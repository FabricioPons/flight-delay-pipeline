#!/usr/bin/env bash
# Bootstrap GCP resources: APIs, GCS buckets, BigQuery dataset.
# Requires: gcloud CLI authenticated, PROJECT_ID env var set.

set -euo pipefail

: "${PROJECT_ID:?PROJECT_ID env var is required}"
REGION="${REGION:-us-central1}"
BQ_LOCATION="${BQ_LOCATION:-US}"  # must be US to query bigquery-public-data.noaa_gsod

RAW_BUCKET="${PROJECT_ID}-raw"
PROCESSED_BUCKET="${PROJECT_ID}-processed"
STAGING_BUCKET="${PROJECT_ID}-dataproc-staging"
BQ_DATASET="flight_delay_analytics"

echo "==> Setting active project: ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}"

echo "==> Enabling required APIs"
gcloud services enable \
  storage.googleapis.com \
  dataproc.googleapis.com \
  bigquery.googleapis.com \
  bigqueryconnection.googleapis.com \
  aiplatform.googleapis.com \
  compute.googleapis.com

echo "==> Creating GCS buckets (region: ${REGION})"
for bucket in "${RAW_BUCKET}" "${PROCESSED_BUCKET}" "${STAGING_BUCKET}"; do
  if gcloud storage buckets describe "gs://${bucket}" >/dev/null 2>&1; then
    echo "    gs://${bucket} already exists, skipping"
  else
    gcloud storage buckets create "gs://${bucket}" \
      --location="${REGION}" \
      --uniform-bucket-level-access
  fi
done

echo "==> Creating BigQuery dataset ${BQ_DATASET} (location: ${BQ_LOCATION})"
if bq --location="${BQ_LOCATION}" ls -d "${PROJECT_ID}:${BQ_DATASET}" >/dev/null 2>&1; then
  echo "    dataset exists, skipping"
else
  bq --location="${BQ_LOCATION}" mk \
    --dataset \
    --description="Flight delay analytics (BTS + NOAA)" \
    "${PROJECT_ID}:${BQ_DATASET}"
fi

echo ""
echo "==> Bootstrap complete."
echo "    Raw bucket:       gs://${RAW_BUCKET}"
echo "    Processed bucket: gs://${PROCESSED_BUCKET}"
echo "    Staging bucket:   gs://${STAGING_BUCKET}"
echo "    BQ dataset:       ${PROJECT_ID}:${BQ_DATASET}"
