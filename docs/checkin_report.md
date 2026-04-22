# Project Check-in Report

**Name:** Fabricio Pons Samano
**Course:** Data Intensive Systems — Final Project
**Date:** 2026-04-22
**Project:** U.S. Airline Flight Delay Analysis Pipeline on GCP

---

## 1. What I have completed so far

### Infrastructure (Phases 0–2)
- **GCP project** `flight-delay-pipeline-494116` created, billing linked, `gcloud` CLI authenticated.
- **APIs enabled:** Cloud Storage, Dataproc, BigQuery, BigQuery Connection, Vertex AI, Compute.
- **GCS buckets** in `us-central1`: `-raw`, `-processed`, `-dataproc-staging`.
- **BigQuery dataset** `flight_delay_analytics` in `US` multi-region (required to join the public `bigquery-public-data.noaa_gsod` dataset).

### Data ingestion (Phase 3)
- 84 monthly BTS On-Time Performance zips (**2019-01 through 2025-12**) streamed from `transtats.bts.gov/PREZIP/…` directly into GCS, partitioned by `year=YYYY/month=M`. ~2.4 GB compressed. Took 31 min end-to-end.
- NOAA GSOD queried in place from `bigquery-public-data.noaa_gsod.gsod*` — no ingestion.

### PySpark processing on Dataproc (Phase 4)
- **Cluster:** 1 × `e2-standard-2` master + 2 × `e2-standard-4` workers (10 vCPU), Dataproc image 2.2 (Spark 3.5). Auto-delete after 1 hr idle.
- **`clean_flights.py`** — parses each BTS zip with `zipfile` inside `sc.binaryFiles`, projects to 31 columns, coerces types, adds derived fields (`year`, `month`, `day_of_week`, `dep_hour`, `is_delayed_15`), writes Parquet partitioned by year/month. **84 output partitions.**
- **`airport_station_map.py`** — haversine nearest-neighbor join between `bigquery-public-data.faa.us_airports` and `bigquery-public-data.noaa_gsod.stations`, collapsed by WBAN and filtered to stations active through 2019+. **18,176 IATA → WBAN pairs.**
- **`join_flights_weather.py`** — joins cleaned flights with NOAA GSOD on WBAN + date for both origin and destination airports. Writes to `flight_delay_analytics.flights_weather_enriched` in BigQuery, partitioned by `flight_date` and clustered by `(reporting_airline, origin, dest)`.

### BigQuery analytics (Phase 5)
Five dashboard-backing views created in `flight_delay_analytics`:

| View | Purpose |
|---|---|
| `v_monthly_ontime_trend` | Monthly flights, cancel count, delay count, on-time rate |
| `v_delay_cause_breakdown` | Minutes attributed to carrier/weather/NAS/security/late aircraft by airline×month |
| `v_airport_delay_heatmap` | Per-origin lat/lon + avg delay + cancel rate (joined to FAA airports) |
| `v_weather_correlation` | Delay / cancel rate bucketed by wind × precip × visibility |
| `v_airline_kpi` | Per-airline flights, avg delay, on-time %, cancel %, diversion % |

### Headline numbers from the materialized warehouse
- **Total flights (2019–2025):** 45,763,492
- **Weather-join coverage overall:** 94.4% of flights have origin weather attached; major hubs (ATL, DFW, DEN, ORD, LAX, …) all between 93.6% and 95.5%.
- **Airline leaderboard (on-time % at arr_del15 = 0):**
  Delta (DL) 83.3% · SkyWest (OO) 81.1% · YX 81.2% · AS 78.9% · UA 78.9% · WN 78.2% · OH 78.0% · AA 76.1% · B6 71.4%
- **COVID impact (cancel %):** 2019 baseline 1.82% → 2020 spike to **5.99%** → 2021 recovery to 1.72%.

### BigQuery ML model (Phase 6)
`flight_delay_analytics.delay_clf` — logistic regression on 2019–2024, evaluated on 2025 holdout:

| Metric | Value |
|---|---|
| Accuracy | 0.561 |
| Precision | 0.296 |
| Recall | 0.635 |
| F1 | 0.403 |
| Log-loss | 0.689 |
| **ROC-AUC** | **0.615** |

**Global feature importance (top 5):**
1. `dep_hour` (0.042)
2. `reporting_airline` (0.023)
3. `origin` (0.023)
4. `dest` (0.019)
5. `month` (0.009)

Operational factors dominate over weather in this simple linear model; extending to a boosted-tree classifier before the final submission is in the next-steps list.

### Repository
- Git-initialized and fully committed (20+ granular commits). All scripts (`scripts/`), PySpark jobs (`pyspark/`), SQL (`sql/`), dashboard spec (`dashboard/looker_studio.md`), and report drafts (`docs/`) are in place and reproducible via a single environment variable (`PROJECT_ID`).

### Progress vs. plan
Roughly **75–80% complete**. Infrastructure, ingestion, transformation, warehouse, and a trained ML model are all done with real numbers. What remains: the Looker Studio dashboard (manual UI build following `dashboard/looker_studio.md`), a final-report fill-in, presentation slides, and the GitHub push.

---

## 2. Challenges encountered and how they were resolved

1. **Maven egress from Dataproc workers blocked.** The cluster couldn't reach `repo1.maven.org` to resolve `spark.jars.packages`. Switched every BigQuery-touching job to use the pre-installed Spark BigQuery connector (Dataproc 2.2 ships it under `/usr/lib/spark/external/`) — dropped the `--jars` flag entirely.
2. **Zone capacity + CPU quota hiccups.** Default new-project quota is 12 vCPU / region; `us-central1-a` was out of `n2` capacity. Downsized to 10 vCPU total and switched to `e2-class` machines with Dataproc's Auto Zone.
3. **FAA table column drift.** Assumed `bigquery-public-data.faa.us_airports` had `iata_code / latitude_deg / longitude_deg`; real schema uses `faa_identifier / latitude / longitude`. For US commercial airports `faa_identifier` equals the IATA code, so the join key remained trivial after the rename.
4. **`date` column trips Spark SQL.** GSOD exposes a native `date` column but Spark's column resolver can't select it directly. Reassembled the date from `year/mo/da`.
5. **Stale stations dominated nearest-neighbor matches.** The NOAA `stations` table retains historical entries (e.g., "Park Ridge AF", closed 1958) that outranked live stations for ORD and DEN. Final fix: collapse by WBAN (5-digit US-specific id, stable across USAF changes) and filter candidates to stations with `end >= 20190101`. Coverage jumped from 17% to 94.4%.

---

## 3. Planned next steps (before May 6 presentation)

- **This week (Apr 23–27):** Build the Looker Studio dashboard from `dashboard/looker_studio.md` — five panels over the five views. Take screenshots for the report.
- **Apr 28 – May 2:** Try `BOOSTED_TREE_CLASSIFIER` in BigQuery ML and compare ROC-AUC against the logistic baseline. Add a model-quality section to the final report.
- **May 3–5:** Finish the final report (9 required sections), draft presentation slides, run a dry-run of the 5-minute demo.
- **May 6 or 7:** Present.
- **May 8–10:** Create GitHub repo, push all commits, add instructor as collaborator, submit the link via Canvas.

---

## 4. Cost to date

Under **$8** of the $300 free credit (GCS ≈ $0.30, Dataproc ≈ $6, BigQuery ≈ $1, BQML ≈ $0.50).
