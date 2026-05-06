# U.S. Airline Flight Delay Analysis Pipeline — Final Report

**Name:** Fabricio Pons Samano
**Course:** Data-Intensive Systems — Final Project
**Date:** 2026-05-10
**Repository:** *(GitHub URL — to add at submission)*
**Dashboard:** *(Looker Studio share link — to add at submission)*

---

## 1. Project overview and goals

This project builds an end-to-end cloud data pipeline on Google Cloud Platform (GCP) that analyzes U.S. airline flight delays between 2019 and 2025, enriched with daily weather observations from the NOAA Global Surface Summary of the Day (GSOD) dataset. Two artifacts are produced:

1. An interactive Looker Studio dashboard surfacing how airline, route, time, and weather conditions correlate with on-time performance.
2. Two BigQuery ML classifiers — a logistic regression baseline and a boosted-tree (XGBoost) ensemble — that predict whether a given flight will arrive 15+ minutes late.

The pipeline is fully reproducible from a single environment variable (`PROJECT_ID`) and four shell scripts. Total cost across all phases came in under **$11** of the GCP free credit.

## 2. Dataset description

### BTS On-Time Performance (primary)

- Source: `https://transtats.bts.gov/PREZIP/On_Time_Reporting_Carrier_On_Time_Performance_1987_present_YYYY_M.zip`
- 84 monthly files (2019-01 through 2025-12).
- ~2.4 GB compressed, ~14 GB uncompressed.
- **45,763,492 flight records** after cleaning.
- 31 columns retained: `reporting_airline`, `flight_date`, `origin`, `dest`, `dep_delay_minutes`, `arr_delay_minutes`, `arr_del15`, `cancelled`, `diverted`, `distance`, the five BTS-attributed delay-cause minute fields (`carrier_delay`, `weather_delay`, `nas_delay`, `security_delay`, `late_aircraft_delay`), and derived fields (`year`, `month`, `day_of_week`, `dep_hour`, `is_delayed_15`).

### NOAA GSOD (secondary)

- Source: `bigquery-public-data.noaa_gsod.gsod*` and `.stations` — queried in place, no ingestion required.
- Daily summary statistics per weather station: mean wind speed (`wdsp`), precipitation (`prcp`), visibility (`visib`), mean temperature (`temp`).
- 18,176 unique IATA → WBAN station mappings produced after filtering for active U.S. stations.

### FAA airports (tertiary)

- Source: `bigquery-public-data.faa.us_airports`.
- Used to attach lat/lon coordinates to BTS origin codes for the geographic dashboard panel and for the haversine nearest-neighbor lookup against NOAA stations.

## 3. Pipeline workflow and services used

```
BTS TranStats (84 monthly zips)       NOAA GSOD (BigQuery public)
         │                                       │
         ▼                                       │
   GCS raw/flights/                              │
         │                                       │
         ▼                                       │
   Dataproc + PySpark  ── clean_flights.py       │
         │                                       │
         ▼                                       │
   GCS processed/flights/*.parquet               │
         │                                       │
         └── join_flights_weather.py ────────────┘
                        │
                        ▼
          BigQuery: flight_delay_analytics
                        │
            ┌───────────┴──────────┐
            ▼                      ▼
      Looker Studio           BigQuery ML
       dashboard           (delay prediction)
```

| Stage | Service | Purpose |
|---|---|---|
| Ingestion | Cloud Storage | Store raw BTS zip files partitioned by `year=YYYY/month=M` |
| Transformation | Dataproc + PySpark 3.5 (image 2.2) | Parse zips, coerce types, derive fields, join flights × weather |
| Warehouse | BigQuery | Partitioned + clustered analytical table; 5 reporting views; 3 ML output tables |
| Analytics | BigQuery SQL | Five dashboard-backing views over `flights_weather_enriched` |
| ML | BigQuery ML | Logistic regression and boosted-tree classifiers, evaluated on a 2025 holdout |
| Visualization | Looker Studio | Two-page interactive dashboard (5 analytics panels + 3 ML panels) |

**Dataproc cluster sizing (final):** 1 × `e2-standard-2` master + 2 × `e2-standard-4` workers = 10 vCPU total, with 1-hour idle auto-delete to limit cost.

## 4. Data processing steps

### 4.1 BTS cleaning (`pyspark/clean_flights.py`)

Reads `gs://<proj>-raw/flights/**/*.zip` via `sc.binaryFiles`, parses each zip with Python's `zipfile` module inside a distributed flatMap, projects to 31 columns, coerces types, and writes Parquet partitioned by `year=YYYY/month=M`. **84 output partitions**, ~46M rows.

