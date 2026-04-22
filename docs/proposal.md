# Project Proposal: U.S. Airline Flight Delay Analysis Pipeline

**Name:** Fabricio Pons Samano

---

## 1. Dataset Description

This project uses two complementary public datasets:

### Primary Dataset: U.S. Bureau of Transportation Statistics (BTS) Airline On-Time Performance

- **Source:** [BTS TranStats](https://www.transtats.bts.gov/DL_SelectFields.aspx?gnoyr_VQ=FGJ&QO_fu146_anzr=b0-gvzr) (U.S. Department of Transportation)
- **Size:** Over **150 million flight records** spanning from October 1987 to present (~12-15 GB in CSV). For this project, I will focus on a recent multi-year subset (2019-2025), which contains approximately **30-40 million rows**.
- **Format:** Structured CSV files, downloadable by month/year with selectable fields.
- **Features (31+ columns):** FlightDate, Reporting_Airline, TailNumber, FlightNumber, Origin, Destination, CRSDepTime, DepTime, DepDelay, TaxiOut, TaxiIn, ArrDelay, Cancelled, CancellationCode, Diverted, ActualElapsedTime, AirTime, Distance, and five granular delay cause columns (CarrierDelay, WeatherDelay, NASDelay, SecurityDelay, LateAircraftDelay).
- **Characteristics:** Structured tabular data. Contains missing values (delay causes are only populated for delayed flights; cancelled flights lack arrival times). Requires cleaning of time formats, categorical encoding of cancellation codes, and handling of diverted flight edge cases.

### Secondary Dataset: NOAA Global Surface Summary of the Day (GSOD)

- **Source:** [BigQuery Public Dataset](https://console.cloud.google.com/bigquery?p=bigquery-public-data&d=noaa_gsod) (`bigquery-public-data.noaa_gsod`)
- **Size:** Over **2.5 billion records** across ~9,000 weather stations worldwide, partitioned by year.
- **Format:** BigQuery tables (directly queryable).
- **Features:** Station ID, date, mean/max/min temperature, dew point, sea level pressure, visibility, wind speed (mean/max/gust), precipitation, snow depth, and fog/rain/snow/hail/thunder indicator flags.
- **Usage:** Weather observations at airport-adjacent stations will be joined with flight records to correlate weather conditions with delay patterns.

---

## 2. GCP Services Planned

| Service | Purpose |
|---|---|
| **Google Cloud Storage** | Store raw CSV files from BTS and intermediate processed data |
| **Dataproc (PySpark)** | Clean, transform, and join flight data with weather data at scale |
| **BigQuery** | Data warehouse for processed/joined tables; run analytical SQL queries |
| **Looker Studio** | Build interactive analytics dashboard for final visualizations |
| **Cloud Functions** (optional) | Automate ingestion of new monthly BTS data files into Cloud Storage |

---

## 3. Final Product

An **interactive analytics dashboard** in Looker Studio that provides insights into U.S. flight delay patterns, including:

- **Delay cause breakdown:** Proportion of delays attributed to carrier, weather, NAS, security, and late aircraft, with filters by airline, airport, and time period.
- **Geographic heatmaps:** Origin/destination airports color-coded by average delay, cancellation rate, or on-time performance.
- **Temporal trends:** Monthly and yearly trends in delay rates, showing the impact of COVID-19 on air travel and the post-pandemic recovery.
- **Weather correlation analysis:** How weather conditions (wind, precipitation, visibility, temperature extremes) at origin and destination airports correlate with flight delays and cancellations.
- **Airline performance comparison:** Side-by-side metrics for major U.S. carriers across key performance indicators.

---

## 4. Why This Dataset Is Suitable for a Large-Scale Data Pipeline

This project is well-suited for a data-intensive cloud pipeline for several reasons:

1. **Scale:** The BTS dataset alone contains 30-40 million rows for the target time period (and 150M+ historically). Joining this with NOAA weather records (2.5B+ rows) produces a cross-referencing workload that exceeds local machine memory and processing capacity, making distributed processing via Dataproc essential.

2. **Multi-source integration:** The pipeline must ingest data from two independent sources in different formats (CSV files from BTS and BigQuery tables from NOAA), match them by airport location and date, and produce a unified analytical dataset. This cross-dataset join is a core data engineering challenge that benefits from cloud-scale infrastructure.

3. **Data complexity:** The flight data requires substantial cleaning -- handling missing delay-cause fields, parsing time-of-day columns, resolving cancelled/diverted edge cases, and standardizing airline codes across years. The weather join requires mapping airport codes (IATA) to nearby NOAA weather station IDs, adding a non-trivial geospatial matching step.

4. **Analytical depth:** The enriched dataset supports both descriptive analytics (dashboards, trend analysis) and potentially predictive modeling (delay prediction), demonstrating the full value chain from raw data to actionable insights.
