#!/usr/bin/env bash
# Submit the three PySpark jobs to the Dataproc cluster in sequence.

set -euo pipefail

: "${PROJECT_ID:?PROJECT_ID env var is required}"
REGION="${REGION:-us-central1}"
CLUSTER_NAME="${CLUSTER_NAME:-flight-delay-cluster}"

RAW_BUCKET="${PROJECT_ID}-raw"
PROCESSED_BUCKET="${PROJECT_ID}-processed"
STAGING_BUCKET="${PROJECT_ID}-dataproc-staging"

# Dataproc image 2.2 ships the Spark BigQuery connector pre-installed, so no
# --jars / --packages is needed for jobs that read from BigQuery.

submit() {
  local script="$1"
  local name
  name="$(basename "${script}" .py)"

  echo "==> Submitting ${name}"

  gcloud dataproc jobs submit pyspark "${script}" \
    --cluster="${CLUSTER_NAME}" \
    --region="${REGION}" \
    -- \
    --project="${PROJECT_ID}" \
    --raw-bucket="${RAW_BUCKET}" \
    --processed-bucket="${PROCESSED_BUCKET}" \
    --staging-bucket="${STAGING_BUCKET}"
}

submit pyspark/clean_flights.py
submit pyspark/airport_station_map.py
submit pyspark/join_flights_weather.py

echo "==> All jobs submitted."
