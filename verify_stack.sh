#!/usr/bin/env bash
set -euo pipefail

N8N_IMAGE="dartfx/n8n:${N8N_VERSION:-next}"
RUNNER_IMAGE="dartfx/n8n-runners:${N8N_VERSION:-next}"

echo "========================================================"
echo "=== Verifying Data Artifex n8n Stack Images ==="
echo "========================================================"
echo "Main Image:   ${N8N_IMAGE}"
echo "Runner Image: ${RUNNER_IMAGE}"
echo ""

# ------------------------------------------------------------------------------
# 1. Main n8n Image Verification
# ------------------------------------------------------------------------------
echo "--- 1. Testing n8n Main Container (${N8N_IMAGE}) ---"

echo -n "Checking QSV binary in n8n container... "
docker run --rm "${N8N_IMAGE}" qsv --version >/dev/null && echo "OK" || { echo "FAILED"; exit 1; }

echo -n "Checking @dartfx/n8n-nodes-qsv extension package directory... "
docker run --rm "${N8N_IMAGE}" ls -la /opt/n8n-custom-nodes/node_modules/@dartfx/n8n-nodes-qsv >/dev/null 2>&1 && echo "OK" || { echo "FAILED"; exit 1; }

# ------------------------------------------------------------------------------
# 2. Task Runner Container Verification
# ------------------------------------------------------------------------------
echo ""
echo "--- 2. Testing Task Runner Container (${RUNNER_IMAGE}) ---"

echo -n "Checking task-runner-launcher binary... "
docker run --rm --entrypoint /bin/bash "${RUNNER_IMAGE}" -c "test -x /usr/local/bin/task-runner-launcher" && echo "OK" || { echo "FAILED"; exit 1; }

echo -n "Checking Node.js & pnpm in runner... "
docker run --rm --entrypoint /bin/bash "${RUNNER_IMAGE}" -c "node -v && pnpm -v" >/dev/null && echo "OK" || { echo "FAILED"; exit 1; }

echo -n "Checking QSV binary in runner... "
docker run --rm --entrypoint /bin/bash "${RUNNER_IMAGE}" -c "qsv --version" >/dev/null && echo "OK" || { echo "FAILED"; exit 1; }

echo "Checking Python package imports in runner (/opt/venv)..."
PACKAGES=(
  "dartfx.utils"
  "dartfx.qsv"
  "dartfx.ckan"
  "dartfx.ddi"
  "dartfx.dataverse"
  "dartfx.nada"
  "dartfx.rdf"
  "dartfx.unf"
  "psycopg"
  "pandas"
  "openpyxl"
  "requests"
  "curl_cffi"
  "pypdf"
  "bs4"
)

for pkg in "${PACKAGES[@]}"; do
  echo -n "  - Importing ${pkg}... "
  docker run --rm --entrypoint /bin/bash "${RUNNER_IMAGE}" -c "python -c 'import ${pkg}'" >/dev/null 2>&1 && echo "OK" || { echo "FAILED"; exit 1; }
done

echo ""
echo "========================================================"
echo "=== All image verification checks passed successfully! ==="
echo "========================================================"