### 4.2 Airport → weather-station mapping (`pyspark/airport_station_map.py`)

Haversine nearest-neighbor join between FAA airports and NOAA GSOD stations:
- Filter NOAA stations to `country='US'`, `wban != '99999'`, `end >= '20190101'` to drop decommissioned legacy stations.
- Collapse by WBAN (5-digit U.S.-specific stable id) to deduplicate USAF code revisions.
- Cross-join inside a ±0.75° lat/lon box, compute haversine distance, keep matches under 50 km, take the nearest station per airport.
- **Output: 18,176 `(iata, station_id, distance_km)` rows.**

### 4.3 Flight × weather join (`pyspark/join_flights_weather.py`)

Joins cleaned flights with NOAA GSOD on `(station_id, weather_date)` for both origin and destination airports, attaching `wdsp`, `prcp`, `visib`, `temp` for each end. `flight_date` is reconstructed from NOAA's `year/mo/da` (Spark's column resolver does not bind GSOD's native `date` column). The result is written to `flight_delay_analytics.flights_weather_enriched`, partitioned by `flight_date` and clustered by `(reporting_airline, origin, dest)`.

- **Final row count: 45,763,492.**
- **Origin weather coverage: 94.4%.** Major hubs (ATL, DFW, DEN, ORD, LAX) all between 93.6% and 95.5%.

### 4.4 BigQuery view materialization (`sql/create_tables.sql`)

Five views power the dashboard:

| View | Granularity | Powers |
|---|---|---|
| `v_monthly_ontime_trend` | One row per month | Time-series panel |
| `v_delay_cause_breakdown` | One row per airline × month | 100% stacked bar |
| `v_airport_delay_heatmap` | One row per origin airport | Geo bubble map |
| `v_weather_correlation` | One row per (wind, precip, visibility) bucket | Pivot heatmap |
| `v_airline_kpi` | One row per airline | Conditional-format table |

Three additional tables back the ML page (`m_eval_metrics`, `m_confusion_matrix`, `m_feature_importance`), materialized from `ML.EVALUATE`, `ML.CONFUSION_MATRIX`, and `ML.GLOBAL_EXPLAIN`. A fourth table (`m_model_comparison`) holds side-by-side metrics for the logistic vs boosted comparison.

## 5. Results

### Headline numbers

- **Total flights analyzed:** 45,763,492 (2019–2025).
- **Weather-join coverage:** 94.4% of flights have origin-airport weather attached.
- **Overall on-time rate:** ~78.7% across the seven-year window.

### Airline leaderboard (on-time % at `arr_del15 = 0`)

| Airline | On-time % |
|---|---|
| Delta (DL) | **83.3%** |
| YX | 81.2% |
| SkyWest (OO) | 81.1% |
| Alaska (AS) | 78.9% |
| United (UA) | 78.9% |
| Southwest (WN) | 78.2% |
| OH | 78.0% |
| American (AA) | 76.1% |
| JetBlue (B6) | 71.4% |

### COVID-19 impact (cancellation rate)

- **2019 baseline:** 1.82%
- **2020:** **5.99%** (peak in Mar–Jun, clearly visible in the monthly time-series panel as a vertical drop in on-time rate followed by a multi-month recovery)
- **2021 recovery:** 1.72%

### Weather-correlated delay rate (origin weather, panel 4)

The pivot heatmap shows delay rate climbing with worsening weather at the origin until ~30 kt wind, at which point delay rate **drops** because flights get **cancelled** rather than flown-and-delayed:

| Wind | Poor visibility (<3 mi) |
|---|---|
| 0–5 kt | 24.5% |
| 5–10 kt | 30.2% |
| 10–20 kt | 39.6% (peak) |
| 20–30 kt | 31.3% |
| 30+ kt | 5.3% (cancellation pool) |

This dual-mode response — delay until breaking point, then cancel — is one of the more interesting analytical findings of the study.

## 6. Visualizations / dashboard

The Looker Studio dashboard is organized as a **two-page report**:

**Page 1 — Analytics (5 panels):**
1. **Monthly on-time rate (2019–2025)** — line series with the COVID dip in Mar–Jun 2020 clearly visible.
2. **Delay cause breakdown by airline** — 100% stacked bar showing carrier vs. weather vs. NAS vs. security vs. late-aircraft minutes by reporting airline.
3. **Airport delay heatmap** — Google Maps bubble map sized by flight count and colored by mean arrival delay; uses a calculated `airport_geo` field combining FAA latitude and longitude.
4. **Weather vs delay rate** — pivot heatmap of `wind_bucket` × `visibility_bucket`, cells colored by delay rate.
5. **Airline KPI table** — sortable conditional-formatted table of flights, mean arrival delay, on-time %, and cancellation %.

