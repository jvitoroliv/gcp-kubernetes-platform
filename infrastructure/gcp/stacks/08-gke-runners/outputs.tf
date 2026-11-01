# -----------------------------------------------------------------------------
# GKE CLUSTER OUTPUTS
# -----------------------------------------------------------------------------

output "cluster_name" {
  description = "GKE runners cluster name"
  value       = module.gke_cluster.name
}

output "cluster_id" {
  description = "GKE runners cluster ID"
  value       = module.gke_cluster.id
}

output "cluster_endpoint" {
  description = "GKE runners cluster endpoint"
  value       = module.gke_cluster.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE runners cluster CA certificate"
  value       = module.gke_cluster.cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "GKE runners cluster location (region)"
  value       = var.region
}

# -----------------------------------------------------------------------------
# NODE POOL OUTPUTS
# -----------------------------------------------------------------------------

output "heavy_pool_name" {
  description = "Name of the heavy runners node pool"
  value       = module.runners_heavy_pool.name
}

output "infra_pool_name" {
  description = "Name of the infra node pool (ArgoCD, ESO, ARC controller)"
  value       = module.infra_pool.name
}

# -----------------------------------------------------------------------------
# WORKLOAD IDENTITY OUTPUTS
# -----------------------------------------------------------------------------

output "workload_identity_pool" {
  description = "Workload Identity pool for the runners cluster"
  value       = "${var.project_id}.svc.id.goog"
}

output "arc_controller_service_account" {
  description = "ARC Controller workload identity service account email"
  value       = module.arc_controller_workload_identity.service_account_email
}

output "arc_runner_service_account" {
  description = "ARC Runner workload identity service account email"
  value       = module.arc_runner_workload_identity.service_account_email
}

# -----------------------------------------------------------------------------
# KUBECTL CONNECTION COMMAND
# -----------------------------------------------------------------------------

output "kubectl_connect_command" {
  description = "Command to configure kubectl to connect to the runners cluster"
  value       = "gcloud container clusters get-credentials ${module.gke_cluster.name} --region ${var.region} --project ${var.project_id}"
}

# -----------------------------------------------------------------------------
# ARC INSTALLATION INSTRUCTIONS
# -----------------------------------------------------------------------------

output "arc_installation_instructions" {
  description = "Instructions for installing Actions Runner Controller"
  value       = <<-EOT
    ============================================================
    ACTIONS RUNNER CONTROLLER (ARC) INSTALLATION
    ============================================================

    ARCHITECTURE:
    - Dedicated runners cluster with 2 node pools:
      * infra-pool (e2-medium, min=1) - ArgoCD, ESO, ARC controller (NO TAINTS)
      * runners-heavy (min=1) - Docker builds, always available

    ------------------------------------------------------------
    STEP 1: Connect to the runners cluster
    ------------------------------------------------------------

    $ gcloud container clusters get-credentials ${module.gke_cluster.name} \
        --region ${var.region} --project ${var.project_id}

    ------------------------------------------------------------
    STEP 2: Install ARC Controller
    ------------------------------------------------------------

    # Create namespace for ARC controller
    $ kubectl create namespace arc-systems

    # Install ARC controller (will run on infra pool - no tolerations needed)
    $ helm install arc \
        --namespace arc-systems \
        oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

    ------------------------------------------------------------
    STEP 3: Create GitHub Secret
    ------------------------------------------------------------

    # Create namespace for runners
    $ kubectl create namespace arc-runners

    # Create GitHub App or PAT secret
    $ kubectl create secret generic arc-github-secret \
        --namespace arc-runners \
        --from-literal=github_token=<YOUR_PAT_OR_APP_TOKEN>

    ------------------------------------------------------------
    STEP 4: Install Runner Scale Set
    ------------------------------------------------------------

    # Heavy Runner Scale Set (all jobs including Docker builds)
    $ helm install arc-runner-heavy \
        --namespace arc-runners \
        --set githubConfigUrl="https://github.com/example-gamedev-org" \
        --set githubConfigSecret.github_token="arc-github-secret" \
        --set runnerScaleSetName="gameplatform-heavy" \
        --set minRunners=1 \
        --set maxRunners=10 \
        --set containerMode.type="dind" \
        --set template.spec.tolerations[0].key=runner-type \
        --set template.spec.tolerations[0].value=heavy \
        --set template.spec.tolerations[0].effect=NoSchedule \
        --set template.spec.nodeSelector.runner_type=heavy \
        oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

    ------------------------------------------------------------
    STEP 5: Verify Installation
    ------------------------------------------------------------

    $ kubectl get pods -n arc-systems    # Controller should be running
    $ kubectl get pods -n arc-runners    # Runner pods

    ------------------------------------------------------------
    WORKFLOW USAGE
    ------------------------------------------------------------

    In your GitHub Actions workflow:

    jobs:
      build:
        runs-on: gameplatform-heavy    # Uses heavy runner pool

    For detailed configuration, see:
    https://github.com/actions/actions-runner-controller
    ============================================================
  EOT
}
