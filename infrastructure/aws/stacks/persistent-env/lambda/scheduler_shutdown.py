#!/usr/bin/env python3
"""
Environment Scheduler - Shutdown Function
Shuts down non-production environments (dev, staging) during off-hours
"""

import boto3
import json
import os
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

# DynamoDB table
state_table = dynamodb.Table(STATE_TABLE_NAME)


def lambda_handler(event, context):
    """
    Main Lambda handler for shutdown operations
    """
    print(f"[SCHEDULER] Starting shutdown for environment: {ENVIRONMENT}")
    print(f"[SCHEDULER] Cluster: {CLUSTER_NAME}")
    print(f"[SCHEDULER] RDS Instance: {DB_INSTANCE_ID}")

    results = {
        'environment': ENVIRONMENT,
        'timestamp': datetime.utcnow().isoformat(),
        'action': 'shutdown',
        'ecs_services': [],
        'rds_status': None,
        'errors': []
    }

    try:
        # 1. Shutdown ECS Services
        print("[SCHEDULER] Shutting down ECS services...")
        ecs_results = shutdown_ecs_services()
        results['ecs_services'] = ecs_results

        # 2. Stop RDS Instance
        print("[SCHEDULER] Stopping RDS instance...")
        rds_result = stop_rds_instance()
        results['rds_status'] = rds_result

        # 3. Send notification
        send_notification(results)

        print("[SCHEDULER] Shutdown completed successfully")
        return {
            'statusCode': 200,
            'body': json.dumps(results)
        }

    except Exception as e:
        error_msg = f"Shutdown failed: {str(e)}"
        print(f"[ERROR] {error_msg}")
        results['errors'].append(error_msg)

        # Send error notification
        send_notification(results, error=True)

        return {
            'statusCode': 500,
            'body': json.dumps(results)
        }


def shutdown_ecs_services() -> List[Dict[str, Any]]:
    """
    Shutdown all ECS services in the cluster by setting desired count to 0
    """
    service_results = []

    try:
        # List all services in cluster
        paginator = ecs.get_paginator('list_services')
        page_iterator = paginator.paginate(
            cluster=CLUSTER_NAME,
            maxResults=100
        )

        service_arns = []
        for page in page_iterator:
            service_arns.extend(page.get('serviceArns', []))

        if not service_arns:
            print("[SCHEDULER] No services found in cluster")
            return service_results

        print(f"[SCHEDULER] Found {len(service_arns)} services to shutdown")

        # Describe services to get current state
        services = ecs.describe_services(
            cluster=CLUSTER_NAME,
            services=service_arns
        )

        for service in services['services']:
            service_name = service['serviceName']
            current_count = service['desiredCount']

            print(f"[SCHEDULER] Processing service: {service_name} (current count: {current_count})")

            # Save current state to DynamoDB
            save_service_state(service_name, current_count)

            # Only update if service is running
            if current_count > 0:
                try:
                    ecs.update_service(
                        cluster=CLUSTER_NAME,
                        service=service_name,
                        desiredCount=0
                    )
                    print(f"[SCHEDULER] ✓ Shutdown service: {service_name}")
                    service_results.append({
                        'service': service_name,
                        'previous_count': current_count,
                        'new_count': 0,
                        'status': 'success'
                    })
                except Exception as e:
                    error_msg = f"Failed to shutdown {service_name}: {str(e)}"
                    print(f"[ERROR] {error_msg}")
                    service_results.append({
                        'service': service_name,
                        'previous_count': current_count,
                        'status': 'failed',
                        'error': error_msg
                    })
            else:
                print(f"[SCHEDULER] - Service already stopped: {service_name}")
                service_results.append({
                    'service': service_name,
                    'previous_count': current_count,
                    'status': 'already_stopped'
                })

        return service_results

    except Exception as e:
        error_msg = f"Failed to shutdown ECS services: {str(e)}"
        print(f"[ERROR] {error_msg}")
        raise


def stop_rds_instance() -> Dict[str, Any]:
    """
    Stop RDS instance if it's running
    """
    try:
        # Check if instance exists and is running
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

        # Save current state
        save_rds_state(DB_INSTANCE_ID, current_status)

        # Only stop if instance is available
        if current_status == 'available':
            try:
                rds.stop_db_instance(
                    DBInstanceIdentifier=DB_INSTANCE_ID
                )
                print(f"[SCHEDULER] ✓ Stopping RDS instance: {DB_INSTANCE_ID}")
                return {
                    'instance': DB_INSTANCE_ID,
                    'previous_status': current_status,
                    'new_status': 'stopping',
                    'status': 'success'
                }
            except Exception as e:
                error_msg = f"Failed to stop RDS: {str(e)}"
                print(f"[ERROR] {error_msg}")
                return {
                    'instance': DB_INSTANCE_ID,
                    'previous_status': current_status,
                    'status': 'failed',
                    'error': error_msg
                }
        else:
            print(f"[SCHEDULER] - RDS not in available state: {current_status}")
            return {
                'instance': DB_INSTANCE_ID,
                'previous_status': current_status,
                'status': 'not_available'
            }

    except Exception as e:
        error_msg = f"Failed to stop RDS instance: {str(e)}"
        print(f"[ERROR] {error_msg}")
        raise


def save_service_state(service_name: str, desired_count: int):
    """
    Save ECS service state to DynamoDB for restoration
    """
    try:
        state_table.put_item(
            Item={
                'resource_id': f'ecs-service#{service_name}',
                'environment': ENVIRONMENT,
                'resource_type': 'ecs_service',
                'service_name': service_name,
                'desired_count': desired_count,
                'timestamp': datetime.utcnow().isoformat(),
                'ttl': int(datetime.utcnow().timestamp()) + (7 * 24 * 3600)  # 7 days TTL
            }
        )
        print(f"[SCHEDULER] Saved state for service: {service_name}")
    except Exception as e:
        print(f"[ERROR] Failed to save state for {service_name}: {str(e)}")


def save_rds_state(instance_id: str, status: str):
    """
    Save RDS instance state to DynamoDB
    """
    try:
        state_table.put_item(
            Item={
                'resource_id': f'rds#{instance_id}',
                'environment': ENVIRONMENT,
                'resource_type': 'rds',
                'instance_id': instance_id,
                'status': status,
                'timestamp': datetime.utcnow().isoformat(),
                'ttl': int(datetime.utcnow().timestamp()) + (7 * 24 * 3600)  # 7 days TTL
            }
        )
        print(f"[SCHEDULER] Saved state for RDS: {instance_id}")
    except Exception as e:
        print(f"[ERROR] Failed to save RDS state: {str(e)}")


def send_notification(results: Dict[str, Any], error: bool = False):
    """
    Send SNS notification with shutdown results
    """
    if not SNS_TOPIC_ARN:
        print("[SCHEDULER] No SNS topic configured, skipping notification")
        return

    try:
        subject = f"[{'ERROR' if error else 'SUCCESS'}] Environment Shutdown: {ENVIRONMENT.upper()}"

        # Format message
        ecs_count = len(results.get('ecs_services', []))
        ecs_success = len([s for s in results.get('ecs_services', []) if s.get('status') == 'success'])

        message_lines = [
            f"Environment: {ENVIRONMENT.upper()}",
            f"Action: SHUTDOWN",
            f"Timestamp: {results.get('timestamp')}",
            "",
            f"ECS Services: {ecs_success}/{ecs_count} shutdown successfully",
        ]

        if results.get('rds_status'):
            rds_status = results['rds_status'].get('status', 'unknown')
            message_lines.append(f"RDS Status: {rds_status}")

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
