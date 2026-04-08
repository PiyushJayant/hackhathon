#!/bin/bash

set -euo pipefail

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  Unified Deployment Script                                                 ║
# ║  Deploys productivity assistant and/or MCP toolbox to Cloud Run            ║
# ║  Usage:                                                                    ║
# ║    ./setup/deploy.sh --mode full       (toolbox + assistant)               ║
# ║    ./setup/deploy.sh --mode toolbox    (toolbox only)                      ║
# ║    ./setup/deploy.sh --mode assistant  (assistant only)                    ║
# ║    ./setup/deploy.sh --mode prototype  (assistant only, no toolbox)        ║
# ╚════════════════════════════════════════════════════════════════════════════╝

MODE="full"
while [ $# -gt 0 ]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}"
REGION="${REGION:-us-central1}"
ASSISTANT_SERVICE_NAME="${ASSISTANT_SERVICE_NAME:-productivity-assistant}"
TOOLBOX_SERVICE_NAME="${TOOLBOX_SERVICE_NAME:-mcp-toolbox}"
AR_REPO="${AR_REPO:-productivity-services}"
GOOGLE_CLOUD_LOCATION="${GOOGLE_CLOUD_LOCATION:-us-central1}"
MODEL="${MODEL:-gemini-2.5-flash}"

ALLOYDB_IP_TYPE="${ALLOYDB_IP_TYPE:-private}"
VPC_CONNECTOR="${VPC_CONNECTOR:-toolbox-vpc-connector}"
VPC_EGRESS="${VPC_EGRESS:-private-ranges-only}"
VPC_NETWORK="${VPC_NETWORK:-easy-alloydb-vpc}"
VPC_CONNECTOR_RANGE="${VPC_CONNECTOR_RANGE:-10.8.0.0/28}"
VPC_CONNECTOR_RANGE_FALLBACK="${VPC_CONNECTOR_RANGE_FALLBACK:-10.9.0.0/28}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_CONFIG="${REPO_ROOT}/cloudbuild.toolbox.yaml"
IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/${AR_REPO}/${TOOLBOX_SERVICE_NAME}:latest"

if [ -z "${PROJECT_ID}" ] || [ "${PROJECT_ID}" = "(unset)" ]; then
  echo "Error: GOOGLE_CLOUD_PROJECT is not set and no active gcloud project was found."
  exit 1
fi

# Load .env if present (required for deployment)
if [ -f "${REPO_ROOT}/.env" ]; then
  set -a
  source "${REPO_ROOT}/.env"
  set +a
  echo "✓ Loaded .env"
else
  echo "Warning: .env not found. Run ./setup/setup.sh all first"
fi

# SERVICE_ACCOUNT is optional — Cloud Run uses the default compute SA if not set
if [ -n "${SERVICE_ACCOUNT:-}" ]; then
  echo "Service Account: ${SERVICE_ACCOUNT}"
fi

echo "=========================================="
echo "Deployment Script"
echo "=========================================="
echo "Project:   ${PROJECT_ID}"
echo "Region:    ${REGION}"
echo "Mode:      ${MODE}"
echo ""


enable_apis() {
  echo "Enabling required APIs..."
  gcloud services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com aiplatform.googleapis.com vpcaccess.googleapis.com --project="${PROJECT_ID}"
}

ensure_repo() {
  if ! gcloud artifacts repositories describe "${AR_REPO}" --location="${REGION}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    echo "Creating Artifact Registry repository..."
    gcloud artifacts repositories create "${AR_REPO}" \
      --repository-format=docker \
      --location="${REGION}" \
      --description="Images for productivity assistant services" \
      --project="${PROJECT_ID}"
  fi
}

connector_state() {
  gcloud compute networks vpc-access connectors describe "${VPC_CONNECTOR}" \
    --region "${REGION}" \
    --project "${PROJECT_ID}" \
    --format='value(state)' 2>/dev/null || true
}

wait_for_connector_ready() {
  local tries=0
  local state=""
  echo "Waiting for VPC connector to be ready..."
  while [ $tries -lt 40 ]; do
    state="$(connector_state)"
    if [ "${state}" = "READY" ]; then
      echo "✓ VPC connector is READY"
      return 0
    fi
    if [ "${state}" = "ERROR" ]; then
      echo "✗ VPC connector state is ERROR"
      return 1
    fi
    tries=$((tries + 1))
    sleep 10
  done
  echo "✗ VPC connector did not reach READY state within timeout"
  return 1
}

create_connector() {
  local cidr="$1"
  echo "Creating VPC connector with CIDR ${cidr}..."
  gcloud compute networks vpc-access connectors create "${VPC_CONNECTOR}" \
    --network "${VPC_NETWORK}" \
    --region "${REGION}" \
    --range "${cidr}" \
    --project "${PROJECT_ID}"
}

ensure_connector() {
  if [ "${ALLOYDB_IP_TYPE}" != "private" ]; then
    return 0
  fi

  if [ -z "${VPC_CONNECTOR}" ]; then
    echo "Error: VPC_CONNECTOR is required when ALLOYDB_IP_TYPE=private"
    exit 1
  fi

  local state
  state="$(connector_state)"
  if [ "${state}" = "ERROR" ]; then
    echo "Removing broken VPC connector..."
    gcloud compute networks vpc-access connectors delete "${VPC_CONNECTOR}" --region "${REGION}" --project "${PROJECT_ID}" --quiet
  fi

  if ! gcloud compute networks vpc-access connectors describe "${VPC_CONNECTOR}" --region "${REGION}" --project "${PROJECT_ID}" >/dev/null 2>&1; then
    create_connector "${VPC_CONNECTOR_RANGE}"
  fi

  if ! wait_for_connector_ready; then
    echo "Trying with fallback CIDR range..."
    gcloud compute networks vpc-access connectors delete "${VPC_CONNECTOR}" --region "${REGION}" --project "${PROJECT_ID}" --quiet
    create_connector "${VPC_CONNECTOR_RANGE_FALLBACK}"
    if ! wait_for_connector_ready; then
      echo "Error: VPC connector ${VPC_CONNECTOR} is not READY"
      exit 1
    fi
  fi
}

prepare_assistant_source() {
  local source_dir
  source_dir="$(mktemp -d)"

  cp "${REPO_ROOT}/requirements.txt" "${source_dir}/requirements.txt"
  cp -R "${REPO_ROOT}/productivity_assistant" "${source_dir}/productivity_assistant"

  cat > "${source_dir}/main.py" <<'EOF'
import logging
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

logger.info("Starting productivity assistant...")

try:
    from google.adk.cli.fast_api import get_fast_api_app

    app = get_fast_api_app(
        agents_dir=os.path.dirname(os.path.abspath(__file__)),
        web=True,
    )
    logger.info("ADK FastAPI app created successfully")
except Exception as e:
    logger.error("Failed to create ADK app: %s", e, exc_info=True)
    from fastapi import FastAPI
    app = FastAPI(title="Productivity Assistant (fallback)")

    @app.get("/")
    def health():
        return {"status": "error", "detail": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
EOF

  cat > "${source_dir}/Procfile" <<'EOF'
web: uvicorn main:app --host 0.0.0.0 --port $PORT
EOF

  echo "${source_dir}"
}

deploy_toolbox() {
  echo ""
  echo "Deploying MCP Toolbox..."
  
  required=(ALLOYDB_REGION ALLOYDB_CLUSTER ALLOYDB_INSTANCE ALLOYDB_DATABASE ALLOYDB_USER ALLOYDB_PASSWORD)
  for v in "${required[@]}"; do
    if [ -z "${!v:-}" ]; then
      echo "Error: missing required environment variable: ${v}"
      exit 1
    fi
  done

  ensure_repo
  ensure_connector

  echo "Building and pushing toolbox image..."
  gcloud builds submit --config "${BUILD_CONFIG}" --substitutions "_IMAGE_URI=${IMAGE_URI}" --project="${PROJECT_ID}" "${REPO_ROOT}"

  echo "Deploying toolbox to Cloud Run..."
  deploy_args=(
    --image "${IMAGE_URI}"
    --region "${REGION}"
    --platform managed
    --allow-unauthenticated
    --port 5000
    --set-env-vars "GOOGLE_CLOUD_PROJECT=${PROJECT_ID},ALLOYDB_REGION=${ALLOYDB_REGION},ALLOYDB_CLUSTER=${ALLOYDB_CLUSTER},ALLOYDB_INSTANCE=${ALLOYDB_INSTANCE},ALLOYDB_IP_TYPE=${ALLOYDB_IP_TYPE},ALLOYDB_DATABASE=${ALLOYDB_DATABASE},ALLOYDB_USER=${ALLOYDB_USER},ALLOYDB_PASSWORD=${ALLOYDB_PASSWORD}"
  )

  if [ -n "${VPC_CONNECTOR}" ] && [ "${ALLOYDB_IP_TYPE}" = "private" ]; then
    deploy_args+=(--vpc-connector "${VPC_CONNECTOR}" --vpc-egress "${VPC_EGRESS}")
  fi

  gcloud run deploy "${TOOLBOX_SERVICE_NAME}" "${deploy_args[@]}"
  
  echo "✓ Toolbox deployed"
}

deploy_assistant() {
  local toolbox_url="${TOOLBOX_URL:-}"
  local prototype="${1:-false}"

  if [ -z "${toolbox_url}" ] && [ "${prototype}" = "false" ]; then
    toolbox_url="$(gcloud run services describe "${TOOLBOX_SERVICE_NAME}" --region "${REGION}" --format='value(status.url)' 2>/dev/null || true)"
  fi

  if [ -z "${toolbox_url}" ] && [ "${prototype}" = "false" ]; then
    echo "Error: TOOLBOX_URL is empty. Deploy toolbox first or use --mode prototype"
    exit 1
  fi

  echo ""
  echo "Deploying Assistant to Cloud Run using Dockerfile..."

  local env_vars="GOOGLE_CLOUD_PROJECT=${PROJECT_ID},GOOGLE_CLOUD_LOCATION=${GOOGLE_CLOUD_LOCATION},GOOGLE_GENAI_USE_VERTEXAI=true,MODEL=${MODEL}"

  if [ "${prototype}" = "true" ]; then
    env_vars="${env_vars},PROTOTYPE_MODE=true"
  else
    env_vars="${env_vars},TOOLBOX_URL=${toolbox_url}"
  fi

  gcloud run deploy "${ASSISTANT_SERVICE_NAME}" \
    --source "${REPO_ROOT}" \
    --region "${REGION}" \
    --platform managed \
    --allow-unauthenticated \
    --memory 1Gi \
    --timeout 300 \
    --clear-base-image \
    --set-env-vars "${env_vars}"

  echo "✓ Assistant deployed"
  echo ""
  echo "Assistant URL:"
  gcloud run services describe "${ASSISTANT_SERVICE_NAME}" --region "${REGION}" --format='value(status.url)'
}

enable_apis

case "${MODE}" in
  toolbox)
    deploy_toolbox
    ;;
  assistant)
    deploy_assistant false
    ;;
  prototype)
    deploy_assistant true
    ;;
  full)
    deploy_toolbox
    TOOLBOX_URL="$(gcloud run services describe "${TOOLBOX_SERVICE_NAME}" --region "${REGION}" --format='value(status.url)' 2>/dev/null || true)"
    if [ -z "${TOOLBOX_URL}" ]; then
      echo "Error: could not resolve TOOLBOX_URL after toolbox deployment"
      exit 1
    fi
    if ! curl -fsS "${TOOLBOX_URL}" >/dev/null 2>&1; then
      echo "Error: toolbox URL is not reachable at ${TOOLBOX_URL}"
      exit 1
    fi
    export TOOLBOX_URL
    deploy_assistant false
    ;;
  *)
    echo "Usage: ./setup/deploy.sh --mode [full|toolbox|assistant|prototype]"
    exit 1
    ;;
esac

echo ""
echo "✓ Deployment complete!"
