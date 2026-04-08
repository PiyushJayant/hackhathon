#!/bin/bash

set -euo pipefail
# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  Create AlloyDB Cluster + Instance                                         ║
# ║  Uses the easy-alloydb-vpc network (from AlloyDB Quick Setup codelab).     ║
# ║  If your cluster already exists (from the codelab), skip this script       ║
# ║  and go straight to apply_schema.sh.                                       ║
# ╚════════════════════════════════════════════════════════════════════════════╝

PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}"
REGION="${ALLOYDB_REGION:-us-central1}"
CLUSTER="${ALLOYDB_CLUSTER:-productivity-cluster}"
INSTANCE="${ALLOYDB_INSTANCE:-productivity-instance}"
DB_PASS="${ALLOYDB_PASSWORD:-postgres}"
VPC_NETWORK="${VPC_NETWORK:-easy-alloydb-vpc}"

if [ -z "${PROJECT_ID}" ] || [ "${PROJECT_ID}" = "(unset)" ]; then
  echo "Error: GOOGLE_CLOUD_PROJECT is not set."
  exit 1
fi

echo "=========================================="
echo "AlloyDB Setup"
echo "=========================================="
echo "Project:  ${PROJECT_ID}"
echo "Region:   ${REGION}"
echo "Cluster:  ${CLUSTER}"
echo "Instance: ${INSTANCE}"
echo "Network:  ${VPC_NETWORK}"
echo "=========================================="

# Enable APIs
echo ""
echo "Enabling AlloyDB and Compute Engine APIs..."
gcloud services enable alloydb.googleapis.com compute.googleapis.com servicenetworking.googleapis.com \
  --project="${PROJECT_ID}"

# ── Check if cluster exists ──────────────────────────────────────────────────
if gcloud alloydb clusters describe "${CLUSTER}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo ""
  echo "Cluster '${CLUSTER}' already exists. Skipping creation."
else
  echo ""
  echo "Creating AlloyDB cluster '${CLUSTER}' (this takes ~5 minutes)..."
  gcloud alloydb clusters create "${CLUSTER}" \
    --region="${REGION}" \
    --password="${DB_PASS}" \
    --network="projects/${PROJECT_ID}/global/networks/${VPC_NETWORK}" \
    --project="${PROJECT_ID}"
  echo "Cluster created."
fi

# ── Check if instance exists ─────────────────────────────────────────────────
if gcloud alloydb instances describe "${INSTANCE}" \
  --cluster="${CLUSTER}" \
  --region="${REGION}" \
  --project="${PROJECT_ID}" >/dev/null 2>&1; then
  echo ""
  echo "Instance '${INSTANCE}' already exists. Skipping creation."
else
  echo ""
  echo "Creating AlloyDB primary instance '${INSTANCE}' (this takes ~10 minutes)..."
  gcloud alloydb instances create "${INSTANCE}" \
    --cluster="${CLUSTER}" \
    --region="${REGION}" \
    --instance-type=PRIMARY \
    --cpu-count=2 \
    --project="${PROJECT_ID}"
  echo "Instance created."
fi

echo ""
echo "=========================================="
echo "AlloyDB cluster and instance are ready."
echo ""
echo "Next step: apply the schema"
echo "  ./setup/apply_schema.sh"
echo "=========================================="
