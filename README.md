# Multi-Agent Productivity Assistant
### Hack2Skill × GCP Hackathon — Multi-Track Submission

A production-ready multi-agent AI system that manages tasks, notes, calendar events,
and productivity analytics — built entirely on Google Cloud.

---

## Architecture

```
User Request
    │
    ▼
root_agent  (Coordinator — Gemini 2.5 Flash, LlmAgent)
    │
    ├── task_agent      ──► MCP Toolbox ──► AlloyDB  (tasks table)
    │
    ├── notes_agent     ──► MCP Toolbox ──► AlloyDB  (notes + VECTOR embeddings)
    │                                        └── text-embedding-005 via AlloyDB AI
    │
    ├── calendar_agent  ──► MCP Toolbox ──► AlloyDB  (events table)
    │
    └── analytics_agent ──► BigQuery MCP  ──► BigQuery  (productivity_analytics)
                            (Google-hosted,
                             StreamableHTTP)
```

---

## GCP Services Used (All Three Tracks)

| Track | Service | Role |
|-------|---------|------|
| Track 1 | **Google ADK** | Agent framework — `LlmAgent`, multi-agent routing |
| Track 1 | **Gemini 2.5 Flash** | LLM for all agents via Vertex AI |
| Track 1 | **Cloud Run** | Serverless deployment of the ADK app |
| Track 1 | **Vertex AI** | Model inference backend |
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
├── productivity_assistant/           # ADK agent package
│   ├── __init__.py                   # Package entry point
│   ├── agent.py                      # root_agent (coordinator)
│   ├── tools.py                      # Shared MCP helpers for BigQuery and toolbox-backed agents
│   └── sub_agents/
│       ├── task_agent.py             # Optional AlloyDB task agent via MCP Toolbox
│       ├── notes_agent.py            # Optional AlloyDB notes agent via MCP Toolbox
│       ├── calendar_agent.py         # Optional AlloyDB calendar agent via MCP Toolbox
│       └── analytics_agent.py        # Hosted BigQuery MCP (StreamableHTTP)
├── mcp_toolbox/
│   └── tools.yaml                    # MCP Toolbox: AlloyDB source + 11 tools
├── setup/
│   ├── alloydb_schema.sql            # AlloyDB tables + pgvector + ScaNN index
│   ├── bigquery_setup.py            # BigQuery dataset, tables, seed data
│   ├── setup_env.sh                 # Enables APIs and writes .env
│   └── setup_bigquery.sh            # Runs the Python BigQuery bootstrapper
├── cleanup/
│   ├── cleanup_env.sh               # Removes .env and optionally disables APIs
│   └── cleanup_bigquery.sh          # Deletes the productivity_analytics dataset
├── main.py                           # FastAPI entrypoint (ADK get_fast_api_app)
├── requirements.txt
├── Dockerfile
└── .env.example
```

---

## Setup Guide

### 1. Prerequisites

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

Enable APIs:
```bash
gcloud services enable \
  run.googleapis.com \
  alloydb.googleapis.com \
  bigquery.googleapis.com \
  aiplatform.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com
```

### 2. AlloyDB Setup

Follow the [AlloyDB Quick Setup codelab](https://codelabs.developers.google.com/quick-alloydb-setup) to create a cluster and instance, then:

```bash
# Connect to AlloyDB and run the schema
psql "host=YOUR_ALLOYDB_IP dbname=productivity user=postgres" \
  -f setup/alloydb_schema.sql
```

This creates:
- `tasks` table
- `notes` table with `VECTOR(768)` column + ScaNN index
- `events` table
- Enables `vector` and `google_ml_integration` extensions

### 3. BigQuery Analytics Setup

```bash
export GOOGLE_CLOUD_PROJECT=your-project-id
python setup/bigquery_setup.py
```

Creates `productivity_analytics` dataset with `task_summary` and `daily_activity` tables and seeds demo data.

### 4. Repo Setup Scripts

If you want the same one-step flow used in the MCP demo, run the repo scripts instead of calling the commands manually:

```bash
chmod +x setup/setup_env.sh setup/setup_bigquery.sh cleanup/cleanup_env.sh cleanup/cleanup_bigquery.sh
./setup/setup_env.sh
./setup/setup_bigquery.sh
```

`setup/setup_env.sh` enables the required APIs and writes a local `.env` file. `setup/setup_bigquery.sh` provisions the analytics dataset using the Python bootstrapper already in this repo.

### 5. MCP Toolbox

Download and run the [MCP Toolbox for Databases](https://github.com/googleapis/genai-toolbox) if you want the AlloyDB-backed task, note, and calendar agents:

```bash
# Set AlloyDB environment variables (matches tools.yaml ${...} refs)
export GOOGLE_CLOUD_PROJECT=your-project-id
export ALLOYDB_REGION=us-central1
export ALLOYDB_CLUSTER=productivity-cluster
export ALLOYDB_INSTANCE=productivity-instance
export ALLOYDB_DATABASE=productivity
export ALLOYDB_USER=postgres
export ALLOYDB_PASSWORD=your-password

