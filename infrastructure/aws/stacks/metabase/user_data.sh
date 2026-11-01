#!/bin/bash
set -ex

# Log everything to file for debugging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting Metabase setup at $(date)"

# Update system
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y \
  docker.io \
  docker-compose-v2 \
  jq \
  curl \
  unzip

# Install AWS CLI v2
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Create directory structure
mkdir -p /home/ubuntu/metabase
mkdir -p /home/ubuntu/metabase-logs
chown -R ubuntu:ubuntu /home/ubuntu/metabase
chown -R ubuntu:ubuntu /home/ubuntu/metabase-logs

# Fetch database credentials from Secrets Manager
echo "Fetching database credentials from Secrets Manager..."
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id project-live-metabase-db-password \
  --region sa-east-1 \
  --query SecretString \
  --output text)

# Extract credentials
DB_HOST=$(echo $SECRET_JSON | jq -r '.host')
DB_PORT=$(echo $SECRET_JSON | jq -r '.port')
DB_NAME=$(echo $SECRET_JSON | jq -r '.dbname')
DB_USER=$(echo $SECRET_JSON | jq -r '.username')
DB_PASS=$(echo $SECRET_JSON | jq -r '.password')

echo "Database host: $DB_HOST"
echo "Database port: $DB_PORT"
echo "Database name: $DB_NAME"

# Create docker-compose.yml
cat > /home/ubuntu/metabase/docker-compose.yml <<EOF
version: '3.8'
services:
  metabase:
    image: metabase/metabase:v0.56.3
    container_name: metabase
    ports:
      - "3000:3000"
    environment:
      MB_JETTY_HOST: 0.0.0.0
      MB_DB_TYPE: postgres
      MB_DB_DBNAME: $DB_NAME
      MB_DB_PORT: $DB_PORT
      MB_DB_USER: $DB_USER
      MB_DB_PASS: $DB_PASS
      MB_DB_HOST: $DB_HOST
      JAVA_OPTS: "-Xms512m -Xmx2g"
      MB_DB_CONNECTION_TIMEOUT_MS: 60000
      MB_DB_JDBC_OPTIONS: "sslmode=disable"
    volumes:
      - /home/ubuntu/metabase-logs:/logs
    restart: always
EOF

chown ubuntu:ubuntu /home/ubuntu/metabase/docker-compose.yml

# Create systemd service for docker-compose
cat > /etc/systemd/system/metabase-compose.service <<EOF
[Unit]
Description=Metabase Docker Compose Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ubuntu/metabase
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0
User=ubuntu
Group=ubuntu

[Install]
WantedBy=multi-user.target
EOF

# Start Metabase via docker compose
echo "Starting Metabase container..."
cd /home/ubuntu/metabase
docker compose up -d

# Wait for Metabase to be healthy
echo "Waiting for Metabase to become healthy..."
COUNTER=0
MAX_ATTEMPTS=60
until [ $COUNTER -gt $MAX_ATTEMPTS ] || curl -f http://localhost:3000/api/health; do
  echo "Attempt $COUNTER: Metabase not ready yet..."
  sleep 10
  COUNTER=$((COUNTER + 1))
done

if [ $COUNTER -gt $MAX_ATTEMPTS ]; then
  echo "ERROR: Metabase failed to start after $MAX_ATTEMPTS attempts"
  cd /home/ubuntu/metabase && docker compose logs
  exit 1
fi

echo "Metabase is healthy!"

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/aws/ec2/project-live-metabase",
            "log_stream_name": "{instance_id}/user-data"
          },
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "/aws/ec2/project-live-metabase",
            "log_stream_name": "{instance_id}/syslog"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "GamePlatform/Metabase",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          {
            "name": "cpu_usage_idle",
            "rename": "CPU_IDLE",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60,
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          {
            "name": "used_percent",
            "rename": "DISK_USED_PERCENT",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          {
            "name": "mem_used_percent",
            "rename": "MEM_USED_PERCENT",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

echo "Metabase setup completed successfully at $(date)"