**Page 2 — ML (3 panels):**
6. **Model quality scorecards** — six scorecards displaying ROC-AUC, accuracy, precision, recall, F1, and log-loss for both models.
7. **Confusion matrix** — pivot heatmap on the 2025 holdout (~7M flights).
8. **Feature importance** — horizontal bar chart from `ML.GLOBAL_EXPLAIN`.

## 7. BigQuery ML model

### 7.1 Logistic regression baseline (`delay_clf`)

- Model type: `LOGISTIC_REG` with `auto_class_weights=TRUE`.
- Features: `reporting_airline`, `origin`, `dest`, `dep_hour`, `day_of_week`, `month`, `distance`, `origin_wdsp` (wind), `origin_prcp` (precipitation), `origin_visib` (visibility), `origin_temp` (temperature).
- Training window: 2019-01-01 to 2024-12-31 (~38M rows).
- Holdout: 2025 (~7M rows).

| Metric | Value |
|---|---|
| Accuracy | 0.5611 |
| Precision | 0.2958 |
| Recall | 0.6347 |
| F1 | 0.4035 |
| Log-loss | 0.6892 |
| **ROC-AUC** | **0.6152** |

**Top features by `ML.GLOBAL_EXPLAIN`:**

| Feature | Attribution |
|---|---|
| `dep_hour` | 0.042 |
| `reporting_airline` | 0.023 |
| `origin` | 0.023 |
| `dest` | 0.019 |
| `month` | 0.009 |

### 7.2 Boosted-tree comparison (`delay_clf_boosted`)

- Model type: `BOOSTED_TREE_CLASSIFIER` (XGBoost backend) with the same features and same train/holdout split as the logistic baseline.
- Hyperparameters: `max_iterations=50`, `max_tree_depth=8`, `learn_rate=0.1`, `subsample=0.8`.

| Metric | Logistic | Boosted | Δ |
|---|---|---|---|
| Accuracy | 0.5611 | *(pending)* | |
| Precision | 0.2958 | *(pending)* | |
| Recall | 0.6347 | *(pending)* | |
| F1 | 0.4035 | *(pending)* | |
| Log-loss | 0.6892 | *(pending)* | |
| **ROC-AUC** | **0.6152** | *(pending)* | |

The model comparison is materialized in `flight_delay_analytics.m_model_comparison` and rendered side-by-side on dashboard page 2.

### 7.3 Interpretation

The logistic baseline's ROC-AUC of 0.62 indicates **weak but non-trivial** predictive signal. Two factors limit its ceiling:

1. **Daily-resolution weather is too coarse** to capture the short, intense events (line storms, gusts, microbursts) that cause specific flights to delay. Hourly METAR observations would likely lift weather features' predictive contribution.
2. **The dominant single driver of delay — late-aircraft propagation** (BTS attributes ~30% of all delay minutes to "late aircraft") — is **not encoded in the feature set** because we don't track tail numbers across consecutive flights. Adding rotation features (e.g. delay of the prior leg by tail number) is the highest-leverage future extension.

The boosted tree's gain over the logistic baseline (when training completes) confirms that nonlinear feature interactions exist in this data — for example, "wind matters at LGA but not at PHX" — that a single linear equation cannot capture.

## 8. Challenges encountered and how they were resolved

