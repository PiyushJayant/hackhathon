# Multi-Agent Productivity Assistant

### Hack2Skill x GCP Hackathon - Multi-Track Submission

A production-ready multi-agent AI system that manages tasks, notes, calendar events,
and productivity analytics - built entirely on Google Cloud.

---

## Architecture

```
User Request
    |
    v
root_agent  (Coordinator - Gemini 2.5 Flash, LlmAgent)
    |
    |-- task_agent      --> MCP Toolbox --> AlloyDB  (tasks table)
    |
    |-- notes_agent     --> MCP Toolbox --> AlloyDB  (notes + VECTOR embeddings)
    |                                        +-- text-embedding-005 via AlloyDB AI
    |
    |-- calendar_agent  --> MCP Toolbox --> AlloyDB  (events table)
    |
    +-- analytics_agent --> BigQuery MCP --> BigQuery (productivity_analytics)
                            (Google-hosted,
                             StreamableHTTP)
```

---

## GCP Services Used (All Three Tracks)

| Track | Service | Role |
|-------|---------|------|
| Track 1 | **Google ADK** | Agent framework - `LlmAgent`, multi-agent routing |
| Track 1 | **Gemini 2.5 Flash** | LLM for all agents via Vertex AI |
| Track 1 | **Cloud Run** | Serverless deployment of the ADK app |
| Track 1 | **Vertex AI** | Model inference backend (`GOOGLE_GENAI_USE_VERTEXAI=true`) |
| Track 2 | **MCP Toolbox for Databases** | Exposes AlloyDB tools to ADK agents via MCP |
| Track 2 | **BigQuery MCP Server** | Google-hosted remote MCP for analytics queries |
| Track 3 | **AlloyDB for PostgreSQL** | Primary data store (tasks, notes, events) |
| Track 3 | **AlloyDB AI** | `embedding('text-embedding-005', ...)` for vector embeddings |
| Track 3 | **pgvector / ScaNN** | Semantic similarity search on notes |
| Track 3 | **BigQuery** | Analytics data warehouse (`productivity_analytics`) |

---

## Project Structure

```
hackhathon/
|-- main.py                           # FastAPI entrypoint (ADK get_fast_api_app)
|-- requirements.txt                  # Python dependencies
|-- Dockerfile                        # Container image for Cloud Run (python:3.11-slim)
|-- Dockerfile.toolbox                # Container for MCP Toolbox service
|-- Procfile                          # Buildpacks entrypoint (fallback)
|-- cloudbuild.toolbox.yaml           # Cloud Build config for toolbox image
|-- .env.example                      # Environment variables template
|-- .gcloudignore                     # Files excluded from Cloud Build uploads
|-- .gitignore                        # Files excluded from git
|
|-- productivity_assistant/           # ADK agent package
|   |-- __init__.py                   # Package entry point
|   |-- agent.py                      # root_agent (coordinator)
|   |-- tools.py                      # Shared MCP helpers (Toolbox + BigQuery)
|   +-- sub_agents/
|       |-- __init__.py
|       |-- task_agent.py             # AlloyDB task CRUD via MCP Toolbox
|       |-- notes_agent.py            # AlloyDB notes + semantic search via MCP Toolbox
|       |-- calendar_agent.py         # AlloyDB calendar events via MCP Toolbox
|       +-- analytics_agent.py        # BigQuery MCP (Google-hosted, StreamableHTTP)
|
|-- mcp_toolbox/
|   +-- tools.yaml                    # MCP Toolbox config: AlloyDB source + 11 SQL tools
|
|-- setup/
|   |-- setup.sh                      # One-step setup: .env + IAM roles + API enablement
|   |-- deploy.sh                     # Unified deploy: --mode full|toolbox|assistant|prototype
|   |-- create_alloydb.sh             # Create AlloyDB cluster + instance
|   |-- apply_schema.sh               # Apply SQL schema via AlloyDB Auth Proxy
|   |-- alloydb_schema.sql            # Tables, extensions, pgvector + ScaNN index
|   |-- setup_bigquery.sh             # Wrapper to run bigquery_setup.py
|   |-- bigquery_setup.py             # Creates BigQuery dataset + tables + seed data
|   +-- start_toolbox_local.sh        # Download + run MCP Toolbox binary locally
|
+-- cleanup/
    |-- cleanup_env.sh                # Remove .env + optionally disable APIs
    +-- cleanup_bigquery.sh           # Delete productivity_analytics dataset
```

