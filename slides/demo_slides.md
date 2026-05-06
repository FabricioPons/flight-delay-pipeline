# 5-min Demo Slide Deck — Markdown Outline

Copy each block into Google Slides / Keynote / PowerPoint as a separate slide.
Speaker notes are in italics under each slide.

---

## Slide 1 — Title

**U.S. Airline Flight Delay Analysis Pipeline**

End-to-end on Google Cloud Platform — BTS + NOAA + FAA, processed at scale, served via Looker Studio + BigQuery ML

Fabricio Pons Samano · Data-Intensive Systems · May 2026

*Speaker note: 30 seconds — name, project, mention "45 million flights, full year-round 2019–2025 dataset."*

---

## Slide 2 — Problem & datasets

**The question:** Can we explain — and predict — U.S. flight delays from publicly available data?

| Dataset | Source | Volume |
|---|---|---|
| BTS On-Time Performance | TranStats monthly zips | 45.76M flights |
| NOAA GSOD weather | BigQuery public dataset | ~9k active U.S. stations |
| FAA airports | BigQuery public dataset | Lat/lon for ~20k airports |

*Speaker note: Stress that BTS does not include weather, NOAA does not include flights — joining them is the analytical core of the project.*

---

## Slide 3 — Architecture

```
BTS zips ──► GCS raw ──► Dataproc/PySpark ──► GCS Parquet
                                  │
NOAA GSOD ────────────────────────┤
                                  │
FAA airports ─────────────────────┤
                                  ▼
                          BigQuery warehouse
                            │            │
                            ▼            ▼
                     Looker Studio   BigQuery ML
                       dashboard     (delay model)
```

**Stack:** Cloud Storage · Dataproc (Spark 3.5) · BigQuery · BigQuery ML · Looker Studio
**Cost so far:** under $11 of $300 free credit

*Speaker note: 30 seconds — emphasize this is a real cloud-native pipeline, not a notebook. Cluster auto-deletes after 1 hr idle.*

---

## Slide 4 — The numbers that matter

- **45,763,492** flight records cleaned and stored in BigQuery
- **94.4%** weather-join coverage (origin airport)
- **18,176** IATA → NOAA station pairs after haversine nearest-neighbor
- **31 min** total wall-clock time to ingest seven years of BTS data
- **10 vCPU** total Dataproc cluster (1 master + 2 workers)

*Speaker note: Anchor the audience on scale. "45 million rows" is the number to repeat.*

---

## Slide 5 — Dashboard, page 1

[Insert screenshot of Looker Studio page 1 — five panels]

Five panels: monthly trend, delay-cause breakdown, airport map, weather heatmap, airline KPI table

*Speaker note: Point at COVID dip in panel 1 (Mar–Jun 2020), point at panel 4 wind-vs-visibility heatmap. Mention DL leads on-time at 83.3%.*

---

## Slide 6 — Dashboard, page 2 — the ML part

[Insert screenshot of Looker Studio page 2 — three panels]

Six scorecards · Confusion matrix on 2025 holdout · Feature importance bar chart

*Speaker note: This is what makes the project a data-intensive **systems** project, not just a SQL exercise. Live BigQuery ML model, evaluated on a real out-of-time holdout, surfaced through dashboard tables.*

---

## Slide 7 — Key analytical findings

1. **COVID is sharply visible** — cancellation rate 1.82% (2019) → 5.99% (2020) → 1.72% (2021).
2. **Operational factors dominate weather** — `dep_hour` is the #1 ML feature; weather features rank below airline, origin, dest.
3. **Cancellation supplants delay at extreme weather** — delay rate peaks at 10–20 kt + poor visibility (39.6%) but drops to 5.3% at 30+ kt because flights get cancelled rather than flown.

*Speaker note: This is the "so what" slide. The third bullet is the surprise — say it slowly.*

---

## Slide 8 — Models compared

| Metric | Logistic | Boosted | Δ |
|---|---|---|---|
| ROC-AUC | 0.6152 | **0.6465** | +0.0313 |
| Precision | 0.2958 | **0.3164** | +0.0206 |
| Recall | 0.6347 | **0.6582** | +0.0235 |
| F1 | 0.4035 | **0.4273** | +0.0238 |

Same features, same train (2019–2024) / holdout (2025) split.

**Plot twist:** Boosted tree promotes `visibility` to the #2 feature (was buried in the logistic model). Operational categoricals (`origin`, `airline`) drop in importance — the linear model was inflating their apparent value via one-hot expansion.

*Speaker note: Lead with ROC-AUC. The +0.03 lift is modest — be honest about it. The interesting story is the feature reordering: nonlinear models reveal that visibility is a genuine predictor that linear models hide. Both models cap around 0.65 because daily weather + no rotation tracking sets a ceiling.*

---

## Slide 9 — Challenges & lessons

- **NOAA stations have ghost rows.** A 1958-decommissioned station outranked the live one for ORD. Filter `end >= 20190101` jumped coverage 17% → 94.4%.
- **Looker Studio's default `SUM` aggregation** silently turns 84 monthly rates of 0.78 into a "78x" rate. Override every metric to AVG.
- **Daily weather is too coarse** for predicting *specific flight* delays. The next leverage point is hourly METAR + tail-number rotation features.

*Speaker note: One sentence each. Don't dwell.*

---

## Slide 10 — What's next + demo link

**Future work:**
- Hourly METAR weather replacing daily GSOD
- Tail-number rotation features (the missing big lever)
- Airflow-scheduled monthly re-runs
- AutoML benchmark

**Live dashboard:** *(paste Looker Studio share URL here)*

**Repo:** *(paste GitHub URL here)*

*Speaker note: 30 seconds. Hand the link to the audience for live exploration. Done.*
