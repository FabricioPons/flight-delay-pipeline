# Looker Studio Dashboard — Build Spec

This dashboard is fed by five BigQuery views in
`flight-delay-pipeline-494116.flight_delay_analytics`:

| View | Feeds |
|---|---|
| `v_monthly_ontime_trend` | Panel 1 (time series) |
| `v_delay_cause_breakdown` | Panel 2 (stacked bar by cause) |
| `v_airport_delay_heatmap` | Panel 3 (geo map) |
| `v_weather_correlation` | Panel 4 (heatmap / bar by wind) |
| `v_airline_kpi` | Panel 5 (table) |

---

## ⚠ Aggregation rule — read first

Every metric in every view is **already aggregated per row** (one row per
month, per airline, per airport, etc). Looker Studio's default of `SUM`
will re-sum them and produce nonsense (a monthly on-time rate of 0.78
summed across 84 months is meaningless).

**Set every numeric metric's aggregation to `AVG`** (not SUM), and for
rates/percents set the field **Type** to **Percent** so `0.78` renders as
`78.0%`. Do this by clicking the metric chip in the Setup panel → change
**Aggregation**, and click the field name → change **Type**.

---

## One-time connection steps

1. Open **https://lookerstudio.google.com** (same Google account as GCP).
2. Top-left **"Create" → "Data source" → "BigQuery"**.
3. Authorize → pick project `flight-delay-pipeline-494116` → dataset
   `flight_delay_analytics`. Connect to each of the five views above as a
   separate data source (repeat step 2–3 five times, or use "Add data" inside
   the report).
4. Top-left **"Create" → "Report"**.
5. When prompted for a source, pick `v_monthly_ontime_trend` first; add the
   others via **"Resource → Manage added data sources → Add a data source"**.

## Panel build order

### Panel 1 — Monthly on-time rate (2019–2025)
- Chart: **Time series** (or Combo if you add the secondary).
- Data source: `v_monthly_ontime_trend`.
- Date range dimension: `month`.
- Metric: `on_time_rate` — **Aggregation = AVG**, **Type = Percent**.
- Optional secondary metric: `delayed_flights` — Aggregation = AVG, put on
  **Right Y-axis** (Setup → Y-axis → Right) so it doesn't squash the rate line.
- Title: "Monthly On-Time Rate — COVID impact visible Mar–Jun 2020".

### Panel 2 — Delay cause breakdown by airline
- Chart type: **100% stacked column chart** (under the Bar chart family in
  the Chart types picker).
