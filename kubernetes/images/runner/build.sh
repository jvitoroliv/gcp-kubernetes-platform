#!/bin/bash
# =============================================================================
# Build GamePlatform Custom Runner Image
# =============================================================================
# Usage:
#   ./build.sh                    # Build locally
#   ./build.sh --push             # Build and push to Artifact Registry
#   ./build.sh --push --tag v1.0  # Build with specific tag
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONOREPO_PATH="${MONOREPO_PATH:-${SCRIPT_DIR}/../../../gameplatform-monorepo}"
REGISTRY="${REGISTRY:-us-east1-docker.pkg.dev/project-nonprod-env/gameplatform-nonprod-images}"
IMAGE_NAME="gameplatform-runner"
DEFAULT_TAG="latest"

# Parse arguments
PUSH=false
TAG="${DEFAULT_TAG}"
while [[ $# -gt 0 ]]; do
    case $1 in
        --push)
            PUSH=true
            shift
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "Building GamePlatform Runner Image"
echo "=========================================="
echo "Monorepo path: ${MONOREPO_PATH}"
echo "Registry: ${REGISTRY}"
echo "Image: ${IMAGE_NAME}:${TAG}"
echo "Push: ${PUSH}"
echo "=========================================="

# Validate monorepo path
if [[ ! -d "${MONOREPO_PATH}/applications/lobby" ]]; then
    echo "ERROR: Monorepo not found at ${MONOREPO_PATH}"
    echo "Set MONOREPO_PATH environment variable to the correct path"
    exit 1
fi

# Create temp directory for build context
BUILD_CONTEXT=$(mktemp -d)
trap "rm -rf ${BUILD_CONTEXT}" EXIT

echo ">>> Preparing build context..."

# Copy Dockerfile and requirements
cp "${SCRIPT_DIR}/Dockerfile" "${BUILD_CONTEXT}/"
cp "${SCRIPT_DIR}/requirements-common.txt" "${BUILD_CONTEXT}/"

# Copy package.json files from monorepo
echo ">>> Copying lobby package files..."
cp "${MONOREPO_PATH}/applications/lobby/package.json" "${BUILD_CONTEXT}/package-lobby.json"
cp "${MONOREPO_PATH}/applications/lobby/package-lock.json" "${BUILD_CONTEXT}/package-lock-lobby.json"

echo ">>> Copying lobby-backend package files..."
cp "${MONOREPO_PATH}/applications/lobby-backend/package.json" "${BUILD_CONTEXT}/package-lobby-backend.json"
cp "${MONOREPO_PATH}/applications/lobby-backend/package-lock.json" "${BUILD_CONTEXT}/package-lock-lobby-backend.json"

# Build image
echo ">>> Building Docker image..."
cd "${BUILD_CONTEXT}"

docker build \
    --platform linux/amd64 \
    -t "${IMAGE_NAME}:${TAG}" \
    -t "${REGISTRY}/${IMAGE_NAME}:${TAG}" \
    .

echo ">>> Build complete!"
echo "Local image: ${IMAGE_NAME}:${TAG}"

# Push if requested
if [[ "${PUSH}" == "true" ]]; then
    echo ">>> Authenticating with Artifact Registry..."
    gcloud auth configure-docker us-east1-docker.pkg.dev --quiet

    echo ">>> Pushing image to ${REGISTRY}/${IMAGE_NAME}:${TAG}..."
    docker push "${REGISTRY}/${IMAGE_NAME}:${TAG}"

    # Also tag and push as latest if not already latest
    if [[ "${TAG}" != "latest" ]]; then
        docker tag "${REGISTRY}/${IMAGE_NAME}:${TAG}" "${REGISTRY}/${IMAGE_NAME}:latest"
        docker push "${REGISTRY}/${IMAGE_NAME}:latest"
    fi

    echo ">>> Push complete!"
    echo "Image available at: ${REGISTRY}/${IMAGE_NAME}:${TAG}"
fi

echo "=========================================="
echo "Done!"
echo "=========================================="
