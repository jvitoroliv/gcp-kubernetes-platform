# Kubernetes CronJob - Lobby Export Updater

## Overview

This document describes the implementation plan for a Kubernetes CronJob that updates the Godot client export in the Lobby service. This replaces the broken BusyBox crond inside the lobby container.

---

## Problem Statement

The lobby container uses BusyBox crond with `-L /dev/stdout` which doesn't work correctly because:
1. crond daemonizes and redirects file descriptors to `/dev/null`
2. The `-L /dev/stdout` option fails silently after the fork
3. Scheduled jobs never execute, only the initial entrypoint download works

---

## Solution Architecture

### Approach
Create a Kubernetes CronJob that runs every 3 minutes and executes the update script inside the lobby pod via `kubectl exec`.

### Where it runs
| Environment | Cluster | Namespace | Target |
|-------------|---------|-----------|--------|
| dev | project-dev-workloads | gameplatform-dev | game-platform-dev-lobby |
| stg | project-stg-workloads | gameplatform-stg | game-platform-stg-lobby |
| prd | project-prd-workloads | gameplatform-prd | game-platform-prd-lobby |

The CronJob runs in the **same cluster and namespace** as the lobby deployment it targets.

---

## Repository Structure

### Location
```
platform-kubernetes-infrastructure/
├── charts/
│   ├── services/
│   │   └── lobby-export-updater/    # NEW - CronJob chart
│   │       ├── Chart.yaml
│   │       ├── values.yaml
│   │       └── templates/
│   │           ├── _helpers.tpl
│   │           ├── cronjob.yaml
│   │           ├── serviceaccount.yaml
│   │           ├── role.yaml
│   │           └── rolebinding.yaml
│   └── game-platform/
│       └── Chart.yaml               # UPDATE - Add dependency
├── argocd/
│   ├── dev/
│   │   └── kustomization.yaml       # No changes needed (uses umbrella chart)
│   ├── stg/
│   │   └── kustomization.yaml
│   └── prd/
│       └── kustomization.yaml
└── values/
    ├── dev/
    │   └── game-platform.yaml     # UPDATE - Add lobby-export-updater config
    ├── stg/
    │   └── game-platform.yaml
    └── prd/
        └── game-platform.yaml
```

---

## Helm Chart Design

### charts/services/lobby-export-updater/Chart.yaml
```yaml
apiVersion: v2
name: lobby-export-updater
description: CronJob to update Godot client export in Lobby service
type: application
version: 1.0.0
appVersion: "1.0.0"
keywords:
  - gameplatform
  - lobby
  - cronjob
  - export
maintainers:
  - name: GamePlatform DevOps Team
    email: devops@gameplatform.example.com
```

### charts/services/lobby-export-updater/values.yaml
```yaml
# Enable/disable the CronJob
enabled: true

# CronJob schedule (every 3 minutes)
schedule: "*/3 * * * *"

# Target lobby deployment
lobby:
  deploymentName: "game-platform-{{ .Release.Namespace | trimPrefix \"gameplatform-\" }}-lobby"
  namespace: ""  # Defaults to release namespace

# Export URL per environment (set via values override)
exportUrl: ""

# Image for kubectl
image:
  repository: bitnami/kubectl
  tag: "1.33"
  pullPolicy: IfNotPresent

# Job configuration
backoffLimit: 3
activeDeadlineSeconds: 120
ttlSecondsAfterFinished: 300
successfulJobsHistoryLimit: 3
failedJobsHistoryLimit: 3
concurrencyPolicy: Forbid

# ServiceAccount
serviceAccount:
  create: true
  name: "lobby-export-updater"
  annotations: {}

# Resources for the job pod
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 100m
    memory: 128Mi

# Node selector (optional)
nodeSelector: {}

# Tolerations (optional)
tolerations: []
```

### charts/services/lobby-export-updater/templates/_helpers.tpl
```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "lobby-export-updater.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "lobby-export-updater.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "lobby-export-updater.labels" -}}
helm.sh/chart: {{ include "lobby-export-updater.chart" . }}
{{ include "lobby-export-updater.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "lobby-export-updater.selectorLabels" -}}
app.kubernetes.io/name: {{ include "lobby-export-updater.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Chart label
*/}}
{{- define "lobby-export-updater.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
ServiceAccount name
*/}}
{{- define "lobby-export-updater.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "lobby-export-updater.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Target namespace (defaults to release namespace)
*/}}
{{- define "lobby-export-updater.targetNamespace" -}}
{{- default .Release.Namespace .Values.lobby.namespace }}
{{- end }}

{{/*
Lobby deployment name
*/}}
{{- define "lobby-export-updater.lobbyDeployment" -}}
{{- $env := .Release.Namespace | trimPrefix "gameplatform-" }}
{{- default (printf "game-platform-%s-lobby" $env) .Values.lobby.deploymentName }}
{{- end }}
```

