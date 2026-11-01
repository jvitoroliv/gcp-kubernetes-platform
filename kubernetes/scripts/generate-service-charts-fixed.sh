#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CHARTS_DIR="$REPO_ROOT/charts/services"

# Create charts directory if not exists
mkdir -p "$CHARTS_DIR"

# Services: name:port:description:version
SERVICES=(
  "lobby-backend:3001:NestJS API backend:11.0.0"
  "afs:8080:Asset File Service:1.22.5"
  "ahsat:8080:Analytics Service:1.17.11"
  "aes:1988:Email Service:3.11"
  "ais:5050:AI Image Service:3.11"
)

echo "🚀 Generating Helm charts for remaining services..."

for entry in "${SERVICES[@]}"; do
  IFS=':' read -r service port desc version <<< "$entry"
  
  echo "📦 Creating chart for $service..."
  
  # Create directory structure
  mkdir -p "$CHARTS_DIR/$service/templates"
  
  # Copy templates from nakama (they are generic)
  if [ -d "$CHARTS_DIR/nakama/templates" ]; then
    cp "$CHARTS_DIR/nakama/templates/_helpers.tpl" "$CHARTS_DIR/$service/templates/"
    cp "$CHARTS_DIR/nakama/templates/deployment.yaml" "$CHARTS_DIR/$service/templates/"
    cp "$CHARTS_DIR/nakama/templates/service.yaml" "$CHARTS_DIR/$service/templates/"
    cp "$CHARTS_DIR/nakama/templates/hpa.yaml" "$CHARTS_DIR/$service/templates/"
    cp "$CHARTS_DIR/nakama/templates/pdb.yaml" "$CHARTS_DIR/$service/templates/"
    cp "$CHARTS_DIR/nakama/templates/serviceaccount.yaml" "$CHARTS_DIR/$service/templates/"
    cp "$CHARTS_DIR/nakama/templates/ingress.yaml" "$CHARTS_DIR/$service/templates/"
    
    # Replace service name in templates
    for file in "$CHARTS_DIR/$service/templates"/*.yaml "$CHARTS_DIR/$service/templates"/*.tpl; do
      if [ -f "$file" ]; then
        sed -i.bak "s/nakama/$service/g" "$file" && rm "${file}.bak"
      fi
    done
  fi
  
  # Create Chart.yaml
  cat > "$CHARTS_DIR/$service/Chart.yaml" <<EOF
apiVersion: v2
name: $service
description: $desc for GamePlatform Platform
type: application
version: 1.0.0
appVersion: "$version"
keywords:
  - microservice
  - $service
maintainers:
  - name: GamePlatform DevOps Team
    email: devops@gameplatform.example.com
EOF

  # Create values.yaml
  cat > "$CHARTS_DIR/$service/values.yaml" <<EOF
replicaCount: 1

image:
  repository: southamerica-east1-docker.pkg.dev/project-prd-env/project-prd-images/$service
  tag: "latest"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: $port

resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 1Gi

autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

serviceAccount:
  create: true
  name: ""

podDisruptionBudget:
  enabled: true
  minAvailable: 1

ingress:
  enabled: true
  className: "gce"
  annotations:
    kubernetes.io/ingress.global-static-ip-name: "project-prd-ip"
  hosts:
    - host: $service.gameplatform.example.com
      paths:
        - path: /*
          pathType: ImplementationSpecific
  tls: []

env: []

nodeSelector: {}
tolerations: []
affinity: {}
EOF

  echo "✅ Chart $service created successfully"
done

echo ""
echo "🎉 All service charts generated successfully!"
echo ""
echo "Generated charts:"
for entry in "${SERVICES[@]}"; do
  IFS=':' read -r service _ _ _ <<< "$entry"
  echo "  - charts/services/$service/"
done