- Data source: `v_delay_cause_breakdown`.
- Dimension (X-axis): `reporting_airline`.
- **Breakdown dimension: LEAVE EMPTY.** (Do not put a metric column here —
  that's what splits a single metric by a categorical; we want the opposite.)
- Metric (Y-axis) — **add all five** with **Aggregation = SUM**:
  `carrier_delay_min`, `weather_delay_min`, `nas_delay_min`,
  `security_delay_min`, `late_aircraft_delay_min`.
- Filter control above chart: `month` (range).
- Title: "Where Do Delays Come From? (by Airline)".

> Aggregation note: these five columns are pre-computed minute totals per
> (airline, month), so SUM rolls up to per-airline totals. (Panel 1's
> `on_time_rate` was a rate, so we used AVG instead.)

### Panel 3 — Airport delay heatmap
- Chart: **Geo chart → Google Maps → Bubble map**.
- Data source: `v_airport_delay_heatmap`.
- Location: create a **Geo field** by combining `latitude` and `longitude`
  (Resource → Manage added data sources → select the source → click Add a
  Field, use a formula like `CONCAT(latitude, ",", longitude)` with type
  "Latitude, Longitude").
- Bubble size metric: `total_flights` — Aggregation **SUM** (pre-aggregated
  per airport; SUM = passthrough since one row per airport).
- Bubble color metric: `avg_arr_delay_min` — Aggregation **AVG**.
- Title: "Average Arrival Delay by Origin Airport".

### Panel 4 — Weather vs delay rate
- Chart type: **Pivot table with heatmap** (Tables → Pivot table, then in
  Style turn on the heatmap conditional formatting).
- Data source: `v_weather_correlation`.
- Rows: `wind_bucket`.
- Columns: `visib_bucket`.
- Metric: `delay_rate` — Aggregation **AVG**, Type **Percent**.
- Title: "Delay Rate by Wind × Visibility Bucket (Origin Weather)".

### Panel 5 — Airline KPI table
- Chart type: **Table with heatmap** (Tables → Table, then Style → turn on
  heatmap conditional formatting).
- Data source: `v_airline_kpi`.
- Dimension: `reporting_airline`.
- Metrics (one row per airline in the view, so any aggregation = passthrough;
  use **AVG** to be safe):
  - `flights` — AVG, Type Number (comma thousands).
  - `avg_arr_delay_min` — AVG, Type Number (1 decimal).
  - `on_time_pct` — AVG, Type Percent (already scaled 0-100 in the view;
    if the view returns 78.16 and Looker shows 7816%, divide by 100 with
    a calculated field — unlikely; Percent type in Looker expects 0-1 so
    set Type to Number with a `%` suffix via Style instead).
  - `cancellation_pct` — same as above.
- Conditional formatting: color-scale `avg_arr_delay_min` (red = higher).
- Title: "Airline Performance Summary (2019–2025)".

---

## ML panels (page 2 of the dashboard)

Three tables back the ML portion — feed them to Looker Studio as additional
data sources just like the five views above:

| Table | Panel |
|---|---|
| `m_eval_metrics` | Panel 6 (scorecards) |
| `m_confusion_matrix` | Panel 7 (pivot heatmap) |
| `m_feature_importance` | Panel 8 (horizontal bar) |

Add a second page to the report (Page → Add page) so these don't clutter
the main analytics canvas.

### Panel 6 — Model quality scorecards
- Chart type: six **Scorecard** charts (one per metric) laid out in a row.
  Or a single **Table** with one row if you'd rather.
- Data source: `m_eval_metrics`.
- Metrics (each Scorecard takes exactly one):
  - `roc_auc` — AVG, Type Number (3 decimals). Title: "ROC-AUC".
  - `accuracy` — AVG, Type Percent. Title: "Accuracy".
  - `precision` — AVG, Type Percent. Title: "Precision".
  - `recall` — AVG, Type Percent. Title: "Recall".
  - `f1` — AVG, Type Percent. Title: "F1".
  - `log_loss` — AVG, Type Number (3 decimals). Title: "Log-loss".

### Panel 7 — Confusion matrix (2025 holdout)
- Chart type: **Pivot table with heatmap**.
- Data source: `m_confusion_matrix`.
- Row dimension: `actual` (0 = on-time, 1 = delayed).
- Column dimension: `predicted`.
- Metric: `flights` — SUM, Type Number (comma thousands).
- Title: "Confusion Matrix (threshold 0.5)".

### Panel 8 — Feature importance
- Chart type: **Horizontal bar chart** (Bar → Horizontal).
- Data source: `m_feature_importance`.
- Dimension: `feature`.
- Metric: `attribution` — AVG, Type Number (4 decimals).
- Sort: descending on `attribution`.
- Title: "Feature Importance (ML.GLOBAL_EXPLAIN)".

> Interpretation for the report: `dep_hour` dominates, followed by
> `reporting_airline`, `origin`, and `dest`. Operational factors outweigh
> the weather features we added — a good motivating finding for the
> "next steps" section (try a boosted-tree classifier, more granular
> weather data).

---

## Page-level controls (top of dashboard)

- Date range control bound to `flight_date` (or `month` where relevant).
- Filter control on `reporting_airline` (multi-select).
- Filter control on `origin` (single-select autocomplete).

## Share + export for report

1. Top-right **"Share" → "Manage access"** → set to
   **"Anyone with the link → Viewer"**. Copy link.
2. Paste link at the top of `docs/final_report.md` (replace the placeholder).
3. Take a full-page screenshot (File → Download → PDF) and save to
   `dashboard/screenshots/dashboard.pdf` before submission.
