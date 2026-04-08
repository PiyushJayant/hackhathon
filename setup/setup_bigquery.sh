#!/bin/bash

set -euo pipefail

PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}"

if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "(unset)" ]; then
    echo "Error: Could not determine Google Cloud Project ID."
    echo "Set GOOGLE_CLOUD_PROJECT or run: gcloud config set project <PROJECT_ID>"
    exit 1
fi

echo "Setting up BigQuery analytics in project: $PROJECT_ID"
export GOOGLE_CLOUD_PROJECT="$PROJECT_ID"

python "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bigquery_setup.py"

echo "BigQuery setup complete."