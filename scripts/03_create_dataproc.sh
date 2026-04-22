#!/usr/bin/env bash
# Create an ephemeral Dataproc cluster sized for this project.
# Auto-deletes after 1 hr of idle time to control cost.

set -euo pipefail

: "${PROJECT_ID:?PROJECT_ID env var is required}"
REGION="${REGION:-us-central1}"
CLUSTER_NAME="${CLUSTER_NAME:-flight-delay-cluster}"
STAGING_BUCKET="${PROJECT_ID}-dataproc-staging"

gcloud dataproc clusters create "${CLUSTER_NAME}" \
  --region="${REGION}" \
  --zone="" \
  --master-machine-type=e2-standard-2 \
  --master-boot-disk-size=100 \
  --num-workers=2 \
  --worker-machine-type=e2-standard-4 \
  --worker-boot-disk-size=100 \
  --image-version=2.2-debian12 \
  --bucket="${STAGING_BUCKET}" \
  --max-idle=1h \
  --properties="spark:spark.jars.packages=com.google.cloud.spark:spark-bigquery-with-dependencies_2.12:0.41.0"

echo "==> Cluster ${CLUSTER_NAME} ready in ${REGION}."
