#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

PROJECT_ID=""
if [ -f "$ENV_FILE" ]; then
    PROJECT_ID=$(grep -E '^GOOGLE_CLOUD_PROJECT=' "$ENV_FILE" | head -n1 | cut -d'=' -f2- || true)
fi

if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "(unset)" ]; then
    PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}"
fi

if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "(unset)" ]; then
    echo "Error: Could not determine Google Cloud Project ID."
    exit 1
fi

echo "----------------------------------------------------------------"
echo "Cleanup targets"
echo "Project:   $PROJECT_ID"
echo "Local env: $ENV_FILE"
echo "APIs:      run, artifactregistry, cloudbuild, aiplatform, bigquery, alloydb"
echo "----------------------------------------------------------------"
read -p "Remove local .env and optionally disable enabled APIs? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 1
fi

if [ -f "$ENV_FILE" ]; then
    rm "$ENV_FILE"
    echo "Deleted $ENV_FILE"
else
    echo "No local .env file found."
fi

read -p "Disable the APIs enabled by setup_env.sh? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    gcloud services disable run.googleapis.com --project="$PROJECT_ID" --force
    gcloud services disable artifactregistry.googleapis.com --project="$PROJECT_ID" --force
    gcloud services disable cloudbuild.googleapis.com --project="$PROJECT_ID" --force
    gcloud services disable aiplatform.googleapis.com --project="$PROJECT_ID" --force
    gcloud services disable bigquery.googleapis.com --project="$PROJECT_ID" --force
    gcloud services disable alloydb.googleapis.com --project="$PROJECT_ID" --force
    echo "APIs disabled."
else
    echo "Skipping API disablement."
fi

echo "Cleanup complete."