#!/usr/bin/env bash
# Download BTS On-Time Performance monthly zips (2019-01 .. 2025-12) and stage in GCS.
# Source: https://transtats.bts.gov/PREZIP/
#
# Strategy: stream each zip via curl directly into gsutil to avoid local disk bloat.
# If a rate limit kicks in, re-run; gsutil cp -n skips objects already present.

set -euo pipefail

: "${PROJECT_ID:?PROJECT_ID env var is required}"
RAW_BUCKET="${PROJECT_ID}-raw"
START_YEAR="${START_YEAR:-2019}"
END_YEAR="${END_YEAR:-2025}"

BASE_URL="https://transtats.bts.gov/PREZIP/On_Time_Reporting_Carrier_On_Time_Performance_1987_present"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

for year in $(seq "${START_YEAR}" "${END_YEAR}"); do
  for month in $(seq 1 12); do
    filename="On_Time_Reporting_Carrier_On_Time_Performance_1987_present_${year}_${month}.zip"
    url="${BASE_URL}_${year}_${month}.zip"
    gcs_path="gs://${RAW_BUCKET}/flights/year=${year}/month=${month}/${filename}"

    if gcloud storage objects describe "${gcs_path}" >/dev/null 2>&1; then
      echo "[skip] ${year}-${month} already in GCS"
      continue
    fi

    echo "[download] ${year}-${month}"
    local_path="${tmpdir}/${filename}"

    # -f: fail on HTTP errors; -L: follow redirects; --retry: resilient
    if ! curl -fL --retry 3 --retry-delay 5 -o "${local_path}" "${url}"; then
      echo "[warn] download failed for ${year}-${month}; skipping"
      continue
    fi

    echo "[upload] ${year}-${month} -> ${gcs_path}"
    gcloud storage cp "${local_path}" "${gcs_path}"
    rm -f "${local_path}"

    # Throttle to be polite.
    sleep 2
  done
done

echo ""
echo "==> All monthly files staged at gs://${RAW_BUCKET}/flights/"
gcloud storage ls "gs://${RAW_BUCKET}/flights/" | head -20
