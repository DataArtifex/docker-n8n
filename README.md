# dartfx/docker-n8n

Comprehensive, production-ready Docker stack for **n8n** (supporting **n8n v3** and **v2**) with an external **Task Runner** sidecar, pre-installed **QSV** data wrangling toolkit, pre-configured **`@dartfx/n8n-nodes-qsv`** community nodes, and unified Python + Node execution powered by [`dartfx/docker-base`](https://github.com/DataArtifex/docker-base).

---

## Architecture Overview

```
                      ┌──────────────────────────────────────────────┐
                      │              Docker Host Network             │
                      │                                              │
                      │   ┌──────────────────────────────────────┐   │
                      │   │       dartfx/n8n (Main Service)      │   │
                      │   │  - n8n v3 / v2 Core Application      │   │
                      │   │  - /usr/local/bin/qsv (CLI)          │   │
                      │   │  - @dartfx/n8n-nodes-qsv Extension   │   │
                      │   │  - Task Broker (:5679)               │   │
                      │   └──────────────────┬───────────────────┘   │
                      │                      │                       │
                      │       HTTP/WebSocket │ :5679                 │
                      │                      ▼                       │
                      │   ┌──────────────────────────────────────┐   │
                      │   │   dartfx/n8n-runners (Sidecar)       │   │
                      │   │  - /usr/local/bin/task-runner-launch │   │
                      │   │  - Python Runner (/opt/venv)         │   │
                      │   │    (dartfx-*, psycopg, pandas, etc)  │   │
                      │   │  - Node Runner (Node 20, pnpm, nvm)  │   │
                      │   │  - Built on dartfx/docker-base       │   │
                      │   └──────────────────────────────────────┘   │
                      │                                              │
                      │   ┌──────────────────┐   ┌───────────────┐   │
                      │   │ PostgreSQL 18    │   │ Shared Volume │   │
                      │   │ (Production DB)  │   │ /data/shared  │   │
                      │   └──────────────────┘   └───────────────┘   │
                      └──────────────────────────────────────────────┘
```

### Key Highlights
* **n8n v3 & v2 Compatibility**: Toggle seamlessly between n8n v3 beta (`N8N_VERSION=next` or `v3-nightly`) and n8n v2 stable (`N8N_VERSION=latest`) with a single `.env` setting.
* **Unified Data Artifex Runner**: Built directly on `dartfx/docker-base` (Debian, Python 3.14, glibc), allowing native C-extension wheels (`psycopg`, `pandas`, `curl_cffi`) and all `dartfx-*` toolkits (`dartfx-qsv`, `dartfx-ckan`, `dartfx-dataverse`, `dartfx-ddi`, `dartfx-nada`, `dartfx-rdf`, `dartfx-unf`, `dartfx-utils`) inside Python Code nodes.
* **Node.js + `pnpm` + `nvm` Support**: Node.js LTS included in the task runner with `pnpm` active out of the box and `nvm` available for multi-version switching.
* **QSV Data Toolkit Available Everywhere**:
  * **On n8n Main Container**: The static musl binary `/usr/local/bin/qsv` is installed for high-speed CSV operations using the **Execute Command** node (`NODES_EXCLUDE=[]` enabled).
  * **n8n Community Nodes**: `@dartfx/n8n-nodes-qsv` is baked into `/opt/n8n-custom-nodes` and loaded via `N8N_CUSTOM_EXTENSIONS`.
  * **On Task Runner Container**: Available directly for shell or Python subprocess workflows.
* **PostgreSQL 18 Ready**: Ready-to-use production overlay (`docker-compose.prod.yml`) utilizing the PostgreSQL 18 volume directory standard (`/var/lib/postgresql`).
* **Shared Storage Volume**: Includes a shared mount at `/data/shared` so QSV commands on the main container and Python/Node code on the runner can read and write identical files.

---

## Quick Start (Local Testing)

### 1. Prerequisites
* Docker 24+ and Docker Compose v2.
* Ensure [`dartfx/docker-base:latest`](https://github.com/DataArtifex/docker-base) is built locally or available on Docker Hub:
  ```bash
  # If building locally from sibling repo:
  cd ../docker-base && docker build -t dartfx/docker-base:latest . && cd ../docker-n8n
  ```

### 2. Configure Environment Variables
Copy the template configuration file:
```bash
cp .env.example .env
```
Generate secure random keys for `N8N_ENCRYPTION_KEY` and `N8N_RUNNERS_AUTH_TOKEN`:
```bash
# On Linux/macOS:
openssl rand -hex 24
```
Paste the generated strings into `.env`.

To test **n8n v3**, leave `N8N_VERSION=next` (or `v3-nightly`). To test **n8n v2**, set `N8N_VERSION=latest`.

### 3. Build & Launch the Stack
```bash
docker compose up --build -d
```

### 4. Access n8n
Open your browser at:
```text
http://localhost:5678
```
Follow the onboarding steps to set up your owner account.

---

## Verifying Features in n8n

### 1. Test QSV CLI via the Execute Command Node
1. Create a new workflow and add an **Execute Command** node.
2. Set the command to:
   ```bash
   qsv --version
   ```
3. Execute the node. You will receive the output string containing the installed QSV version (e.g. `qsv 0.134.0 ...`).

### 2. Test `@dartfx/n8n-nodes-qsv` Community Nodes
1. Open the node selection panel in n8n.
2. Search for `QSV`.
3. You will see the Data Artifex QSV nodes pre-installed and ready for dragging into your canvas.

### 3. Test Python Code Node with `dartfx` Toolkits
1. Add a **Code** node and select **Python** mode.
2. Enter the following test code:
   ```python
   import pandas as pd
   import psycopg
   import dartfx.utils
   import dartfx.qsv

   df = pd.DataFrame({
       "city": ["Toronto", "Berlin", "Tokyo"],
       "population": [2930000, 3645000, 13960000]
   })

   return [{
       "json": {
           "status": "success",
           "cities_count": len(df),
           "dartfx_utils": str(dartfx.utils),
           "dartfx_qsv": str(dartfx.qsv)
       }
   }]
   ```
3. Execute the node. The task runner executes this in external mode within `/opt/venv`, returning JSON data seamlessly.

### 4. Test JavaScript Code Node
1. Add a **Code** node and select **JavaScript** mode.
2. Enter:
   ```javascript
   const items = [{ name: "Data Artifex", ready: true }];
   return items.map(item => ({ json: item }));
   ```
3. Execute the node to verify the JavaScript external runner.

---

## Pre-Configured Demo Workflows

The repository includes curated demo workflows in the [`workflows/`](file:///Users/pascal/Library/CloudStorage/Dropbox/git-dartfx/docker-n8n/workflows) directory:

| File | Workflow Name | Description |
| :--- | :--- | :--- |
| `01-smoke-test-all-engines.json` | **01: Smoke Test - All Runtime Engines** | Verifies QSV CLI, Python runner (`dartfx.*`, `pandas`, `curl_cffi`), and JS runner (`lodash`) in parallel |
| `02-qsv-data-wrangling.json` | **02: QSV CLI - CSV Wrangling & Analytics** | Generates tabular data in `/data/shared`, calculates statistical profiles, and runs filters/sorts with QSV |
| `03-python-dartfx-pipeline.json` | **03: Python Runner - DDI-Codebook Creation & Validation** | Creates, serializes to `/data/shared`, and validates a DDI-Codebook 2.6 document using `dartfx.ddi.ddicodebook` |

### Automatic First-Boot Seeding
When the `n8n` container boots for the first time, it automatically detects and imports all `.json` workflows located in `/opt/n8n-workflows` (bundled in the image and mounted from `./workflows`). They appear ready to run in your n8n workspace immediately upon visiting `http://localhost:5678`.

### Manual / On-Demand Importing
You can import newly added workflow files into the active n8n database at any time using the CLI:
```bash
docker compose exec n8n n8n import:workflow --separate --input=/opt/n8n-workflows
```

---

## Production Deployment (PostgreSQL 18)

For production deployments, execute the stack using the production overlay [`docker-compose.prod.yml`](file:///Users/pascal/Library/CloudStorage/Dropbox/git-dartfx/docker-n8n/docker-compose.prod.yml), which replaces SQLite with a dedicated PostgreSQL 18 container.

### 1. Configure Production Variables in `.env`
```ini
N8N_HOST=n8n.yourdomain.com
N8N_PROTOCOL=https
WEBHOOK_URL=https://n8n.yourdomain.com/
N8N_PORT=5678

# Critical Security Tokens
N8N_ENCRYPTION_KEY=<strong_generated_secret_32_characters>
N8N_RUNNERS_AUTH_TOKEN=<strong_generated_secret_32_characters>

# PostgreSQL 18 Database Credentials
POSTGRES_USER=n8n
POSTGRES_PASSWORD=<strong_generated_db_password>
POSTGRES_DB=n8n
```

### 2. Launch with Production Overlay
```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up --build -d
```

### 3. Production Security Checklist
* **Reverse Proxy / TLS**: Place n8n behind Traefik, Nginx, or Caddy terminating SSL/TLS.
* **Proxy Hops**: `N8N_PROXY_HOPS=1` is already included in `docker-compose.prod.yml` to correctly forward client IPs and HTTPS headers from your reverse proxy.
* **Firewall Broker Port**: Port `5679` (task runner broker) is communicated internally across the Docker network; do **not** expose port `5679` to the public internet.

---

## Persistence & Backup Strategy

Data persistence in this stack is split into three volumes:

| Volume Name | Mount Path in Container | Purpose |
| :--- | :--- | :--- |
| `dartfx_n8n_data` | `/home/node/.n8n` in `n8n` | Workflows, user profiles, credentials, community node settings |
| `dartfx_postgres_data` | `/var/lib/postgresql` in `postgres` | Full PostgreSQL 18 database cluster (`18/docker/...`) |
| `dartfx_shared_data` | `/data/shared` in `n8n` & `n8n-runners` | Shared staging files, CSV datasets, temporary pipeline exports |

### PostgreSQL 18 Data Layout Note
Starting with PostgreSQL 18, `PGDATA` defaults to `/var/lib/postgresql/18/docker`. Our stack mounts the declared volume at the parent `/var/lib/postgresql`, allowing clean major upgrades in the future.

### Backup Procedure
1. **Critical: Save `N8N_ENCRYPTION_KEY`**:
   Credentials saved in n8n are encrypted with this key. If this key is lost, your workflows cannot decrypt credentials. Store it securely in a password manager or vault.
2. **Database Backup**:
   ```bash
   docker exec -t n8n-postgres pg_dump -U n8n -d n8n | gzip > n8n_backup_$(date +%Y%m%d_%H%M%S).sql.gz
   ```
3. **Volume Backup**:
   Backup `n8n_data` and `shared_data` using standard volume snapshot or tar commands.

---

## Extending Python and Node Packages

### Adding Python Packages to Task Runner
1. Edit [`pyproject.toml`](file:///Users/pascal/Library/CloudStorage/Dropbox/git-dartfx/docker-n8n/pyproject.toml):
   ```toml
   dependencies = [
       # ... existing packages ...
       "scikit-learn>=1.4.0",
       "polars>=0.20.0",
   ]
   ```
2. If the package imports third-party or non-standard modules, ensure `n8n-task-runners.json` allows them (by default, `N8N_RUNNERS_EXTERNAL_ALLOW=*` allows all packages).
3. Rebuild the runner container:
   ```bash
   docker compose build n8n-runners
   docker compose up -d n8n-runners
   ```

### Adding Node Packages to Task Runner
Just like Python dependencies are configured in [`pyproject.toml`](file:///Users/pascal/Library/CloudStorage/Dropbox/git-dartfx/docker-n8n/pyproject.toml), extra Node dependencies are declared in [`package.json`](file:///Users/pascal/Library/CloudStorage/Dropbox/git-dartfx/docker-n8n/package.json):

1. Edit [`package.json`](file:///Users/pascal/Library/CloudStorage/Dropbox/git-dartfx/docker-n8n/package.json):
   ```json
   {
     "dependencies": {
       "axios": "^1.7.7",
       "lodash": "^4.17.21",
       "cheerio": "^1.0.0",
       "moment": "^2.30.1"
     }
   }
   ```
2. Rebuild the runner container:
   ```bash
   docker compose build n8n-runners
   docker compose up -d n8n-runners
   ```
   During the build, [`Dockerfile.runners`](file:///Users/pascal/Library/CloudStorage/Dropbox/git-dartfx/docker-n8n/Dockerfile.runners) automatically installs them into `/opt/runners/task-runner-javascript` using `pnpm`.
3. In [`n8n-task-runners.json`](file:///Users/pascal/Library/CloudStorage/Dropbox/git-dartfx/docker-n8n/n8n-task-runners.json), `NODE_FUNCTION_ALLOW_EXTERNAL: "*"` is already set, so all installed packages are instantly available to your **Code** nodes in JavaScript mode (`const axios = require('axios');`).

---

## Verifying & Publishing Images

### Automated Local Verification
A verification script is included to test system utilities, binary execution, and Python package imports across both containers:
```bash
./verify_images.sh
```

### Publishing to Container Registry (Docker Hub)
To build and publish multi-platform (`linux/amd64`, `linux/arm64`) images to Docker Hub:
```bash
./publish_images.sh --namespace dartfx --version next
```
For n8n v2 stable:
```bash
./publish_images.sh --namespace dartfx --version latest
```

---

## License

This project is licensed under the [MIT License](LICENSE).