### charts/services/lobby-export-updater/templates/serviceaccount.yaml
```yaml
{{- if .Values.enabled }}
{{- if .Values.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "lobby-export-updater.serviceAccountName" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "lobby-export-updater.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
```

### charts/services/lobby-export-updater/templates/role.yaml
```yaml
{{- if .Values.enabled }}
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ include "lobby-export-updater.fullname" . }}
  namespace: {{ include "lobby-export-updater.targetNamespace" . }}
  labels:
    {{- include "lobby-export-updater.labels" . | nindent 4 }}
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
  - apiGroups: [""]
    resources: ["pods/exec"]
    verbs: ["create"]
{{- end }}
```

### charts/services/lobby-export-updater/templates/rolebinding.yaml
```yaml
{{- if .Values.enabled }}
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ include "lobby-export-updater.fullname" . }}
  namespace: {{ include "lobby-export-updater.targetNamespace" . }}
  labels:
    {{- include "lobby-export-updater.labels" . | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ include "lobby-export-updater.fullname" . }}
subjects:
  - kind: ServiceAccount
    name: {{ include "lobby-export-updater.serviceAccountName" . }}
    namespace: {{ .Release.Namespace }}
{{- end }}
```

### charts/services/lobby-export-updater/templates/cronjob.yaml
```yaml
{{- if .Values.enabled }}
apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ include "lobby-export-updater.fullname" . }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "lobby-export-updater.labels" . | nindent 4 }}
spec:
  schedule: {{ .Values.schedule | quote }}
  concurrencyPolicy: {{ .Values.concurrencyPolicy }}
  successfulJobsHistoryLimit: {{ .Values.successfulJobsHistoryLimit }}
  failedJobsHistoryLimit: {{ .Values.failedJobsHistoryLimit }}
  jobTemplate:
    spec:
      backoffLimit: {{ .Values.backoffLimit }}
      activeDeadlineSeconds: {{ .Values.activeDeadlineSeconds }}
      ttlSecondsAfterFinished: {{ .Values.ttlSecondsAfterFinished }}
      template:
        metadata:
          labels:
            {{- include "lobby-export-updater.selectorLabels" . | nindent 12 }}
        spec:
          serviceAccountName: {{ include "lobby-export-updater.serviceAccountName" . }}
          restartPolicy: OnFailure
          {{- with .Values.nodeSelector }}
          nodeSelector:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.tolerations }}
          tolerations:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          containers:
            - name: kubectl
              image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
              imagePullPolicy: {{ .Values.image.pullPolicy }}
              resources:
                {{- toYaml .Values.resources | nindent 16 }}
              command:
                - /bin/sh
                - -c
                - |
                  set -e
                  echo "[$(date)] Starting lobby export update..."

                  # Get the lobby pod name
                  NAMESPACE="{{ include "lobby-export-updater.targetNamespace" . }}"
                  DEPLOYMENT="{{ include "lobby-export-updater.lobbyDeployment" . }}"

                  echo "[$(date)] Finding pod for deployment: $DEPLOYMENT in namespace: $NAMESPACE"

                  POD=$(kubectl get pods -n "$NAMESPACE" \
                    -l "app.kubernetes.io/name=lobby" \
                    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

                  if [ -z "$POD" ]; then
                    echo "[$(date)] ERROR: No lobby pod found"
                    exit 1
                  fi

                  echo "[$(date)] Found pod: $POD"

                  # Check if pod is ready
                  READY=$(kubectl get pod -n "$NAMESPACE" "$POD" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
                  if [ "$READY" != "True" ]; then
                    echo "[$(date)] WARNING: Pod is not ready, skipping update"
                    exit 0
                  fi

                  # Execute the update script
                  echo "[$(date)] Executing update script..."
                  kubectl exec -n "$NAMESPACE" "$POD" -- \
                    /usr/local/bin/update-export.sh '{{ .Values.exportUrl }}'

                  echo "[$(date)] Export update completed successfully!"
{{- end }}
```

---

## Umbrella Chart Update

### charts/game-platform/Chart.yaml (ADD dependency)
```yaml
# Add to dependencies list:
  - name: lobby-export-updater
    version: 1.0.0
    repository: "file://../services/lobby-export-updater"
    condition: lobby-export-updater.enabled
```

---

## Environment Values

### values/dev/game-platform.yaml (ADD section)
```yaml
lobby-export-updater:
  enabled: true
  schedule: "*/3 * * * *"
  exportUrl: "https://storage.googleapis.com/galapagos-exports-gcs/lobby/dev/index.7z"
  lobby:
    deploymentName: "game-platform-dev-lobby"
```

