#!/bin/bash

set -euo pipefail

# ╔════════════════════════════════════════════════════════════════════════════╗
# ║  Local Toolbox Startup (Binary)                                            ║
# ║  Downloads and starts MCP Toolbox v0.23.0 for local development            ║
# ║  Usage: Terminal 1 of 2 for local dev (Terminal 2: adk web)                ║
# ║  Note: Cannot connect to private AlloyDB from Cloud Shell                   ║
# ╚════════════════════════════════════════════════════════════════════════════╝

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

# Check if virtual environment is activated
if [ -z "${VIRTUAL_ENV:-}" ]; then
  echo "⚠️  Warning: Python virtual environment is not activated"
  echo "Please run: source ${REPO_ROOT}/.venv/bin/activate"
fi

# Configuration
VERSION="${TOOLBOX_VERSION:-0.23.0}"
TOOLBOX_BINARY="./toolbox-${VERSION}"
TOOLBOX_URL="https://storage.googleapis.com/genai-toolbox/v${VERSION}/linux/amd64/toolbox"
TOOLS_CONFIG="${REPO_ROOT}/mcp_toolbox/tools.yaml"

echo "=========================================="
echo "MCP Toolbox Startup (Binary)"
echo "=========================================="
echo "Version:      ${VERSION}"
echo "Tools config: ${TOOLS_CONFIG}"

# Download toolbox binary if not present
if [ ! -f "${TOOLBOX_BINARY}" ]; then
  echo ""
  echo "Downloading toolbox binary v${VERSION}..."
  curl -L -o "${TOOLBOX_BINARY}" "${TOOLBOX_URL}"
  chmod +x "${TOOLBOX_BINARY}"
  echo "Downloaded and made executable: ${TOOLBOX_BINARY}"
else
  echo "Binary already present: ${TOOLBOX_BINARY}"
fi

# Verify tools.yaml exists
if [ ! -f "${TOOLS_CONFIG}" ]; then
  echo "Error: tools.yaml not found at ${TOOLS_CONFIG}"
  exit 1
fi

# Source .env if present for logging
if [ -f "${REPO_ROOT}/.env" ]; then
  set -a
  source "${REPO_ROOT}/.env"
  set +a
  echo ""
  echo "Loaded environment from .env"
fi

# Check for private AlloyDB in Cloud Shell (known incompatibility)
if [ -n "${DEVSHELL_PROJECT_ID:-}" ] && [ "${ALLOYDB_IP_TYPE:-}" = "private" ]; then
  echo ""
  echo "⚠️  WARNING: Private AlloyDB cannot be accessed from Cloud Shell"
  echo ""
  echo "Cloud Shell does not have routing to private VPC ranges (e.g., 10.19.0.0/16)."
  echo "To deploy productivity assistant with private AlloyDB:"
  echo ""
  echo "  1. Setup: ./setup/setup.sh all"
  echo "  2. Deploy: ./setup/deploy.sh --mode full      (full stack with toolbox)"
  echo "     OR:     ./setup/deploy.sh --mode prototype (assistant only)"
  echo ""
  exit 1
fi

echo ""
echo "Starting MCP Toolbox binary..."
echo ""

exec "${TOOLBOX_BINARY}" "${TOOLS_CONFIG}"
