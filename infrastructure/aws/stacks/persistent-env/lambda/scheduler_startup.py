#!/usr/bin/env python3
"""
Environment Scheduler - Startup Function
Starts up non-production environments (dev, staging) during business hours
"""

import boto3
import json
import os
import time
from datetime import datetime
from typing import Dict, List, Any

# AWS Clients
ecs = boto3.client('ecs')
rds = boto3.client('rds')
dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

# Environment variables
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')
CLUSTER_NAME = os.environ.get('CLUSTER_NAME', f'gameplatform-{ENVIRONMENT}-shared-cluster')
DB_INSTANCE_ID = os.environ.get('DB_INSTANCE_ID', f'{ENVIRONMENT}-postgres-postgres')
STATE_TABLE_NAME = os.environ.get('STATE_TABLE_NAME', f'gameplatform-{ENVIRONMENT}-scheduler-state')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')

# Configuration
RDS_STARTUP_TIMEOUT = 300  # 5 minutes max wait for RDS to become available

# DynamoDB table
state_table = dynamodb.Table(STATE_TABLE_NAME)


def lambda_handler(event, context):
    """
    Main Lambda handler for startup operations
    """
    print(f"[SCHEDULER] Starting startup for environment: {ENVIRONMENT}")
    print(f"[SCHEDULER] Cluster: {CLUSTER_NAME}")
    print(f"[SCHEDULER] RDS Instance: {DB_INSTANCE_ID}")

    results = {
        'environment': ENVIRONMENT,
        'timestamp': datetime.utcnow().isoformat(),
        'action': 'startup',
        'rds_status': None,
        'ecs_services': [],
        'errors': []
    }

    try:
        # 1. Start RDS Instance
        print("[SCHEDULER] Starting RDS instance...")
        rds_result = start_rds_instance()
        results['rds_status'] = rds_result

        # 2. Wait for RDS to be available (if it was started)
        if rds_result.get('status') == 'success':
            print("[SCHEDULER] Waiting for RDS to become available...")
            rds_available = wait_for_rds_available()
            results['rds_status']['available'] = rds_available
        else:
            print("[SCHEDULER] RDS was not started, proceeding with ECS startup")

        # 3. Restore ECS Services
        print("[SCHEDULER] Restoring ECS services...")
        ecs_results = restore_ecs_services()
        results['ecs_services'] = ecs_results

        # 4. Send notification
        send_notification(results)

        print("[SCHEDULER] Startup completed successfully")
        return {
            'statusCode': 200,
            'body': json.dumps(results)
        }

    except Exception as e:
        error_msg = f"Startup failed: {str(e)}"
        print(f"[ERROR] {error_msg}")
        results['errors'].append(error_msg)

        # Send error notification
        send_notification(results, error=True)

        return {
            'statusCode': 500,
            'body': json.dumps(results)
        }


def start_rds_instance() -> Dict[str, Any]:
    """
    Start RDS instance if it's stopped
    """
    try:
        # Check if instance exists and its current state
        response = rds.describe_db_instances(
            DBInstanceIdentifier=DB_INSTANCE_ID
        )

        if not response['DBInstances']:
            return {
                'instance': DB_INSTANCE_ID,
                'status': 'not_found'
            }

        db_instance = response['DBInstances'][0]
        current_status = db_instance['DBInstanceStatus']

        print(f"[SCHEDULER] RDS current status: {current_status}")

        # Only start if instance is stopped
        if current_status == 'stopped':
            try:
                rds.start_db_instance(
                    DBInstanceIdentifier=DB_INSTANCE_ID
                )
                print(f"[SCHEDULER] ✓ Starting RDS instance: {DB_INSTANCE_ID}")
                return {
                    'instance': DB_INSTANCE_ID,
                    'previous_status': current_status,
                    'new_status': 'starting',
                    'status': 'success'
                }
            except Exception as e:
                error_msg = f"Failed to start RDS: {str(e)}"
                print(f"[ERROR] {error_msg}")
                return {
                    'instance': DB_INSTANCE_ID,
                    'previous_status': current_status,
                    'status': 'failed',
                    'error': error_msg
                }
        elif current_status == 'available':
            print(f"[SCHEDULER] - RDS already available: {DB_INSTANCE_ID}")
            return {
                'instance': DB_INSTANCE_ID,
                'previous_status': current_status,
                'status': 'already_available'
            }
        else:
            print(f"[SCHEDULER] - RDS in transitioning state: {current_status}")
            return {
                'instance': DB_INSTANCE_ID,
                'previous_status': current_status,
                'status': 'transitioning'
            }

    except Exception as e:
        error_msg = f"Failed to start RDS instance: {str(e)}"
        print(f"[ERROR] {error_msg}")
        raise


