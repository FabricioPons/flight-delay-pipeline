# U.S. Airline Flight Delay Analytics Pipeline

End-to-end data pipeline on Google Cloud Platform analyzing U.S. flight delays (2019–2025) enriched with NOAA weather observations.

**Author:** Fabricio Pons Samano
**Course:** Data Intensive Systems — Final Project

## Architecture

```
BTS TranStats (84 monthly CSVs)       NOAA GSOD (BigQuery public dataset)
         │                                       │
         ▼                                       │
   GCS raw/flights/                              │
         │                                       │
         ▼                                       │
   Dataproc (PySpark)  ── clean_flights.py       │
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

## Services used

| Service | Purpose |
|---|---|
| Google Cloud Storage | Raw CSVs + processed Parquet |
| Dataproc (Spark 3.5) | Cleaning, transformation, flight × weather join |
| BigQuery | Data warehouse + analytical SQL |
| BigQuery ML | Logistic regression delay classifier |
| Looker Studio | Interactive dashboard |

## Repo layout

```
docs/         Proposal, requirements, check-in, final report
scripts/      Shell scripts to bootstrap GCP and run the pipeline
pyspark/      PySpark ETL jobs
sql/          BigQuery DDL + analytics + ML training
dashboard/    Looker Studio build spec + screenshots
slides/       Presentation deck
```

## Running the pipeline

1. Create a GCP project + enable billing.
2. Install + authenticate gcloud CLI.
3. Set `PROJECT_ID` env var, then run:
   ```
   bash scripts/01_gcp_bootstrap.sh
   bash scripts/02_download_bts.sh
   bash scripts/03_create_dataproc.sh
   bash scripts/04_submit_jobs.sh
   bq query --use_legacy_sql=false < sql/create_tables.sql
   bq query --use_legacy_sql=false < sql/bqml_delay_model.sql
   ```
4. Open Looker Studio → follow `dashboard/looker_studio.md`.

## Status

See `docs/checkin_report.md` and `docs/final_report.md` for current progress.
