#!/usr/bin/env bash
# Submit the three PySpark jobs to the Dataproc cluster in sequence.

set -euo pipefail

: "${PROJECT_ID:?PROJECT_ID env var is required}"
REGION="${REGION:-us-central1}"
CLUSTER_NAME="${CLUSTER_NAME:-flight-delay-cluster}"

RAW_BUCKET="${PROJECT_ID}-raw"
PROCESSED_BUCKET="${PROJECT_ID}-processed"
STAGING_BUCKET="${PROJECT_ID}-dataproc-staging"

# Google-hosted BQ connector JAR (no external egress required).
BQ_CONNECTOR_JAR="gs://spark-lib/bigquery/spark-bigquery-with-dependencies_2.12-0.44.1.jar"

submit() {
  local script="$1"
  local with_bq="${2:-no}"
  local name
  name="$(basename "${script}" .py)"

  echo "==> Submitting ${name}"

  local jars_arg=""
  if [[ "${with_bq}" == "bq" ]]; then
    jars_arg="--jars=${BQ_CONNECTOR_JAR}"
  fi

  gcloud dataproc jobs submit pyspark "${script}" \
    --cluster="${CLUSTER_NAME}" \
    --region="${REGION}" \
    ${jars_arg} \
    -- \
    --project="${PROJECT_ID}" \
    --raw-bucket="${RAW_BUCKET}" \
    --processed-bucket="${PROCESSED_BUCKET}" \
    --staging-bucket="${STAGING_BUCKET}"
}

# clean_flights reads/writes GCS only — no BQ connector needed.
submit pyspark/clean_flights.py no

# airport_station_map + join_flights_weather read from the BigQuery public
# dataset; supply the connector JAR from gs://spark-lib.
submit pyspark/airport_station_map.py bq
submit pyspark/join_flights_weather.py bq

echo "==> All jobs submitted."
