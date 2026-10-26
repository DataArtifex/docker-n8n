#!/usr/bin/env bash
set -euo pipefail

# Default configuration
DEFAULT_REGISTRY="docker.io"
DEFAULT_NAMESPACE="dartfx"
N8N_IMAGE_NAME="n8n"
RUNNER_IMAGE_NAME="n8n-runners"
DEFAULT_PLATFORM="linux/amd64,linux/arm64"

usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -n, --namespace <name>  Docker Hub namespace/username (default: $DEFAULT_NAMESPACE)"
  echo "  -v, --version <version> n8n version tag to build (e.g. next, v3-nightly, latest, 2.45.1) (default: from .env or 'next')"
  echo "  -t, --tag <tag>          Additional custom image tag to push"
  echo "  -r, --registry <url>     Target container registry (default: $DEFAULT_REGISTRY)"
  echo "  -p, --platform <plat>    Target platform (default: $DEFAULT_PLATFORM)"
  echo "  -s, --skip-verification  Skip running verify_images.sh before pushing"
  echo "  -f, --rebuild, --force   Force a clean rebuild with --no-cache"
  echo "  -h, --help               Show this help message"
  exit "${1:-1}"
}

NAMESPACE="$DEFAULT_NAMESPACE"
CUSTOM_TAG=""
REGISTRY="$DEFAULT_REGISTRY"
SKIP_VERIFICATION=false
REBUILD=false
PLATFORM="$DEFAULT_PLATFORM"

# Read default N8N_VERSION from .env if present
if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -a && source .env && set +a
fi
VERSION="${N8N_VERSION:-next}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -v|--version)
      VERSION="$2"
      shift 2
      ;;
    -t|--tag)
      CUSTOM_TAG="$2"
      shift 2
      ;;
    -r|--registry)
      REGISTRY="$2"
      shift 2
      ;;
    -p|--platform)
      PLATFORM="$2"
      shift 2
      ;;
    -s|--skip-verification)
      SKIP_VERIFICATION=true
      shift
      ;;
    -f|--rebuild|--force)
      REBUILD=true
      shift
      ;;
    -h|--help)
      usage 0
      ;;
    *)
      echo "Unknown option: $1"
      usage 1
      ;;
  esac
done

export N8N_VERSION="$VERSION"
N8N_LOCAL="${NAMESPACE}/${N8N_IMAGE_NAME}:${VERSION}"
RUNNER_LOCAL="${NAMESPACE}/${RUNNER_IMAGE_NAME}:${VERSION}"

# 1. Build local native images for verification
if [ "$SKIP_VERIFICATION" = false ]; then
  echo "=== Step 1: Building local native images for verification ==="
  BUILD_ARGS=(--build-arg "N8N_VERSION=${VERSION}")
  if [ "$REBUILD" = true ]; then
    BUILD_ARGS+=(--no-cache --pull)
  fi

  docker build "${BUILD_ARGS[@]}" -f Dockerfile.n8n -t "${N8N_LOCAL}" .
  docker build "${BUILD_ARGS[@]}" -f Dockerfile.runners -t "${RUNNER_LOCAL}" .

  # 2. Run verification script
  echo "=== Step 2: Running verify_images.sh ==="
  if [ -f "./verify_images.sh" ]; then
    ./verify_images.sh
  elif [ -f "./verify_stack.sh" ]; then
    ./verify_stack.sh
  else
    echo "Warning: verify_images.sh not found. Skipping verification."
  fi
  echo ""
else
  echo "=== Skipping local verification ==="
fi

# 3. Determine tags to push
TAGS=("$VERSION")
if [ -n "$CUSTOM_TAG" ]; then
  TAGS+=("$CUSTOM_TAG")
fi

echo "=== Step 3: Preparing to publish images ==="
echo "Target Registry: ${REGISTRY}/${NAMESPACE}"
echo "Images:          ${N8N_IMAGE_NAME}, ${RUNNER_IMAGE_NAME}"
echo "Tags:            ${TAGS[*]}"
echo "Platforms:       ${PLATFORM}"
echo ""

# Setup builder if building for multiple platforms
if [[ "$PLATFORM" == *","* ]]; then
  if ! docker buildx inspect multi-builder >/dev/null 2>&1; then
    echo "Creating new buildx builder 'multi-builder'..."
    docker buildx create --name multi-builder --use >/dev/null 2>&1 || true
  else
    docker buildx use multi-builder >/dev/null 2>&1 || true
  fi
  docker buildx inspect --bootstrap >/dev/null 2>&1 || true
fi

BUILDX_FLAGS=(--platform "${PLATFORM}" --build-arg "N8N_VERSION=${VERSION}" --push)
if [ "$REBUILD" = true ]; then
  BUILDX_FLAGS+=(--no-cache --pull)
fi

# Build and push n8n main image
N8N_TAGS_ARGS=()
for tag in "${TAGS[@]}"; do
  if [ "$REGISTRY" = "docker.io" ]; then
    N8N_TAGS_ARGS+=("-t" "${NAMESPACE}/${N8N_IMAGE_NAME}:${tag}")
  else
    N8N_TAGS_ARGS+=("-t" "${REGISTRY}/${NAMESPACE}/${N8N_IMAGE_NAME}:${tag}")
  fi
done

echo "Building & pushing ${N8N_IMAGE_NAME}..."
docker buildx build "${BUILDX_FLAGS[@]}" "${N8N_TAGS_ARGS[@]}" -f Dockerfile.n8n .

# Build and push runner image
RUNNER_TAGS_ARGS=()
for tag in "${TAGS[@]}"; do
  if [ "$REGISTRY" = "docker.io" ]; then
    RUNNER_TAGS_ARGS+=("-t" "${NAMESPACE}/${RUNNER_IMAGE_NAME}:${tag}")
  else
    RUNNER_TAGS_ARGS+=("-t" "${REGISTRY}/${NAMESPACE}/${RUNNER_IMAGE_NAME}:${tag}")
  fi
done

echo "Building & pushing ${RUNNER_IMAGE_NAME}..."
docker buildx build "${BUILDX_FLAGS[@]}" "${RUNNER_TAGS_ARGS[@]}" -f Dockerfile.runners .

echo ""
echo "=== Successfully published all images! ==="
