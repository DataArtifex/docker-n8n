#!/bin/sh
set -e

# 1. Custom Certificates Handling (from upstream n8nio/n8n entrypoint)
if [ -d /opt/custom-certificates ]; then
  echo "Trusting custom certificates from /opt/custom-certificates."
  export NODE_OPTIONS="--use-openssl-ca $NODE_OPTIONS"
  export SSL_CERT_DIR=/opt/custom-certificates
  c_rehash /opt/custom-certificates
fi

# Ensure shared data directory is writable by all stack services (node UID 1000 + runner UID 10001)
if [ -d /data/shared ]; then
  chmod 1777 /data/shared 2>/dev/null || true
fi

# 2. Auto-seed Demo Workflows on First Boot
SEEDED_FLAG="/home/node/.n8n/.workflows_seeded"
WORKFLOWS_DIR="/opt/n8n-workflows"

if [ -d "$WORKFLOWS_DIR" ] && [ ! -f "$SEEDED_FLAG" ]; then
  wf_count=$(find "$WORKFLOWS_DIR" -name "*.json" 2>/dev/null | wc -l)
  if [ "$wf_count" -gt 0 ]; then
    echo "=========================================================="
    echo "Found $wf_count demo workflow(s) in $WORKFLOWS_DIR."
    echo "Seeding initial workflows into n8n database..."
    echo "=========================================================="
    n8n import:workflow --separate --input="$WORKFLOWS_DIR" || echo "Notice: Workflow import finished with non-critical notes."
    mkdir -p /home/node/.n8n
    touch "$SEEDED_FLAG"
    echo "Initial workflow seeding complete."
    echo "=========================================================="
  fi
fi

# 3. Launch n8n Process
if [ "$#" -gt 0 ]; then
  exec n8n "$@"
else
  exec n8n
fi
