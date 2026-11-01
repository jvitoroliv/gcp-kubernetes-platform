#!/bin/bash

# Script to generate Helm charts for remaining services
# Usage: ./generate-service-charts.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CHARTS_DIR="$REPO_ROOT/charts/services"

# Service configurations
declare -A SERVICES=(
  ["lobby-backend"]="3001:NestJS API backend:11.0.0"
  ["afs"]="8080:Asset File Service - Go:1.22.5"
  ["ahsat"]="8080:Analytics Service - Go:1.17.11"
  ["aes"]="1988:Email Service - Python:3.11"
  ["ais"]="5050:AI Image Service - Python:3.11"
)

generate_chart_yaml() {
  local service=$1
  local port=$2
  local desc=$3
  local version=$4

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
}

generate_values_yaml() {
  local service=$1
  local port=$2

  cat > "$CHARTS_DIR/$service/values.yaml" <<EOF
replicaCount: 1

image:
  repository: southamerica-east1-docker.pkg.dev/project-prd-env/project-prd-images/$service
  tag: "latest"
  pullPolicy: IfNotPresent

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  annotations: {}
  name: "$service"

podAnnotations: {}

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: false

service:
  type: ClusterIP
  port: $port

ingress:
  enabled: true
  className: "gce"
  annotations:
    kubernetes.io/ingress.allow-http: "false"
  hosts:
    - host: $service.gameplatform.example.com
      paths:
        - path: /*
          pathType: ImplementationSpecific
          port: $port
  tls: []

resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi

autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

nodeSelector: {}

tolerations: []

affinity: {}

podDisruptionBudget:
  enabled: true
  minAvailable: 1

livenessProbe:
  httpGet:
    path: /health
    port: $port
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  successThreshold: 1
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health
    port: $port
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3

# Database configuration (if needed)
database:
  secretName: postgres-credentials
  connectionName: "project-prd-env:southamerica-east1:postgres-prd"
  cloudSqlProxy:
    enabled: false
    image: gcr.io/cloudsql-docker/gce-proxy:latest

# Environment variables
env:
  - name: NODE_ENV
    value: "production"

# Extra environment variables from secrets
envFrom:
  - secretRef:
      name: $service-secrets
      optional: true

# Service monitor for Prometheus
serviceMonitor:
  enabled: false
  interval: 30s
  path: /metrics
  labels: {}
EOF
}

generate_helpers_tpl() {
  local service=$1
  local service_title=$(echo $service | sed 's/-/_/g')

  cat > "$CHARTS_DIR/$service/templates/_helpers.tpl" <<EOF
{{/*
Expand the name of the chart.
*/}}
{{- define "$service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "$service.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- \$name := default .Chart.Name .Values.nameOverride }}
{{- if contains \$name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name \$name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "$service.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "$service.labels" -}}
helm.sh/chart: {{ include "$service.chart" . }}
{{ include "$service.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "$service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "$service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "$service.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "$service.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
EOF
}

generate_deployment_yaml() {
  local service=$1

  cat > "$CHARTS_DIR/$service/templates/deployment.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "SERVICE_NAME.fullname" . }}
  labels:
    {{- include "SERVICE_NAME.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "SERVICE_NAME.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "SERVICE_NAME.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "SERVICE_NAME.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
      - name: SERVICE_NAME
        securityContext:
          {{- toYaml .Values.securityContext | nindent 12 }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        ports:
        - name: http
          containerPort: {{ .Values.service.port }}
          protocol: TCP
        env:
        {{- range .Values.env }}
        - name: {{ .name }}
          value: {{ .value | quote }}
        {{- end }}
        {{- with .Values.envFrom }}
        envFrom:
          {{- toYaml . | nindent 12 }}
        {{- end }}
        livenessProbe:
          {{- toYaml .Values.livenessProbe | nindent 12 }}
        readinessProbe:
          {{- toYaml .Values.readinessProbe | nindent 12 }}
        resources:
          {{- toYaml .Values.resources | nindent 12 }}
      {{- if .Values.database.cloudSqlProxy.enabled }}
      - name: cloud-sql-proxy
        image: {{ .Values.database.cloudSqlProxy.image }}
        command:
        - "/cloud_sql_proxy"
        - "-instances={{ .Values.database.connectionName }}=tcp:5432"
        securityContext:
          runAsNonRoot: true
          allowPrivilegeEscalation: false
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
EOF

  # Replace SERVICE_NAME with actual service name
  sed -i.bak "s/SERVICE_NAME/$service/g" "$CHARTS_DIR/$service/templates/deployment.yaml"
  rm "$CHARTS_DIR/$service/templates/deployment.yaml.bak"
}

generate_service_yaml() {
  local service=$1

  cat > "$CHARTS_DIR/$service/templates/service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: {{ include "$service.fullname" . }}
  labels:
    {{- include "$service.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
  - port: {{ .Values.service.port }}
    targetPort: http
    protocol: TCP
    name: http
  selector:
    {{- include "$service.selectorLabels" . | nindent 4 }}
EOF
}

generate_hpa_yaml() {
  local service=$1

  cat > "$CHARTS_DIR/$service/templates/hpa.yaml" <<EOF
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "$service.fullname" . }}
  labels:
    {{- include "$service.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "$service.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
  {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
  {{- end }}
  {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
  {{- end }}
{{- end }}
EOF
}

generate_pdb_yaml() {
  local service=$1

  cat > "$CHARTS_DIR/$service/templates/pdb.yaml" <<EOF
{{- if .Values.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "$service.fullname" . }}
  labels:
    {{- include "$service.labels" . | nindent 4 }}
spec:
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
  selector:
    matchLabels:
      {{- include "$service.selectorLabels" . | nindent 6 }}
{{- end }}
EOF
}

generate_serviceaccount_yaml() {
  local service=$1

  cat > "$CHARTS_DIR/$service/templates/serviceaccount.yaml" <<EOF
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "$service.serviceAccountName" . }}
  labels:
    {{- include "$service.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
EOF
}

generate_ingress_yaml() {
  local service=$1

  cat > "$CHARTS_DIR/$service/templates/ingress.yaml" <<EOF
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "$service.fullname" . }}
  labels:
    {{- include "$service.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.ingress.className }}
  ingressClassName: {{ .Values.ingress.className }}
  {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "$service.fullname" \$ }}
                port:
                  number: {{ .port }}
          {{- end }}
    {{- end }}
{{- end }}
EOF
}

generate_servicemonitor_yaml() {
  local service=$1

  cat > "$CHARTS_DIR/$service/templates/servicemonitor.yaml" <<EOF
{{- if .Values.serviceMonitor.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "$service.fullname" . }}
  labels:
    {{- include "$service.labels" . | nindent 4 }}
    {{- with .Values.serviceMonitor.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  selector:
    matchLabels:
      {{- include "$service.selectorLabels" . | nindent 6 }}
  endpoints:
  - port: http
    path: {{ .Values.serviceMonitor.path }}
    interval: {{ .Values.serviceMonitor.interval }}
{{- end }}
EOF
}

# Main execution
echo "Generating Helm charts for remaining services..."

for service in "${!SERVICES[@]}"; do
  echo "Processing $service..."

  IFS=':' read -ra INFO <<< "${SERVICES[$service]}"
  port="${INFO[0]}"
  desc="${INFO[1]}"
  version="${INFO[2]}"

  # Create directories
  mkdir -p "$CHARTS_DIR/$service/templates"

  # Generate all files
  generate_chart_yaml "$service" "$port" "$desc" "$version"
  generate_values_yaml "$service" "$port"
  generate_helpers_tpl "$service"
  generate_deployment_yaml "$service"
  generate_service_yaml "$service"
  generate_hpa_yaml "$service"
  generate_pdb_yaml "$service"
  generate_serviceaccount_yaml "$service"
  generate_ingress_yaml "$service"
  generate_servicemonitor_yaml "$service"

  echo "✓ $service chart generated"
done

echo "All service charts generated successfully!"
