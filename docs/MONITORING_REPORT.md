# Monitoring & Logging Stack — Implementation Report

**Environment scope:** Development (DEV) — active | Staging & Production — pending

---

## Overview

This report summarizes the implementation of the observability stack for the GamePlatform platform running on Google Kubernetes Engine (GCP). The stack covers metrics collection, log aggregation, distributed tracing, and alerting across all platform services.

---

## What Was Implemented

### Metrics — Prometheus + Alertmanager

A **kube-prometheus-stack** was deployed to the DEV cluster, providing:

- **Prometheus** — scrapes metrics from all 8 application services plus all cluster-level components (nodes, pods, containers, kubelet, kube-state-metrics)
- **Alertmanager** — receives firing alerts from Prometheus; routing rules and notification channels to be configured in the next iteration

Current Prometheus coverage: **86,000+ time series** across **17 scrape jobs**, including:

| Source | What it provides |
|---|---|
| All 8 GamePlatform services | Application-level HTTP metrics (request rate, error rate, latency) |
| cAdvisor | Per-container CPU, memory, network, filesystem |
| kube-state-metrics | Deployment status, pod restarts, resource requests/limits |
| node-exporter | Per-node CPU, memory, disk, network |
| kubelet | Node-level runtime metrics |

### Logs — Loki + Promtail

- **Promtail** runs as a DaemonSet on every node and ships logs from all pods to Loki
- **Loki** stores and indexes logs; they are queryable directly in Grafana via LogQL
- All 8 GamePlatform services in the DEV namespace are currently streaming logs

### Distributed Tracing — Tempo

- **Tempo** is deployed and configured as a datasource in Grafana
- The Grafana datasource is pre-configured with trace-to-log correlation (Loki) and service map (Prometheus)
- End-to-end trace validation with service instrumentation is part of the next steps

### Telemetry Collection — OpenTelemetry Collector

- **OTel Collector** is deployed and running in the DEV cluster
- Acts as the centralized receiver for traces and metrics emitted by services using the OpenTelemetry SDK
- Configured to forward traces to Tempo and metrics to Prometheus

### Visualization — Grafana

Grafana is the single pane of glass for the entire observability stack. The following is pre-configured:

- **Datasources:** Prometheus, Loki, Tempo (all pre-provisioned, no manual setup needed)
- **Dashboards:**
  - **Golden Signals** — the primary dashboard for all services, displaying request rate, error rate, and latency (RED method), plus CPU and memory per service
  - **Node Exporter / USE** — node-level resource utilization (CPU, memory, disk, network)
  - **Kubernetes cluster overview** — deployment health, pod status, resource pressure
  - **Loki log explorer** — full-text log search across all services

Screenshots of the main dashboards are attached below.

---

## Access (VPN Required)

All monitoring endpoints are **private and accessible only via VPN**. They are not exposed to the internet.

| Service | URL |
|---|---|
| Grafana | http://grafana.dev.gameplatform |
| Prometheus | http://prometheus.dev.gameplatform |
| Alertmanager | http://alertmanager.dev.gameplatform |

> **Note:** Team members will be granted individual Grafana user accounts in the coming days. At the moment, the stack is under active configuration by the infrastructure team.

---

## How to Use

### Monitoring (Grafana)

1. Connect to VPN
2. Open `http://grafana.dev.gameplatform` in your browser
3. Navigate to **Dashboards → Golden Signals** to see request rate, error rate, and latency for all services
4. Use **Dashboards → Node Exporter** for infrastructure-level resource metrics

### Querying Logs (Loki)

1. In Grafana, go to **Explore** and select the **Loki** datasource
2. Use LogQL to filter logs. Examples:
   - All logs for a specific service: `{namespace="gameplatform-dev", app="lobby-backend"}`
   - Filter by log level: `{namespace="gameplatform-dev"} |= "ERROR"`
   - Full-text search: `{namespace="gameplatform-dev"} |= "payment failed"`

### Querying Metrics (Prometheus)

1. In Grafana, go to **Explore** and select the **Prometheus** datasource
2. Use PromQL to query metrics. Examples:
   - HTTP request rate per service: `rate(http_requests_total{namespace="gameplatform-dev"}[5m])`
   - Error rate: `rate(http_requests_total{status=~"5.."}[5m])`
   - Memory usage by pod: `container_memory_working_set_bytes{namespace="gameplatform-dev"}`

### Querying Traces (Tempo)

1. In Grafana, go to **Explore** and select the **Tempo** datasource
2. Search by service name or trace ID
3. From Loki logs, if a trace ID appears in the log line, Grafana will automatically offer a link to the corresponding trace

---

## What Is Not Yet Working

### 1. Alert routing (Alertmanager)
**Status:** Alertmanager is running, but no notification channels are configured yet (Slack, PagerDuty, email, etc.).

**Impact:** Alerts fired by Prometheus are not delivered anywhere.

**Next steps:** Define alert severity levels, configure receivers (e.g., Slack webhook), and create alerting rules for critical conditions (pod crash loops, high error rate, resource exhaustion).

### 2. Distributed tracing — end-to-end (Tempo)
**Status:** Tempo is running and configured in Grafana, but trace ingestion has not been validated end-to-end with the running services.

**Impact:** Traces may not be appearing in Grafana for services not yet instrumented with OpenTelemetry.

**Next steps:** Validate that services are emitting traces to the OTel Collector with the correct endpoint configuration, and confirm traces appear in the Grafana Tempo datasource.

### 3. Monitoring for Staging and Production
**Status:** The full stack (Prometheus, Loki, Promtail, Tempo, OTel Collector) is deployed only in DEV. STG and PRD do not have monitoring deployed yet.

**Impact:** No metrics, logs, or traces are available for STG and PRD environments.

**Next steps:** Once the DEV stack is fully validated, the same stack will be deployed to STG and PRD. The PRD environment already has Loki and Tempo datasource configuration pre-defined, which will accelerate that deployment.

### 4. Grafana user accounts
**Status:** Currently only the admin account exists.

**Impact:** Team members cannot log in to Grafana independently.

**Next steps:** Individual user accounts will be created for team members in the coming days, with appropriate access levels.

---

## Dashboard Screenshots

*(Screenshots to be added)*

---

## Summary

| Component | DEV | STG | PRD |
|---|---|---|---|
| Prometheus | ✅ Running | ⏳ Pending | ⏳ Pending |
| Alertmanager | ✅ Running | ⏳ Pending | ⏳ Pending |
| Grafana | ✅ Running | ⏳ Pending | ⏳ Pending |
| Loki | ✅ Running | ⏳ Pending | ⏳ Pending |
| Promtail | ✅ Running | ⏳ Pending | ⏳ Pending |
| Tempo | ✅ Deployed | ⏳ Pending | ⏳ Pending |
| OTel Collector | ✅ Deployed | ⏳ Pending | ⏳ Pending |
| Alert rules | ❌ Not configured | ⏳ Pending | ⏳ Pending |
| Grafana user accounts | ❌ Pending | ⏳ Pending | ⏳ Pending |
| Trace validation (Tempo) | ❌ Not validated | ⏳ Pending | ⏳ Pending |
