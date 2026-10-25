# Data Artifex n8n & Task Runner Docker Stack

Official Data Artifex Docker images for hosting **n8n** (v3 and v2) with an isolated, high-performance external **Task Runner** sidecar.

## Overview

* **`dartfx/n8n`**: Official n8n application runtime packaged with the high-performance **QSV** command-line data toolkit and pre-installed **`@dartfx/n8n-nodes-qsv`** community extensions.
* **`dartfx/n8n-runners`**: Unified external task runner sidecar built on `dartfx/docker-base` (Debian, Python 3.14, glibc), featuring all Data Artifex Python toolkits (`dartfx-*`, `psycopg`, `pandas`, `openpyxl`, `curl_cffi`), Node.js LTS with `pnpm` and `nvm`, and n8n's `task-runner-launcher`.

## Quick Docker Compose Setup

```yaml
services:
  n8n:
    image: dartfx/n8n:next
    container_name: n8n-main
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=localhost
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=http://localhost:5678/
      - N8N_ENCRYPTION_KEY=replace_with_a_secure_encryption_key_32chars
      - N8N_RUNNERS_MODE=external
      - N8N_RUNNERS_BROKER_LISTEN_ADDRESS=0.0.0.0
      - N8N_RUNNERS_AUTH_TOKEN=replace_with_a_secure_runner_auth_token_32chars
      - NODES_EXCLUDE=[]
      - N8N_COMMUNITY_PACKAGES_ENABLED=true
      - N8N_CUSTOM_EXTENSIONS=/opt/n8n-custom-nodes
    volumes:
      - n8n_data:/home/node/.n8n
      - shared_data:/data/shared

  n8n-runners:
    image: dartfx/n8n-runners:next
    container_name: n8n-task-runner
    restart: unless-stopped
    environment:
      - N8N_RUNNERS_MODE=external
      - N8N_RUNNERS_AUTH_TOKEN=replace_with_a_secure_runner_auth_token_32chars
      - N8N_RUNNERS_TASK_BROKER_URI=http://n8n:5679
    volumes:
      - shared_data:/data/shared
    depends_on:
      - n8n

volumes:
  n8n_data:
  shared_data:
```

## Features

* **Run QSV from Workflows**: Execute high-performance CSV transforms in n8n workflows using either the built-in Execute Command node (`qsv`) or the pre-installed `@dartfx/n8n-nodes-qsv` community node.
* **Full Python Ecosystem**: Import `dartfx.utils`, `dartfx.qsv`, `dartfx.ckan`, `psycopg`, `pandas`, `requests`, and `curl_cffi` natively in Code nodes without build-time dependency headaches.
* **Production Postgres 18 Ready**: Compatible with PostgreSQL 18 volume structures (`/var/lib/postgresql`).
* **Source Repository**: [https://github.com/DataArtifex/docker-n8n](https://github.com/DataArtifex/docker-n8n)