---

## Quick Start

### Prerequisites

```bash
# Authenticate and set project
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

# Create Python virtual environment
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Option 1: Full Setup (All Agents)

```bash
# 1. Setup environment + IAM
./setup/setup.sh all

# 2. Create AlloyDB cluster (skip if using existing codelab cluster)
./setup/create_alloydb.sh

# 3. Apply schema (via AlloyDB Studio or Auth Proxy)
#    Option A: AlloyDB Studio (recommended for private IP)
#      - Go to: https://console.cloud.google.com/alloydb
#      - Open AlloyDB Studio for your instance
#      - Paste contents of setup/alloydb_schema.sql
#    Option B: Auth Proxy (requires VPC routing)
#      ./setup/apply_schema.sh

# 4. Setup BigQuery analytics
./setup/setup_bigquery.sh

# 5. Deploy everything to Cloud Run
./setup/deploy.sh --mode full
```

### Option 2: Prototype Mode (Analytics Agent Only)

No AlloyDB or MCP Toolbox required. Deploys only the BigQuery analytics agent:

```bash
# 1. Setup environment + IAM
./setup/setup.sh all

# 2. Setup BigQuery analytics
./setup/setup_bigquery.sh

# 3. Deploy in prototype mode
./setup/deploy.sh --mode prototype
```

---

## Local Development

Run the toolbox and ADK in two terminals:

**Terminal 1: Start MCP Toolbox (binary)**

```bash
cd ~/hackhathon
source .venv/bin/activate
set -a; source .env; set +a
./setup/start_toolbox_local.sh
```

Downloads toolbox v0.23.0 automatically and runs on http://localhost:5000.

> **Note:** Local toolbox requires VPC routing to private AlloyDB. If using Cloud Shell
> with private AlloyDB, deploy to Cloud Run instead (`./setup/deploy.sh --mode full`).

**Terminal 2: Start ADK Web UI**

```bash
cd ~/hackhathon
source .venv/bin/activate
set -a; source .env; set +a
adk web
```

Opens http://localhost:8000 with all agents:
- **Task Agent**: Create, update, delete, list tasks (AlloyDB)
- **Notes Agent**: Semantic search + CRUD with AI embeddings (AlloyDB + text-embedding-005)
- **Calendar Agent**: Schedule, list, delete events (AlloyDB)
- **Analytics Agent**: Productivity stats and trends (BigQuery)

---

## Deployment to Cloud Run

The unified `deploy.sh` script handles all deployment modes:

```bash
# Deploy everything (toolbox + assistant with VPC connector)
./setup/deploy.sh --mode full

# Deploy only the MCP Toolbox service
./setup/deploy.sh --mode toolbox

# Deploy only the assistant (requires toolbox already running)
./setup/deploy.sh --mode assistant

# Deploy analytics-only prototype (no AlloyDB needed)
./setup/deploy.sh --mode prototype
```

### What the script does:

1. Enables required GCP APIs
2. Loads environment from `.env`
3. For `full` / `toolbox` modes:
   - Creates Artifact Registry repo
   - Creates VPC connector for private AlloyDB
   - Builds and deploys MCP Toolbox to Cloud Run
4. For `full` / `assistant` / `prototype` modes:
   - Deploys ADK app via Dockerfile
   - Sets `GOOGLE_GENAI_USE_VERTEXAI=true` for Vertex AI
   - Sets `GOOGLE_CLOUD_LOCATION=us-central1` for regional endpoint
   - Prints the Cloud Run URL

### Manual deployment (if needed):

```bash
gcloud run deploy productivity-assistant \
  --source . \
  --region us-central1 \
  --set-env-vars "PROTOTYPE_MODE=true,GOOGLE_CLOUD_PROJECT=YOUR_PROJECT,GOOGLE_CLOUD_LOCATION=us-central1,GOOGLE_GENAI_USE_VERTEXAI=true" \
  --allow-unauthenticated \
  --memory 1Gi \
  --timeout 300 \
  --clear-base-image
