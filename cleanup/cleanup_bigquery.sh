#!/bin/bash

set -euo pipefail

PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}"
DATASET_ID="productivity_analytics"

if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "(unset)" ]; then
    echo "Error: Could not determine Google Cloud Project ID."
    echo "Set GOOGLE_CLOUD_PROJECT or run: gcloud config set project <PROJECT_ID>"
    exit 1
fi

echo "----------------------------------------------------------------"
echo "BigQuery cleanup targets"
echo "Project: $PROJECT_ID"
echo "Dataset: $DATASET_ID"
echo "----------------------------------------------------------------"
read -p "Delete the BigQuery dataset and all of its tables? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 1
fi

if bq show "$PROJECT_ID:$DATASET_ID" >/dev/null 2>&1; then
    bq rm -r -f --dataset "$PROJECT_ID:$DATASET_ID"
    echo "Deleted dataset $PROJECT_ID:$DATASET_ID"
else
    echo "Dataset not found. Nothing to delete."
fi

echo "BigQuery cleanup complete."