### values/stg/game-platform.yaml (ADD section)
```yaml
lobby-export-updater:
  enabled: true
  schedule: "*/3 * * * *"
  exportUrl: "https://storage.googleapis.com/galapagos-exports-gcs/lobby/stg/index.7z"
  lobby:
    deploymentName: "game-platform-stg-lobby"
```

### values/prd/game-platform.yaml (ADD section)
```yaml
lobby-export-updater:
  enabled: true
  schedule: "*/3 * * * *"
  exportUrl: "https://storage.googleapis.com/galapagos-exports-gcs/lobby/prd/index.7z"
  lobby:
    deploymentName: "game-platform-prd-lobby"
```

---

## Lobby Dockerfile Cleanup

After implementing the CronJob, remove the broken cron from the lobby container:

### applications/lobby/Dockerfile (REMOVE cron-related code)

Remove from entrypoint:
```dockerfile
# REMOVE these lines from the entrypoint script:
# Create crontab with the resolved URL (runs every 3 minutes)
echo "*/3 * * * * /usr/local/bin/update-export.sh '$EXPORT_URL' >> /proc/1/fd/1 2>&1" > /etc/crontabs/root
chmod 0644 /etc/crontabs/root

echo "=== Starting crond ==="
crond -l 2 -L /dev/stdout
```

Keep only the initial download on startup (for fast cold-start):
```dockerfile
# KEEP this - runs once at container startup
/usr/local/bin/update-export.sh "$EXPORT_URL" || echo "Initial download failed, CronJob will retry"
```

---

## Implementation Steps

### Phase 1: Create Helm Chart
1. Create directory `charts/services/lobby-export-updater/`
2. Create `Chart.yaml`
3. Create `values.yaml`
4. Create `templates/_helpers.tpl`
5. Create `templates/serviceaccount.yaml`
6. Create `templates/role.yaml`
7. Create `templates/rolebinding.yaml`
8. Create `templates/cronjob.yaml`

### Phase 2: Update Umbrella Chart
1. Add dependency to `charts/game-platform/Chart.yaml`
2. Run `helm dependency update` in game-platform directory

### Phase 3: Configure Environments
1. Add lobby-export-updater config to `values/dev/game-platform.yaml`
2. Add lobby-export-updater config to `values/stg/game-platform.yaml`
3. Add lobby-export-updater config to `values/prd/game-platform.yaml`

### Phase 4: Deploy
1. Commit and push changes to `platform-kubernetes-infrastructure`
2. ArgoCD will automatically sync the changes
3. Verify CronJob is created in each namespace

### Phase 5: Cleanup Lobby
1. Update `applications/lobby/Dockerfile` to remove cron
2. Commit and push to `gameplatform-monorepo`
3. Build and deploy new lobby image

### Phase 6: Verify
1. Check CronJob status: `kubectl get cronjobs -n gameplatform-dev`
2. Check Job history: `kubectl get jobs -n gameplatform-dev`
3. Check logs: `kubectl logs -n gameplatform-dev job/<job-name>`
4. Verify export is being updated every 3 minutes

---

## Monitoring & Troubleshooting

### Check CronJob Status
```bash
# List CronJobs
kubectl get cronjobs -n gameplatform-dev

# Check recent jobs
kubectl get jobs -n gameplatform-dev --sort-by=.metadata.creationTimestamp

# Check job logs
kubectl logs -n gameplatform-dev job/$(kubectl get jobs -n gameplatform-dev -o jsonpath='{.items[-1].metadata.name}')
```

### Check Export Update
```bash
# Check when export was last updated
kubectl exec -n gameplatform-dev deploy/game-platform-dev-lobby -- stat /app/public/export | grep Modify
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Job fails with "No lobby pod found" | Lobby pod not running | Check lobby deployment |
| Job fails with "Pod is not ready" | Lobby pod is restarting | Wait for pod to be ready |
| Permission denied on exec | RBAC not configured | Check Role and RoleBinding |
| Export not updating | Wrong URL | Check exportUrl in values |

---

## Rollback Plan

If the CronJob causes issues:

1. Disable CronJob:
```yaml
# In values/{env}/game-platform.yaml
lobby-export-updater:
  enabled: false
```

2. Re-enable cron in lobby Dockerfile (revert the cleanup)

3. Build and deploy new lobby image

---

## Future Improvements

1. **GCS Pub/Sub Integration**: Instead of polling every 3 minutes, trigger the update immediately when the GCS file changes
2. **Metrics**: Add Prometheus metrics for job success/failure
3. **Alerting**: Alert on failed jobs via ArgoCD notifications
4. **Multi-replica support**: If lobby has multiple replicas, update all of them (or use a shared volume)
