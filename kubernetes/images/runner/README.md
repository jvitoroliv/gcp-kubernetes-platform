# GamePlatform Custom GitHub Actions Runner

Custom runner image for GitHub Actions with pre-installed tools and cached dependencies.

## Overview

This image extends the official GitHub Actions runner with:
- **Node.js 20** + npm (with cached dependencies for lobby and lobby-backend)
- **Go 1.22** + module cache
- **Python 3.11** + common packages
- **Docker CLI** + Buildx (for DinD mode)
- **Cloud tools**: gcloud, kubectl, helm, yq

## Build Times Comparison

| Task | Standard Runner | Custom Runner | Improvement |
|------|----------------|---------------|-------------|
| npm ci (lobby) | ~4 min | ~30 sec | **8x faster** |
| npm ci (lobby-backend) | ~2 min | ~20 sec | **6x faster** |
| go mod download | ~1 min | ~10 sec | **6x faster** |
| pip install | ~1 min | ~10 sec | **6x faster** |

## Usage

### In GitHub Actions Workflow

```yaml
jobs:
  build:
    runs-on: gameplatform-heavy  # Uses the custom runner
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies (uses cache)
        run: |
          cd applications/lobby
          # Copy pre-cached node_modules if available
          if [ -d "/cache/npm/lobby-node_modules" ]; then
            cp -r /cache/npm/lobby-node_modules ./node_modules
          fi
          npm ci --prefer-offline
```

### Build Locally

```bash
# From the repository root
cd images/runner

# Set path to monorepo (for package.json files)
export MONOREPO_PATH=/path/to/gameplatform-monorepo

# Build locally
./build.sh

# Build and push to Artifact Registry
./build.sh --push

# Build with specific tag
./build.sh --push --tag v1.0.0
```

### Build via GitHub Actions

The image is automatically rebuilt:
- **On push**: When files in `images/runner/` change
- **Weekly**: Every Sunday at 6 AM UTC (for security updates)
- **Manual**: Via workflow_dispatch in GitHub Actions

## Pre-cached Dependencies

### NPM (Node.js)

Cached at `/cache/npm/`:
- `lobby-node_modules/` - Full node_modules for lobby app
- `lobby-backend-node_modules/` - Full node_modules for lobby-backend

### Python

Pre-installed packages (see `requirements-common.txt`):
- FastAPI, uvicorn, pydantic
- Flask, flask_cors
- requests, aiohttp
- psycopg2-binary, asyncpg
- gunicorn

### Go

The Go module cache is pre-warmed at `/home/runner/go/pkg/mod`.

## Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| `NPM_CACHE_DIR` | `/cache/npm` | NPM cache location |
| `GOMODCACHE` | `/home/runner/go/pkg/mod` | Go modules cache |
| `GOCACHE` | `/home/runner/.cache/go-build` | Go build cache |
| `PIP_CACHE_DIR` | `/home/runner/.cache/pip` | Pip cache |

## Updating the Image

### When to Update

1. **Dependency updates**: When lobby or lobby-backend package.json changes significantly
2. **Tool version updates**: When upgrading Node.js, Go, or Python versions
3. **Security updates**: Weekly automatic rebuilds

### How to Update

1. Modify `Dockerfile` or dependency files
2. Commit and push to main branch
3. GitHub Actions will automatically build and push
4. Redeploy ARC runner scale set:

```bash
# Connect to runners cluster (via VPN - cluster is private)
gcloud container clusters get-credentials gameplatform-nonprod-runners \
  --region us-east1 --project project-nonprod-env --internal-ip

# Upgrade the runner scale set
helm upgrade arc-runner-heavy \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  -n arc-runners \
  -f charts/runners/runner-heavy/values.yaml
```

## Installed Tools

| Tool | Version | Path |
|------|---------|------|
| Node.js | 20.x | `/usr/bin/node` |
| npm | latest | `/usr/bin/npm` |
| Go | 1.22.x | `/usr/local/go/bin/go` |
| Python | 3.11 | `/usr/bin/python` |
| pip | latest | `/usr/bin/pip` |
| Docker CLI | latest | `/usr/bin/docker` |
| gcloud | latest | `/usr/bin/gcloud` |
| kubectl | latest | `/usr/local/bin/kubectl` |
| helm | 3.14.x | `/usr/local/bin/helm` |
| yq | 4.40.x | `/usr/local/bin/yq` |

## Troubleshooting

### Image pull fails

```bash
# Check if runner pods can pull from Artifact Registry
kubectl describe pod -n arc-runners -l app.kubernetes.io/name=arc-runner-heavy

# Verify the image exists
gcloud artifacts docker images list \
  us-east1-docker.pkg.dev/project-nonprod-env/project-dev-gameplatform \
  --filter="package=gameplatform-runner"
```

### Cache not being used

Ensure the workflow copies from the cache directory:
```yaml
- name: Use cached dependencies
  run: |
    if [ -d "/cache/npm/lobby-node_modules" ]; then
      cp -r /cache/npm/lobby-node_modules ./node_modules
      echo "Using cached node_modules"
    fi
    npm ci --prefer-offline
```

### Build fails

Check the build logs in GitHub Actions:
1. Go to Actions tab in the repository
2. Find "Build Runner Image" workflow
3. Check the logs for errors

## Files

```
images/runner/
├── Dockerfile               # Main Dockerfile
├── build.sh                 # Local build script
├── requirements-common.txt  # Python packages to pre-install
└── README.md               # This file
```
