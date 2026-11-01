# =============================================================================
# GamePlatform Custom GitHub Actions Runner
# =============================================================================
# Base: Official GitHub Actions Runner
# Includes: Node.js 20, Go 1.22, Python 3.11, Docker CLI, gcloud, kubectl, helm
# Pre-cached: npm dependencies for lobby and lobby-backend
#
# Build: docker build -t gameplatform-runner:latest .
# =============================================================================

FROM ghcr.io/actions/actions-runner:latest

# Switch to root to install packages
USER root

# =============================================================================
# ENVIRONMENT VARIABLES
# =============================================================================
ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_VERSION=20
ENV GO_VERSION=1.22.10
ENV PYTHON_VERSION=3.11
ENV HELM_VERSION=3.14.0
ENV YQ_VERSION=4.40.5

# =============================================================================
# SYSTEM PACKAGES
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    # Common tools
    curl \
    wget \
    git \
    jq \
    unzip \
    zip \
    gnupg \
    lsb-release \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    # Python build deps
    libssl-dev \
    libffi-dev \
    python3-dev \
    # For some npm packages
    libpng-dev \
    libjpeg-dev \
    # For Go CGO
    libc6-dev \
    # Network tools (for debugging)
    netcat-openbsd \
    dnsutils \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# NODE.JS 20.x
# =============================================================================
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest \
    && rm -rf /var/lib/apt/lists/*

# Verify Node installation
RUN node --version && npm --version

# =============================================================================
# GO 1.22.x
# =============================================================================
RUN curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz | tar -C /usr/local -xzf - \
    && ln -s /usr/local/go/bin/go /usr/local/bin/go \
    && ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt

# Set Go environment
ENV GOROOT=/usr/local/go
ENV GOPATH=/home/runner/go
ENV PATH="${GOPATH}/bin:${GOROOT}/bin:${PATH}"

# Verify Go installation
RUN go version

# =============================================================================
# PYTHON 3.11
# =============================================================================
RUN add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        python${PYTHON_VERSION} \
        python${PYTHON_VERSION}-venv \
        python${PYTHON_VERSION}-dev \
        python${PYTHON_VERSION}-distutils \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.11 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1 \
    && update-alternatives --install /usr/bin/python python /usr/bin/python${PYTHON_VERSION} 1

# Install pip
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python${PYTHON_VERSION}

# Verify Python installation
RUN python --version && pip --version

# =============================================================================
# DOCKER CLI (for DinD communication)
# =============================================================================
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-buildx-plugin \
    && rm -rf /var/lib/apt/lists/*

# Verify Docker CLI
RUN docker --version

# =============================================================================
# GOOGLE CLOUD SDK
# =============================================================================
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && apt-get update \
    && apt-get install -y google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin \
    && rm -rf /var/lib/apt/lists/*

# Verify gcloud
RUN gcloud version

# =============================================================================
# KUBECTL
# =============================================================================
RUN curl -fsSL "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Verify kubectl
RUN kubectl version --client

# =============================================================================
# HELM
# =============================================================================
RUN curl -fsSL https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz | tar -xzf - -C /tmp \
    && mv /tmp/linux-amd64/helm /usr/local/bin/helm \
    && rm -rf /tmp/linux-amd64

# Verify Helm
RUN helm version

# =============================================================================
# YQ (YAML processor)
# =============================================================================
RUN curl -fsSL https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64 -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# Verify yq
RUN yq --version

# =============================================================================
# CACHE DIRECTORIES
# =============================================================================
# Create cache directories with proper permissions
RUN mkdir -p /cache/npm \
    && mkdir -p /cache/go \
    && mkdir -p /cache/pip \
    && mkdir -p /home/runner/.npm \
    && mkdir -p /home/runner/go/pkg/mod \
    && mkdir -p /home/runner/.cache/pip \
    && mkdir -p /home/runner/.cache/go-build

# =============================================================================
# PRE-CACHE: NPM DEPENDENCIES (lobby)
# =============================================================================
WORKDIR /cache/npm/lobby
COPY package-lobby.json ./package.json
COPY package-lock-lobby.json ./package-lock.json
RUN npm ci --prefer-offline --no-audit \
    && cp -r node_modules /cache/npm/lobby-node_modules \
    && rm -rf node_modules

# =============================================================================
# PRE-CACHE: NPM DEPENDENCIES (lobby-backend)
# =============================================================================
WORKDIR /cache/npm/lobby-backend
COPY package-lobby-backend.json ./package.json
COPY package-lock-lobby-backend.json ./package-lock.json
RUN npm ci --prefer-offline --no-audit \
    && cp -r node_modules /cache/npm/lobby-backend-node_modules \
    && rm -rf node_modules

# =============================================================================
# PRE-CACHE: PYTHON PACKAGES (common)
# =============================================================================
WORKDIR /cache/pip
COPY requirements-common.txt ./
RUN pip install --no-cache-dir --ignore-installed -r requirements-common.txt

# =============================================================================
# SET PERMISSIONS
# =============================================================================
RUN chown -R runner:runner /cache \
    && chown -R runner:runner /home/runner

# =============================================================================
# SWITCH BACK TO RUNNER USER
# =============================================================================
USER runner
WORKDIR /home/runner

# Configure npm to use cache
RUN npm config set cache /home/runner/.npm

# Configure Go cache
ENV GOCACHE=/home/runner/.cache/go-build
ENV GOMODCACHE=/home/runner/go/pkg/mod

# Configure pip cache
ENV PIP_CACHE_DIR=/home/runner/.cache/pip

# =============================================================================
# LABELS
# =============================================================================
LABEL org.opencontainers.image.source="https://github.com/example-gamedev-org/platform-kubernetes-infrastructure"
LABEL org.opencontainers.image.description="GamePlatform Custom GitHub Actions Runner with Node.js, Go, Python, and cloud tools"
LABEL org.opencontainers.image.version="1.0.0"
