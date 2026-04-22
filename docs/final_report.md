# U.S. Airline Flight Delay Analysis Pipeline — Final Report

**Name:** Fabricio Pons Samano
**Course:** Data-Intensive Systems — Final Project
**Date:** *(to fill in before May 10 submission)*
**Repository:** *(GitHub URL — to add)*
**Dashboard:** *(Looker Studio share link — to add)*

---

## 1. Project overview and goals

This project builds an end-to-end cloud data pipeline on Google Cloud Platform (GCP) to analyze U.S. airline flight delays between 2019 and 2025, enriched with daily weather observations from the NOAA Global Surface Summary of the Day (GSOD) dataset. The goal is to produce an interactive analytics dashboard that surfaces how airline, route, time, and weather conditions correlate with on-time performance, and a lightweight machine-learning model that predicts whether a given flight will be delayed by 15 minutes or more.

## 2. Dataset description

### BTS On-Time Performance (primary)
*(Fill in: row count, date range, column count after ingest; copy highlights from `proposal.md`.)*

### NOAA GSOD (secondary)
*(Fill in: station count joined, observation date range, columns used.)*

## 3. Pipeline workflow and services used

```
BTS TranStats (84 monthly CSVs)       NOAA GSOD (BigQuery public)
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
| Transformation | Dataproc + PySpark (3.5) | Parse zips, coerce types, join flights × weather |
| Warehouse | BigQuery | Partitioned + clustered analytical tables and views |
| Analytics | BigQuery SQL | Five dashboard-backing views |
| ML | BigQuery ML | Logistic regression delay classifier |
| Visualization | Looker Studio | Interactive dashboard |

## 4. Data processing steps

### 4.1 BTS cleaning (`pyspark/clean_flights.py`)
*(Fill in: row count before/after filters, columns dropped, screenshot of Dataproc job summary.)*

### 4.2 Airport → weather-station mapping (`pyspark/airport_station_map.py`)
*(Fill in: # IATA airports, # NOAA stations matched, mean/median match distance.)*

### 4.3 Flight × weather join (`pyspark/join_flights_weather.py`)
*(Fill in: enriched row count, null coverage on weather columns.)*

### 4.4 BigQuery table materialization (`sql/create_tables.sql`)
*(Fill in: view names + row counts, partition/cluster keys.)*

## 5. Results

*(Copy/paste results from `sql/analytics_queries.sql` once executed. Suggested content:)*
- Headline numbers (total flights, cancellations, mean delay).
- 2019 vs 2020 comparison showing COVID-19 impact.
- Top-10 worst airports by delay.
- Wind-driven delay comparison.
- Aggregate delay cause attribution.

## 6. Visualizations / dashboard

*(Insert screenshot of Looker Studio dashboard + share link. Describe each of the five panels and what insight each surfaces.)*

## 7. BigQuery ML model

*(Fill in after running `sql/bqml_delay_model.sql`:)*
- Model type: logistic regression.
- Features: airline, origin, dest, dep hour, day-of-week, month, distance, origin wind / precip / visib / temp.
- Train window: 2019-01-01 to 2024-12-31.
- Holdout: 2025.
- ROC-AUC on holdout: *(value)*.
- Confusion matrix at 0.5: *(table)*.
- Top-5 features by `ML.GLOBAL_EXPLAIN`: *(list)*.

## 8. Challenges encountered and how they were resolved

1. **No public BTS API.** Reverse-engineered the TranStats PREZIP URL pattern to enable scripted `curl` ingestion.
2. **Zips inside GCS.** Spark CSV reader doesn't handle `.zip`; switched to `sc.binaryFiles` + Python `zipfile` module inside a distributed `flatMap`.
3. **IATA ↔ station matching.** Built a haversine nearest-neighbor join between FAA and NOAA station tables (≤50 km).
4. **BQ region pinning.** The NOAA public dataset is `US` multi-region; had to create the project dataset in `US` (not a specific region) so the cross-join works.
5. *(Add any additional challenges as they arise during execution.)*

## 9. Lessons learned

*(To fill in: reflections on cloud cost discipline, cluster sizing, Spark/BigQuery trade-offs, dashboard iteration.)*

## 10. Potential next steps

- Streaming ingestion via Cloud Functions as new monthly BTS files drop.
- Upgrade BQML model to `BOOSTED_TREE_CLASSIFIER` and compare ROC-AUC.
- Add hourly METAR weather (instead of daily GSOD) for finer-grained weather correlation.
- Surface airline-specific dashboards with row-level security filters in Looker Studio.
- Schedule the pipeline with Cloud Composer / Airflow for reproducibility.

---

## Appendix A — Reproducing the pipeline

```bash
export PROJECT_ID=flight-delay-pipeline-494116
bash scripts/01_gcp_bootstrap.sh
bash scripts/02_download_bts.sh
bash scripts/03_create_dataproc.sh
bash scripts/04_submit_jobs.sh
bq query --use_legacy_sql=false < sql/create_tables.sql
bq query --use_legacy_sql=false < sql/bqml_delay_model.sql
```

## Appendix B — Cost summary
*(Fill in actual costs from GCP billing → cost table — under $20 expected.)*
