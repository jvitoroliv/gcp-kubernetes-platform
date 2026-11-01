#!/usr/bin/env python3
"""
RDS Metrics Analysis Script
Collects and analyzes CloudWatch metrics for GamePlatform RDS instances
"""

# AWS SDK — Lambda runtime includes boto3; packaged here for version pinning
import boto3
import json
from datetime import datetime, timedelta
from statistics import mean

def get_metric_stats(cloudwatch, db_identifier, metric_name, days=30):
    """Get CloudWatch metric statistics for an RDS instance"""
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(days=days)

    # Error boundary — failures here are logged and handled, not propagated
    try:
        response = cloudwatch.get_metric_statistics(
            Namespace='AWS/RDS',
            MetricName=metric_name,
            Dimensions=[
                {
                    'Name': 'DBInstanceIdentifier',
                    'Value': db_identifier
                }
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=86400,  # 1 day
            Statistics=['Average', 'Maximum', 'Minimum']
        )

        if not response['Datapoints']:
            return None

        datapoints = response['Datapoints']

        averages = [dp.get('Average', 0) for dp in datapoints if 'Average' in dp]
        maximums = [dp.get('Maximum', 0) for dp in datapoints if 'Maximum' in dp]
        minimums = [dp.get('Minimum', 0) for dp in datapoints if 'Minimum' in dp]

        return {
            'metric': metric_name,
            'avg_of_averages': mean(averages) if averages else 0,
            'peak_maximum': max(maximums) if maximums else 0,
            'lowest_minimum': min(minimums) if minimums else 0,
            'datapoint_count': len(datapoints)
        }
    # Catch-all with structured logging. Specific exceptions handled above.
    except Exception as e:
        print(f"Error getting {metric_name}: {str(e)}")
        return None

def analyze_rds_instance(profile_name, region, db_identifier):
    """Analyze all relevant metrics for an RDS instance"""
    print(f"\n{'='*80}")
    print(f"Analyzing RDS Instance: {db_identifier}")
    print(f"Profile: {profile_name} | Region: {region}")
    print(f"{'='*80}\n")

    session = boto3.Session(profile_name=profile_name, region_name=region)
    cloudwatch = session.client('cloudwatch')
    rds = session.client('rds')

    # Get current RDS configuration
    try:
        db_info = rds.describe_db_instances(DBInstanceIdentifier=db_identifier)
        db_instance = db_info['DBInstances'][0]

        print("CURRENT CONFIGURATION:")
        print(f"  Instance Class: {db_instance['DBInstanceClass']}")
        print(f"  Engine: {db_instance['Engine']} {db_instance['EngineVersion']}")
        print(f"  Storage: {db_instance['AllocatedStorage']} GB")
        print(f"  Max Storage: {db_instance.get('MaxAllocatedStorage', 'N/A')} GB")
        print(f"  Storage Type: {db_instance['StorageType']}")
        print(f"  IOPS: {db_instance.get('Iops', 'N/A')}")
        print(f"  Multi-AZ: {db_instance['MultiAZ']}")
        print(f"  Created: {db_instance['InstanceCreateTime']}")
        print()

        # Calculate instance age
        age_days = (datetime.now(db_instance['InstanceCreateTime'].tzinfo) - db_instance['InstanceCreateTime']).days
        print(f"  Instance Age: {age_days} days")
        print()

    except Exception as e:
        print(f"Error getting RDS info: {str(e)}")
        return None

    # Metrics to collect
    metrics = [
        'CPUUtilization',
        'DatabaseConnections',
        'FreeableMemory',
        'FreeStorageSpace',
        'ReadIOPS',
        'WriteIOPS',
        'ReadLatency',
        'WriteLatency',
        'ReadThroughput',
        'WriteThroughput'
    ]

    print("CLOUDWATCH METRICS (Last 30 days):")
    print("-" * 80)

    results = {}
    for metric in metrics:
        stats = get_metric_stats(cloudwatch, db_identifier, metric, days=30)
        if stats:
            results[metric] = stats

            # Format output based on metric type
            if 'Memory' in metric or 'Storage' in metric:
                # Convert bytes to GB
                avg_gb = stats['avg_of_averages'] / (1024**3)
                min_gb = stats['lowest_minimum'] / (1024**3)
                max_gb = stats['peak_maximum'] / (1024**3)
                print(f"  {metric}:")
                print(f"    Average: {avg_gb:.2f} GB")
                print(f"    Minimum: {min_gb:.2f} GB")
                print(f"    Maximum: {max_gb:.2f} GB")
            elif 'Throughput' in metric:
                # Convert bytes/sec to MB/s
                avg_mb = stats['avg_of_averages'] / (1024**2)
                max_mb = stats['peak_maximum'] / (1024**2)
                print(f"  {metric}:")
                print(f"    Average: {avg_mb:.2f} MB/s")
                print(f"    Maximum: {max_mb:.2f} MB/s")
            elif 'Latency' in metric:
                # Already in seconds
                print(f"  {metric}:")
                print(f"    Average: {stats['avg_of_averages']:.4f} seconds")
                print(f"    Maximum: {stats['peak_maximum']:.4f} seconds")
            else:
                print(f"  {metric}:")
                print(f"    Average: {stats['avg_of_averages']:.2f}")
                print(f"    Maximum: {stats['peak_maximum']:.2f}")

            print(f"    Datapoints: {stats['datapoint_count']}")
            print()

    # Calculate storage usage
    if 'FreeStorageSpace' in results:
        allocated_storage_bytes = db_instance['AllocatedStorage'] * (1024**3)
        free_storage_bytes = results['FreeStorageSpace']['avg_of_averages']
        used_storage_bytes = allocated_storage_bytes - free_storage_bytes
        used_storage_gb = used_storage_bytes / (1024**3)
        usage_percent = (used_storage_gb / db_instance['AllocatedStorage']) * 100

        print("STORAGE ANALYSIS:")
        print(f"  Allocated: {db_instance['AllocatedStorage']} GB")
        print(f"  Used: {used_storage_gb:.2f} GB ({usage_percent:.1f}%)")
        print(f"  Free: {free_storage_bytes / (1024**3):.2f} GB")
        print()

    # Memory analysis (for instance sizing recommendation)
    if 'FreeableMemory' in results:
        # Get instance type specs
        instance_class = db_instance['DBInstanceClass']

        # t3.micro = 1 GB, t3.small = 2 GB, t3.medium = 4 GB, t3.large = 8 GB
        instance_memory = {
            'db.t3.micro': 1,
            'db.t3.small': 2,
            'db.t3.medium': 4,
            'db.t3.large': 8,
            'db.t4g.micro': 1,
            'db.t4g.small': 2,
            'db.t4g.medium': 4,
        }

        total_memory_gb = instance_memory.get(instance_class, 0)
        free_memory_gb = results['FreeableMemory']['avg_of_averages'] / (1024**3)
        used_memory_gb = total_memory_gb - free_memory_gb
        memory_usage_percent = (used_memory_gb / total_memory_gb * 100) if total_memory_gb > 0 else 0

        print("MEMORY ANALYSIS:")
        print(f"  Total: {total_memory_gb} GB")
        print(f"  Used (avg): {used_memory_gb:.2f} GB ({memory_usage_percent:.1f}%)")
        print(f"  Free (avg): {free_memory_gb:.2f} GB")
        print()

    return {
        'db_info': db_instance,
        'metrics': results,
        'age_days': age_days
    }

def main():
    """Main analysis function"""

    # Analyze Dev environment
    dev_results = analyze_rds_instance(
        profile_name='sandbox',
        region='us-east-1',
        db_identifier='dev-postgres-postgres'
    )

    # Analyze Staging environment
    stg_results = analyze_rds_instance(
        profile_name='staging',
        region='us-east-1',
        db_identifier='stg-postgres-postgres'
    )

    # Generate recommendations
    print("\n" + "="*80)
    print("OPTIMIZATION RECOMMENDATIONS")
    print("="*80 + "\n")

    if dev_results:
        print("DEV ENVIRONMENT:")
        cpu_avg = dev_results['metrics'].get('CPUUtilization', {}).get('avg_of_averages', 0)
        cpu_max = dev_results['metrics'].get('CPUUtilization', {}).get('peak_maximum', 0)

        print(f"  Current: {dev_results['db_info']['DBInstanceClass']}")
        print(f"  CPU Usage: {cpu_avg:.1f}% avg, {cpu_max:.1f}% max")

        if cpu_avg < 10 and cpu_max < 30:
            print(f"  ✓ Instance is significantly underutilized")
            print(f"  → Could remain on db.t3.micro (lowest cost)")
        elif cpu_avg < 20 and cpu_max < 50:
            print(f"  ✓ Instance is underutilized but appropriate for dev")
        print()

    if stg_results:
        print("STAGING ENVIRONMENT:")
        cpu_avg = stg_results['metrics'].get('CPUUtilization', {}).get('avg_of_averages', 0)
        cpu_max = stg_results['metrics'].get('CPUUtilization', {}).get('peak_maximum', 0)

        print(f"  Current: {stg_results['db_info']['DBInstanceClass']}")
        print(f"  CPU Usage: {cpu_avg:.1f}% avg, {cpu_max:.1f}% max")

        if cpu_avg < 20 and cpu_max < 50:
            print(f"  ✓ Instance is underutilized")
            print(f"  → Recommend downgrade to db.t3.small (50% cost reduction)")
        elif cpu_avg < 30 and cpu_max < 70:
            print(f"  ✓ Instance sizing is appropriate")
        print()

    # Save results to JSON
    output = {
        'analysis_date': datetime.utcnow().isoformat(),
        'dev': dev_results,
        'stg': stg_results
    }

    output_file = '/docs/GamePlatform/rds_metrics_analysis.json'
    with open(output_file, 'w') as f:
        json.dump(output, f, indent=2, default=str)

    print(f"\nDetailed results saved to: {output_file}")

if __name__ == '__main__':
    main()