def wait_for_rds_available() -> bool:
    """
    Wait for RDS instance to become available
    Returns True if available, False if timeout
    """
    start_time = time.time()
    check_interval = 15  # seconds

    while (time.time() - start_time) < RDS_STARTUP_TIMEOUT:
        try:
            response = rds.describe_db_instances(
                DBInstanceIdentifier=DB_INSTANCE_ID
            )

            if response['DBInstances']:
                status = response['DBInstances'][0]['DBInstanceStatus']
                print(f"[SCHEDULER] RDS status: {status}")

                if status == 'available':
                    elapsed = int(time.time() - start_time)
                    print(f"[SCHEDULER] ✓ RDS available after {elapsed} seconds")
                    return True

            time.sleep(check_interval)

        except Exception as e:
            print(f"[ERROR] Error checking RDS status: {str(e)}")
            time.sleep(check_interval)

    print(f"[SCHEDULER] ⚠ RDS did not become available within {RDS_STARTUP_TIMEOUT}s timeout")
    return False


def restore_ecs_services() -> List[Dict[str, Any]]:
    """
    Restore ECS services to their previous desired count from DynamoDB
    """
    service_results = []

    try:
        # Get all ECS service states from DynamoDB
        response = state_table.scan(
            FilterExpression='begins_with(resource_id, :prefix) AND #env = :env',
            ExpressionAttributeNames={
                '#env': 'environment'
            },
            ExpressionAttributeValues={
                ':prefix': 'ecs-service#',
                ':env': ENVIRONMENT
            }
        )

        service_states = response.get('Items', [])

        if not service_states:
            print("[SCHEDULER] No saved service states found in DynamoDB")
            return service_results

        print(f"[SCHEDULER] Found {len(service_states)} saved service states")

        # List current services in cluster
        paginator = ecs.get_paginator('list_services')
        page_iterator = paginator.paginate(
            cluster=CLUSTER_NAME,
            maxResults=100
        )

        current_service_arns = []
        for page in page_iterator:
            current_service_arns.extend(page.get('serviceArns', []))

        # Extract service names from ARNs
        current_service_names = [arn.split('/')[-1] for arn in current_service_arns]

        # Restore each service
        for state in service_states:
            service_name = state.get('service_name')
            desired_count = int(state.get('desired_count', 1))

            if service_name not in current_service_names:
                print(f"[SCHEDULER] - Service not found in cluster: {service_name}")
                service_results.append({
                    'service': service_name,
                    'status': 'not_found'
                })
                continue

            print(f"[SCHEDULER] Restoring service: {service_name} to count: {desired_count}")

            try:
                ecs.update_service(
                    cluster=CLUSTER_NAME,
                    service=service_name,
                    desiredCount=desired_count
                )
                print(f"[SCHEDULER] ✓ Restored service: {service_name}")
                service_results.append({
                    'service': service_name,
                    'restored_count': desired_count,
                    'status': 'success'
                })
            except Exception as e:
                error_msg = f"Failed to restore {service_name}: {str(e)}"
                print(f"[ERROR] {error_msg}")
                service_results.append({
                    'service': service_name,
                    'status': 'failed',
                    'error': error_msg
                })

        return service_results

    except Exception as e:
        error_msg = f"Failed to restore ECS services: {str(e)}"
        print(f"[ERROR] {error_msg}")
        raise


def send_notification(results: Dict[str, Any], error: bool = False):
    """
    Send SNS notification with startup results
    """
    if not SNS_TOPIC_ARN:
        print("[SCHEDULER] No SNS topic configured, skipping notification")
        return

    try:
        subject = f"[{'ERROR' if error else 'SUCCESS'}] Environment Startup: {ENVIRONMENT.upper()}"

        # Format message
        ecs_count = len(results.get('ecs_services', []))
        ecs_success = len([s for s in results.get('ecs_services', []) if s.get('status') == 'success'])

        message_lines = [
            f"Environment: {ENVIRONMENT.upper()}",
            f"Action: STARTUP",
            f"Timestamp: {results.get('timestamp')}",
            "",
        ]

        if results.get('rds_status'):
            rds_status = results['rds_status'].get('status', 'unknown')
            rds_available = results['rds_status'].get('available', False)
            message_lines.append(f"RDS Status: {rds_status}")
            if rds_status == 'success':
                message_lines.append(f"RDS Available: {rds_available}")

        message_lines.append("")
        message_lines.append(f"ECS Services: {ecs_success}/{ecs_count} restored successfully")

        if results.get('errors'):
            message_lines.append("")
            message_lines.append("ERRORS:")
            for err in results['errors']:
                message_lines.append(f"  - {err}")

        message = "\n".join(message_lines)

        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )

        print("[SCHEDULER] Notification sent successfully")

    except Exception as e:
        print(f"[ERROR] Failed to send notification: {str(e)}")