```

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `GOOGLE_CLOUD_PROJECT` | GCP project ID | Required |
| `GOOGLE_CLOUD_LOCATION` | Vertex AI region | `us-central1` |
| `GOOGLE_GENAI_USE_VERTEXAI` | Use Vertex AI instead of Gemini API key | `true` |
| `MODEL` | Gemini model name | `gemini-2.5-flash` |
| `PROTOTYPE_MODE` | Skip AlloyDB agents, analytics only | `false` |
| `TOOLBOX_URL` | MCP Toolbox server URL | `http://127.0.0.1:5000` |
| `ALLOYDB_REGION` | AlloyDB cluster region | `us-central1` |
| `ALLOYDB_CLUSTER` | AlloyDB cluster name | `productivity-cluster` |
| `ALLOYDB_INSTANCE` | AlloyDB instance name | `productivity-instance` |
| `ALLOYDB_DATABASE` | Database name | `postgres` |
| `ALLOYDB_USER` | Database user | `postgres` |
| `ALLOYDB_PASSWORD` | Database password | Required |
| `ALLOYDB_IP_TYPE` | AlloyDB IP type | `private` |
| `VPC_CONNECTOR` | VPC connector name | `toolbox-vpc-connector` |
| `VPC_NETWORK` | VPC network name | `easy-alloydb-vpc` |

Copy `.env.example` to `.env` and fill in your values, or run `./setup/setup.sh env` to generate it.

---

## Example Conversations

```
User: Create a high-priority task to "Prepare hackathon demo" due 2026-04-10

User: Add a note titled "Demo ideas" about "Use real-time streaming for live showcase"
      tagged with hackathon,ideas

User: Find notes related to "presentation" (semantic search via AlloyDB AI)

User: Schedule a team sync for 2026-04-09 at 14:00 for 45 minutes

User: How was my task completion rate this week?  (BigQuery analytics)

User: Create a task for the review, note the feedback points, and schedule a follow-up
      (multi-step: routes to task_agent -> notes_agent -> calendar_agent)
```

---

## Cleanup

```bash
# Delete BigQuery dataset
./cleanup/cleanup_bigquery.sh

# Remove .env and optionally disable APIs
./cleanup/cleanup_env.sh
```

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **MCP Toolbox for AlloyDB** | Separates AI reasoning from data access; clean declarative SQL in `tools.yaml` (Track 2 codelab pattern) |
| **Google-hosted BigQuery MCP** | Uses `StreamableHTTPConnectionParams` + OAuth ADC - same pattern as Location Intelligence codelab |
| **AlloyDB AI embeddings** | `embedding('text-embedding-005', ...)` called inside SQL - in-database intelligence (Track 3 codelab pattern) |
| **ScaNN index on notes** | Scalable nearest-neighbour search as taught in AlloyDB Quick Setup codelab |
| **LLM-driven routing** | ADK's built-in sub-agent transfer via `description` fields - no manual routing code |
| **Vertex AI backend** | `GOOGLE_GENAI_USE_VERTEXAI=true` - enterprise-grade inference on Cloud Run via ADC |
| **Prototype mode** | `PROTOTYPE_MODE=true` deploys analytics-only, bypassing AlloyDB for quick demos |
| **Dockerfile deployment** | Consistent builds with `python:3.11-slim`, avoids Buildpack conflicts |

---

## Codelabs Referenced

1. [Build a Multi-Agent Application with Google ADK](https://codelabs.developers.google.com/adk-multi-agent)
2. [Build Agentic Applications with Vertex AI and ADK](https://codelabs.developers.google.com/vertex-ai-adk)
3. [MCP Toolbox for Databases with AlloyDB](https://codelabs.developers.google.com/mcp-toolbox-alloydb)
4. [MCP Toolbox for Databases with BigQuery](https://codelabs.developers.google.com/mcp-toolbox-bigquery)
5. [AlloyDB Quick Setup](https://codelabs.developers.google.com/quick-alloydb-setup)
6. [AlloyDB AI + LangChain RAG](https://codelabs.developers.google.com/alloydb-ai-langchain)
