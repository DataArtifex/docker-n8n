# AGENTS INSTRUCTIONS

This project builds a specialized Docker stack for n8n (supporting both n8n v3 and v2) and an external task runner for the Data Artifex ecosystem.

## Stack Components

1. **`dartfx/n8n` (`Dockerfile.n8n`)**:
   - Extends official `n8nio/n8n:${N8N_VERSION}` (default: `next` for v3, supports `latest` or specific versions for v2).
   - Bundles the latest static Linux musl binary of `qsv` at `/usr/local/bin/qsv` for execution via the Execute Command node.
   - Pre-installs the `@dartfx/n8n-nodes-qsv` community node package into `/opt/n8n-custom-nodes` and exposes it via `N8N_CUSTOM_EXTENSIONS`.
   - Allows execution commands via `NODES_EXCLUDE=[]`.

2. **`dartfx/n8n-runners` (`Dockerfile.runners`)**:
   - Extends `dartfx/docker-base:latest` (Debian, Python 3.14, glibc, QSV, and `dartfx-*` packages).
   - Extracts `task-runner-launcher` and n8n runner scripts from `n8nio/runners:${N8N_VERSION}`.
   - Installs Node.js LTS, `pnpm`, and `nvm`.
   - Symlinks `/opt/runners/task-runner-python/.venv` to `/opt/venv`, synchronizing additional Python packages via `pyproject.toml` and `uv`.
   - Runs as non-root user `appuser` (UID/GID 10001).

3. **`docker-compose.yml` & `docker-compose.prod.yml`**:
   - `docker-compose.yml`: Default stack for local development and workflow building (using SQLite persistence in `n8n_data`).
   - `docker-compose.prod.yml`: Production deployment stack adding `postgres:18-alpine` with version-specific data directory handling (`/var/lib/postgresql`), proxy configuration, and hardened security settings.

## Python and Node Packages

- Additional Python packages are defined in `pyproject.toml` and installed via `uv`.
- Additional Node packages for JavaScript code execution are defined in `package.json` and installed via `pnpm` in `/opt/runners/task-runner-javascript`.
- Package access controls and allowlists are configured in `n8n-task-runners.json`.