# Start the toolbox (runs on port 5000 by default)
./toolbox --tools-file mcp_toolbox/tools.yaml
```

If you are using Cloud Shell only and want to try the analytics agent first, you can skip this step. The app will still start, but only the hosted BigQuery sub-agent will be available until `TOOLBOX_URL` points to a running toolbox server.

### 6. Local Development

```bash
pip install -r requirements.txt
cp .env.example .env  # Fill in your values

# Option A — ADK dev UI
adk web

# Option B — FastAPI directly
python main.py
```

Open `http://localhost:8000` for the ADK chat UI.

### 7. Local Development (Recommended for Testing)

Run toolbox and ADK in parallel terminals. The toolbox binary approach is the fastest way to get all agents working locally.

**Terminal 1: Start MCP Toolbox (binary)**

```bash
cd ~/hackhathon
source .venv/bin/activate
set -a; source .env; set +a

chmod +x setup/start_toolbox_local.sh
./setup/start_toolbox_local.sh
```

The script automatically downloads toolbox v0.23.0 and starts it on http://localhost:5000
with your MCP tools configured.

**Terminal 2: Start ADK Web**

```bash
cd ~/hackhathon
source .venv/bin/activate
adk web
```

Opens http://localhost:8000 in your browser. All agents are available:
- **Task Agent**: Create, update, delete, list tasks (AlloyDB)
- **Notes Agent**: Semantic search, create, delete notes with AI embeddings (AlloyDB + text-embedding-005)
- **Calendar Agent**: Schedule events, list, delete (AlloyDB)
- **Analytics Agent**: Productivity stats and trends (BigQuery — always available)


### 8. Deploy to Cloud Run

Production deployment should run two services: toolbox and assistant.

First, set up IAM roles for your service account:
**Note:** Local development with Terminal 1 + Terminal 2 workflow above is recommended first.
If you need Cloud Run deployment for the hackathon submission, follow these steps:

```bash
chmod +x setup/setup_iam.sh
./setup/setup_iam.sh
```

This creates the service account and grants necessary roles for Vertex AI, AlloyDB, and BigQuery.

Then deploy both services:

```bash
chmod +x setup/deploy_toolbox_cloud_run.sh setup/deploy_assistant_cloud_run.sh setup/deploy_all_cloud_run.sh
```

Deploy toolbox first:

```bash
export GOOGLE_CLOUD_PROJECT=your-project-id
export REGION=us-central1
export ALLOYDB_REGION=us-central1
export ALLOYDB_CLUSTER=productivity-cluster
export ALLOYDB_INSTANCE=productivity-instance
export ALLOYDB_DATABASE=productivity
export ALLOYDB_USER=postgres
export ALLOYDB_PASSWORD=your-password

./setup/deploy_toolbox_cloud_run.sh
```

Then deploy the assistant and point it to the toolbox URL:

```bash
export SERVICE_ACCOUNT=your-sa@your-project-id.iam.gserviceaccount.com
./setup/deploy_assistant_cloud_run.sh
```

The scripts implement the correct separation of concerns:
- `setup/deploy_toolbox_cloud_run.sh` builds `Dockerfile.toolbox` and deploys the MCP toolbox service.
- `setup/deploy_assistant_cloud_run.sh` deploys the ADK app and injects `TOOLBOX_URL`.

Or run both sequentially with validation:

```bash
./setup/deploy_all_cloud_run.sh
```

`setup/deploy_all_cloud_run.sh` deploys toolbox first, validates toolbox reachability, then deploys the assistant.

### 9. Cleanup

When you are done, you can remove the local configuration and the analytics dataset with:

```bash
./cleanup/cleanup_bigquery.sh
./cleanup/cleanup_env.sh
```

`cleanup/cleanup_bigquery.sh` deletes the `productivity_analytics` dataset. `cleanup/cleanup_env.sh` removes `.env` and can optionally disable the APIs enabled during setup.

**IAM Roles required on the service account:**
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:YOUR_SA" \
  --role="roles/aiplatform.user"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:YOUR_SA" \
  --role="roles/alloydb.client"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:YOUR_SA" \
  --role="roles/bigquery.user"
```

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
      (multi-step: routes to task_agent → notes_agent → calendar_agent)
```

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **MCP Toolbox for AlloyDB** | Separates AI reasoning from data access; clean declarative SQL in `tools.yaml` (Track 2 codelab pattern) |
| **Google-hosted BigQuery MCP** | Uses `StreamableHTTPConnectionParams` + OAuth ADC — same pattern as Location Intelligence codelab |
| **AlloyDB AI embeddings** | `embedding('text-embedding-005', ...)` called inside SQL — in-database intelligence (Track 3 codelab pattern) |
| **ScaNN index on notes** | Scalable nearest-neighbour search as taught in AlloyDB Quick Setup codelab |
| **LLM-driven routing** | ADK's built-in sub-agent transfer via `description` fields — no manual routing code |
| **Vertex AI backend** | `GOOGLE_GENAI_USE_VERTEXAI=true` — enterprise-grade inference on Cloud Run |