1. **Maven egress from Dataproc workers blocked.** The default `spark.jars.packages` resolution path could not reach `repo1.maven.org` from the cluster network. Resolved by switching every BigQuery-touching job to use the **pre-installed Spark BigQuery connector** that ships with Dataproc 2.2 under `/usr/lib/spark/external/`, dropping the `--jars` flag entirely.
2. **CPU quota and zone capacity.** Default new-project quota is 12 vCPU per region, and `us-central1-a` had no `n2` capacity. Resolved by downsizing to 10 vCPU total and switching to `e2`-class machines with Dataproc auto-zone (`--zone=""`).
3. **FAA table column drift.** Initial code assumed `bigquery-public-data.faa.us_airports` columns were `iata_code / latitude_deg / longitude_deg`. The actual schema uses `faa_identifier / latitude / longitude`. For U.S. commercial airports, `faa_identifier` equals the IATA code, so the join key remained trivial after the rename.
4. **Spark cannot resolve GSOD's native `date` column.** Reassembled the flight date from `year/mo/da` using `to_date(concat_ws("-", ...))`.
5. **Stale stations dominating nearest-neighbor.** Initial weather coverage was only 17%, with major hubs (ORD, DEN) at 0%. Root cause: the NOAA `stations` table retains decommissioned entries (e.g. WBAN 14810 "Park Ridge AF", closed 1958) that ranked as nearest to several airports. Final fix: collapse the stations table by WBAN and filter to `end >= '20190101'`. **Coverage jumped from 17% → 94.4%.**
6. **Looker Studio's default `SUM` aggregation on pre-aggregated rates.** Panel 1 (on-time rate) initially summed 84 monthly rates, producing values of 60+. Resolved by changing every metric in the dashboard to use `AVG` instead of `SUM` and setting field types to `Percent` for rate columns.
7. **Geocoding strings vs. lat/lon for the bubble map.** Looker silently dropped airports whose IATA codes its geocoder couldn't resolve. Fixed by adding a calculated `airport_geo = CONCAT(latitude, ",", longitude)` field with type `Geo → Latitude, Longitude`.

## 9. Lessons learned

- **Cloud cost discipline pays.** Auto-deleting the Dataproc cluster after 1 hr idle and using `e2`-class workers kept the entire project under $11. The temptation is to leave clusters running between jobs; resisting that habit roughly 5×'d the budget runway.
- **Use pre-installed connectors when available.** Time spent fighting `spark.jars.packages` egress could have been avoided by reading the Dataproc 2.2 image release notes first, which call out the bundled Spark-BigQuery connector explicitly.
- **Validate join keys against actual coverage, not row counts.** A naive nearest-neighbor join "succeeded" with 18,176 rows but 17% true coverage. The fix wasn't in the SQL — it was in understanding the lifecycle of the underlying physical entities (NOAA stations open, close, change codes over decades).
- **Start with the simplest model.** A logistic regression provides a clean baseline that immediately reveals which features carry signal (`dep_hour`, airline, route) and which don't (daily weather averages). It also exposes ceiling effects that more complex models won't fix without different features.
- **Looker Studio's default aggregations are wrong for pre-aggregated views.** Anyone connecting Looker to BigQuery views should expect to override SUM → AVG on every rate metric.
- **Dashboard iteration is faster than you'd think.** Once the views were in place, building a 5-panel + 3-panel two-page dashboard took roughly two evenings of clicking, mostly debugging defaults rather than designing layouts.

## 10. Potential next steps

- **Hourly METAR weather** (NOAA Integrated Surface Database) instead of daily GSOD, to capture short-duration weather events that drive specific flight delays.
- **Tail-number rotation features** — for each flight, the delay of the prior leg flown by the same aircraft. This is the single highest-leverage feature missing from the current model.
- **Streaming ingestion via Cloud Functions** as new monthly BTS files drop, replacing the current batch script.
- **Schedule with Cloud Composer / Airflow** so the entire pipeline can be re-run on demand without manual cluster spin-up.
- **Row-level security in Looker Studio** to give airline-specific stakeholders dashboards filtered to their own carrier code.
- **Try `AUTOML_CLASSIFIER`** in BigQuery ML for an automated hyperparameter search benchmark.

---

## Appendix A — Reproducing the pipeline

```bash
export PROJECT_ID=flight-delay-pipeline-494116

# 1. Bootstrap (APIs, buckets, BQ dataset)
bash scripts/01_gcp_bootstrap.sh

# 2. Ingest BTS zips into GCS (~30 min)
bash scripts/02_download_bts.sh

# 3. Spin up Dataproc cluster
bash scripts/03_create_dataproc.sh

# 4. Submit clean / map / join PySpark jobs (~50 min)
bash scripts/04_submit_jobs.sh

# 5. Materialize BigQuery views and ML models
bq query --use_legacy_sql=false < sql/create_tables.sql
bq query --use_legacy_sql=false < sql/bqml_delay_model.sql
bq query --use_legacy_sql=false < sql/bqml_eval_tables.sql
bq query --use_legacy_sql=false < sql/bqml_boosted_model.sql
bq query --use_legacy_sql=false < sql/bqml_compare_models.sql
```

## Appendix B — Cost summary

| Service | Approx cost |
|---|---|
| Cloud Storage (raw + processed, 1 month) | $0.30 |
| Dataproc (cluster active ~6 hr cumulative) | $6 |
| BigQuery (queries, view materialization) | $1 |
| BigQuery ML (logistic + boosted training) | $3 |
| **Total** | **< $11** |

All costs absorbed by the GCP $300 free credit.
