# Project Check-in Report

**Name:** Fabricio Pons Samano
**Course:** Data Intensive Systems — Final Project
**Date:** 2026-04-22 *(draft; submit by Apr 24)*
**Project:** U.S. Airline Flight Delay Analysis Pipeline on GCP

---

## 1. What I have completed so far

### Infrastructure
- **GCP project** `flight-delay-pipeline-494116` created, billing linked, CLI authenticated.
- **APIs enabled:** Cloud Storage, Dataproc, BigQuery, BigQuery Connection, Vertex AI, Compute.
- **Buckets provisioned** in `us-central1`:
  - `gs://flight-delay-pipeline-494116-raw` (BTS raw zips)
  - `gs://flight-delay-pipeline-494116-processed` (cleaned Parquet + lookups)
  - `gs://flight-delay-pipeline-494116-dataproc-staging`
- **BigQuery dataset** `flight_delay_analytics` created in `US` multi-region (required to cross-join `bigquery-public-data.noaa_gsod`).

### Data ingestion
- BTS On-Time Performance monthly zip files **2019-01 through 2025-12 (84 files, ~2.4 GB)** streamed directly from `transtats.bts.gov/PREZIP/...` into GCS, partitioned by `year=YYYY/month=M`.
- NOAA GSOD stays in place in the BigQuery public dataset — no ingestion needed.

### Pipeline code (all committed to the repo)
- `scripts/01_gcp_bootstrap.sh` — reproducible GCP setup.
- `scripts/02_download_bts.sh` — idempotent BTS ingestion (skips objects already in GCS).
- `scripts/03_create_dataproc.sh` — Dataproc cluster template (3 worker `n2-standard-4`, 1-hour auto-idle).
- `scripts/04_submit_jobs.sh` — job orchestration.
- `pyspark/clean_flights.py` — zip parsing, column projection, type coercion, snake_case rename, partitioned Parquet.
- `pyspark/airport_station_map.py` — haversine nearest-station match, IATA → NOAA station (≤50 km).
- `pyspark/join_flights_weather.py` — joins cleaned flights with NOAA GSOD for both origin and destination, writes to BigQuery.
- `sql/create_tables.sql` — five dashboard-backing views.
- `sql/analytics_queries.sql` — report-driving queries.
- `sql/bqml_delay_model.sql` — logistic regression training + `ML.EVALUATE` + confusion matrix + `ML.GLOBAL_EXPLAIN`.
- `dashboard/looker_studio.md` — panel-by-panel build spec.

### Progress vs. plan
Roughly **60–65% complete**: ingestion + all code artifacts are done; what remains is cluster execution, BigQuery ML evaluation, and Looker Studio build.

---

## 2. Challenges encountered

1. **BTS data access.** There is no public API; the TranStats "download selected columns" form is interactive. I reverse-engineered the PREZIP endpoint (`https://transtats.bts.gov/PREZIP/On_Time_Reporting_Carrier_On_Time_Performance_1987_present_YYYY_M.zip`), which exposes monthly pre-zipped files for direct `curl`. This removed the need for a browser-driven scraper.
2. **Zip files inside GCS.** Spark's CSV reader handles `.gz` but not `.zip`. I parse zips inside `sc.binaryFiles` using Python's `zipfile` module, which keeps everything distributed without an intermediate unzip step.
3. **Airport → weather station matching.** BTS uses IATA codes; NOAA uses USAF-WBAN station ids. I built a haversine nearest-neighbor join (≤50 km) against `bigquery-public-data.faa.us_airports` and `bigquery-public-data.noaa_gsod.stations` to produce a one-time lookup table.
4. **Region pinning.** BigQuery datasets that read `bigquery-public-data.noaa_gsod` must live in `US` multi-region. This also constrains Dataproc cluster placement for the BQ connector to behave efficiently.

---

## 3. Planned next steps (before May 6 presentation)

- **Apr 22–24:** Spin up Dataproc cluster, run all three PySpark jobs end-to-end. Verify `flights_weather_enriched` row count (~40 M) and sanity-check the join.
- **Apr 25–27:** Materialize the five BigQuery views, train the BQML logistic-regression model, capture ROC-AUC + confusion matrix for the report.
- **Apr 28 – May 1:** Build the Looker Studio dashboard following `dashboard/looker_studio.md`; tune panel layouts and colors.
- **May 2–5:** Draft the final report, presentation slides, and polish a 5-minute demo.
- **May 6 or 7:** Present.
- **May 8–10:** Push everything to GitHub, add instructor as collaborator, submit repo link on Canvas.

---

## 4. Repo link

GitHub repo will be created and shared by May 10 (final submission). Work currently on local git branch `main`; all commits are reproducible and every shell/PySpark script is parameterized on `PROJECT_ID`.
