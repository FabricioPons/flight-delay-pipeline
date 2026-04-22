#!/usr/bin/env bash
# Submit the three PySpark jobs to the Dataproc cluster in sequence.

set -euo pipefail

: "${PROJECT_ID:?PROJECT_ID env var is required}"
REGION="${REGION:-us-central1}"
CLUSTER_NAME="${CLUSTER_NAME:-flight-delay-cluster}"

RAW_BUCKET="${PROJECT_ID}-raw"
PROCESSED_BUCKET="${PROJECT_ID}-processed"
STAGING_BUCKET="${PROJECT_ID}-dataproc-staging"

submit() {
  local script="$1"; shift
  local name
  name="$(basename "${script}" .py)"
  echo "==> Submitting ${name}"
  gcloud dataproc jobs submit pyspark "${script}" \
    --cluster="${CLUSTER_NAME}" \
    --region="${REGION}" \
    --properties="spark.jars.packages=com.google.cloud.spark:spark-bigquery-with-dependencies_2.12:0.41.0" \
    -- \
    --project="${PROJECT_ID}" \
    --raw-bucket="${RAW_BUCKET}" \
    --processed-bucket="${PROCESSED_BUCKET}" \
    --staging-bucket="${STAGING_BUCKET}" \
    "$@"
}

submit pyspark/clean_flights.py
submit pyspark/airport_station_map.py
submit pyspark/join_flights_weather.py --dataset=flight_delay_analytics

echo "==> All jobs submitted."
