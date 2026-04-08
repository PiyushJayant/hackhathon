#!/bin/bash

set -euo pipefail
# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  Apply AlloyDB Schema                                                      ║
# ║  Uses AlloyDB Auth Proxy to tunnel into the private AlloyDB instance       ║
# ║  and apply the schema (tables, extensions, indexes).                       ║
# ║                                                                            ║
# ║  Prerequisites:                                                            ║
# ║    - AlloyDB cluster and instance must already exist                       ║
# ║    - gcloud auth application-default login must be done                    ║
# ║    - .env must be sourced (set -a; source .env; set +a)                    ║
# ╚════════════════════════════════════════════════════════════════════════════╝

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCHEMA_FILE="${REPO_ROOT}/setup/alloydb_schema.sql"

PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}"
REGION="${ALLOYDB_REGION:-us-central1}"
CLUSTER="${ALLOYDB_CLUSTER:-productivity-cluster}"
INSTANCE="${ALLOYDB_INSTANCE:-productivity-instance}"
DB="${ALLOYDB_DATABASE:-postgres}"
DB_USER="${ALLOYDB_USER:-postgres}"
DB_PASS="${ALLOYDB_PASSWORD:-postgres}"

PROXY_PORT=15432
PROXY_PID=""

if [ -z "${PROJECT_ID}" ] || [ "${PROJECT_ID}" = "(unset)" ]; then
  echo "Error: GOOGLE_CLOUD_PROJECT is not set."
  exit 1
fi

if [ ! -f "${SCHEMA_FILE}" ]; then
  echo "Error: schema file not found: ${SCHEMA_FILE}"
  exit 1
fi

echo "=========================================="
echo "Apply AlloyDB Schema"
echo "=========================================="
echo "Project:  ${PROJECT_ID}"
echo "Cluster:  ${CLUSTER}"
echo "Instance: ${INSTANCE}"
echo "Database: ${DB}"
echo "Schema:   ${SCHEMA_FILE}"
echo "=========================================="

# ── Step 1: Ensure AlloyDB Auth Proxy is available ────────────────────────────
PROXY_BIN="${REPO_ROOT}/alloydb-auth-proxy"
PROXY_VERSION="v1.12.2"

if [ ! -f "${PROXY_BIN}" ]; then
  echo ""
  echo "Downloading AlloyDB Auth Proxy ${PROXY_VERSION}..."
  curl -sSL -o "${PROXY_BIN}" \
    "https://storage.googleapis.com/alloydb-auth-proxy/${PROXY_VERSION}/alloydb-auth-proxy.linux.amd64"
  chmod +x "${PROXY_BIN}"
  echo "Downloaded: ${PROXY_BIN}"
fi

# ── Step 2: Start the proxy in the background ────────────────────────────────
INSTANCE_URI="projects/${PROJECT_ID}/locations/${REGION}/clusters/${CLUSTER}/instances/${INSTANCE}"

echo ""
echo "Starting AlloyDB Auth Proxy on localhost:${PROXY_PORT}..."
"${PROXY_BIN}" "${INSTANCE_URI}" --port "${PROXY_PORT}" &
PROXY_PID=$!

cleanup() {
  if [ -n "${PROXY_PID}" ] && kill -0 "${PROXY_PID}" 2>/dev/null; then
    echo ""
    echo "Stopping AlloyDB Auth Proxy (PID ${PROXY_PID})..."
    kill "${PROXY_PID}" 2>/dev/null || true
    wait "${PROXY_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Wait for proxy to be ready
echo "Waiting for proxy to be ready..."
for i in $(seq 1 30); do
  if pg_isready -h 127.0.0.1 -p "${PROXY_PORT}" -U "${DB_USER}" >/dev/null 2>&1; then
    echo "Proxy is ready."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "Error: proxy did not become ready within 30 seconds."
    exit 1
  fi
  sleep 1
done

# ── Step 3: Apply the schema ─────────────────────────────────────────────────
echo ""
echo "Applying schema to database '${DB}'..."
PGPASSWORD="${DB_PASS}" psql \
  -h 127.0.0.1 \
  -p "${PROXY_PORT}" \
  -U "${DB_USER}" \
  -d "${DB}" \
  -f "${SCHEMA_FILE}"

echo ""
echo "=========================================="
echo "Schema applied successfully!"
echo "=========================================="
