#!/bin/bash

set -euo pipefail

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  Unified Setup Script                                                      ║
# ║  Environment setup + Google Cloud IAM configuration                        ║
# ║  Usage: ./setup/setup.sh [env|iam|all]                                     ║
# ╚════════════════════════════════════════════════════════════════════════════╝

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ -f "${REPO_ROOT}/.env" ]; then
  set -a
  source "${REPO_ROOT}/.env"
  set +a
fi

# Check if virtual environment is activated
if [ -z "${VIRTUAL_ENV:-}" ]; then
  echo "⚠️  Warning: Python virtual environment is not activated"
  echo "Please run: source ${REPO_ROOT}/.venv/bin/activate"
fi

PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}"
REGION="${REGION:-us-central1}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-productivity-service}"

if [[ "${SERVICE_ACCOUNT}" == *"@"* ]]; then
  SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT}"
  SERVICE_ACCOUNT_NAME="${SERVICE_ACCOUNT%%@*}"
else
  SERVICE_ACCOUNT_NAME="${SERVICE_ACCOUNT}"
  SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
fi

if [ -z "${PROJECT_ID}" ] || [ "${PROJECT_ID}" = "(unset)" ]; then
  echo "Error: GOOGLE_CLOUD_PROJECT is not set and no active gcloud project was found."
  exit 1
fi

echo "=========================================="
echo "Setup Script"
echo "=========================================="
echo "Project ID: ${PROJECT_ID}"
echo "Region:     ${REGION}"
echo ""

setup_env() {
  echo "Setting up environment (.env file)..."
  
  # Get AlloyDB cluster details from gcloud or use defaults
  ALLOYDB_REGION="${ALLOYDB_REGION:-us-central1}"
  ALLOYDB_CLUSTER="${ALLOYDB_CLUSTER:-productivity-cluster}"
  ALLOYDB_INSTANCE="${ALLOYDB_INSTANCE:-productivity-instance}"
  ALLOYDB_DATABASE="${ALLOYDB_DATABASE:-postgres}"
  ALLOYDB_USER="${ALLOYDB_USER:-postgres}"
  ALLOYDB_IP_TYPE="${ALLOYDB_IP_TYPE:-private}"
  
  # Get password from Secret Manager if available
  if gcloud secrets describe alloydb-password --project="${PROJECT_ID}" >/dev/null 2>&1; then
    ALLOYDB_PASSWORD="$(gcloud secrets versions access latest --secret=alloydb-password --project=${PROJECT_ID})"
  else
    ALLOYDB_PASSWORD="${ALLOYDB_PASSWORD:-changeme}"
  fi

  PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)' 2>/dev/null || echo 'UNKNOWN')"

  cat > "${REPO_ROOT}/.env" << EOF
# ── Google Cloud ───────────────────────────────────────────────────────────────
GOOGLE_CLOUD_PROJECT=${PROJECT_ID}
GOOGLE_CLOUD_LOCATION=us-central1
PROJECT_ID=${PROJECT_ID}
PROJECT_NUMBER=${PROJECT_NUMBER}

# Use Vertex AI backend (recommended for Cloud Run; uses ADC automatically)
GOOGLE_GENAI_USE_VERTEXAI=true

# Model
MODEL=gemini-2.5-flash

# ── Service Account ───────────────────────────────────────────────────────────
SA_NAME=${SERVICE_ACCOUNT_NAME}
SERVICE_ACCOUNT=${SERVICE_ACCOUNT_EMAIL}

# ── AlloyDB ────────────────────────────────────────────────────────────────────
ALLOYDB_REGION=${ALLOYDB_REGION}
ALLOYDB_CLUSTER=${ALLOYDB_CLUSTER}
ALLOYDB_INSTANCE=${ALLOYDB_INSTANCE}
ALLOYDB_IP_TYPE=${ALLOYDB_IP_TYPE}
ALLOYDB_DATABASE=${ALLOYDB_DATABASE}
ALLOYDB_USER=${ALLOYDB_USER}
ALLOYDB_PASSWORD=${ALLOYDB_PASSWORD}

# ── MCP Toolbox ────────────────────────────────────────────────────────────────
# Local dev:  http://127.0.0.1:5000
# Cloud Run:  (auto-detected by deploy.sh from mcp-toolbox service URL)
TOOLBOX_URL=http://127.0.0.1:5000

# ── VPC Configuration (for private AlloyDB) ───────────────────────────────────
VPC_CONNECTOR=toolbox-vpc-connector
VPC_EGRESS=private-ranges-only
VPC_NETWORK=easy-alloydb-vpc
VPC_CONNECTOR_RANGE=10.8.0.0/28
VPC_CONNECTOR_RANGE_FALLBACK=10.9.0.0/28

# ── Cloud Run Service Names ───────────────────────────────────────────────────
REGION=${REGION}
ASSISTANT_SERVICE_NAME=productivity-assistant
TOOLBOX_SERVICE_NAME=mcp-toolbox
AR_REPO=productivity-services
EOF

  echo "✓ .env file created at ${REPO_ROOT}/.env"
}

setup_iam() {
  echo "Setting up IAM roles and service account..."

  # Create service account if it doesn't exist
  if ! gcloud iam service-accounts describe "${SERVICE_ACCOUNT_EMAIL}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    echo "Creating service account: ${SERVICE_ACCOUNT_EMAIL}"
    gcloud iam service-accounts create "${SERVICE_ACCOUNT_NAME}" \
      --display-name="Productivity Assistant Service Account" \
      --project="${PROJECT_ID}"
  else
    echo "Service account already exists: ${SERVICE_ACCOUNT_EMAIL}"
  fi

  # Enable required APIs
  echo "Enabling required APIs..."
  gcloud services enable \
    run.googleapis.com \
    artifactregistry.googleapis.com \
    cloudbuild.googleapis.com \
    aiplatform.googleapis.com \
    compute.googleapis.com \
    iam.googleapis.com \
    vpcaccess.googleapis.com \
    bigquery.googleapis.com \
    alloydb.googleapis.com \
    --project="${PROJECT_ID}"

  # Grant IAM roles to service account
  echo "Granting IAM roles to service account..."
  
  ROLES=(
    "roles/aiplatform.user"
    "roles/bigquery.user"
    "roles/alloydb.client"
    "roles/storage.admin"
    "roles/artifactregistry.writer"
    "roles/cloudbuild.builds.editor"
    "roles/logging.logWriter"
  )

  for role in "${ROLES[@]}"; do
    echo "  Granting ${role}..."
    gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
      --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
      --role="${role}" \
      --condition=None \
      --quiet >/dev/null
  done

  echo "✓ IAM setup complete"
}

ACTION="${1:-all}"

case "${ACTION}" in
  env)
    setup_env
    ;;
  iam)
    setup_iam
    ;;
  all)
    setup_env
    setup_iam
    ;;
  *)
    echo "Usage: ./setup/setup.sh [env|iam|all]"
    exit 1
    ;;
esac

echo ""
echo "✓ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Source .env:    set -a; source ${REPO_ROOT}/.env; set +a"
echo "  2. BigQuery:       ./setup/setup_bigquery.sh"
echo "  3. AlloyDB schema: Apply via AlloyDB Studio (or ./setup/apply_schema.sh)"
echo "  4. Deploy:         ./setup/deploy.sh --mode prototype   (analytics only)"
echo "                     ./setup/deploy.sh --mode full        (all agents)"
