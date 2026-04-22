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
- Chart: **Time series**.
- Data source: `v_monthly_ontime_trend`.
- Dimension: `month`.
- Metric: `on_time_rate` (format as percent).
- Secondary metric: `cancelled_flights` (bar overlay, optional).
- Title: "Monthly On-Time Rate — COVID impact visible Mar–Jun 2020".

### Panel 2 — Delay cause breakdown by airline
- Chart: **100% stacked bar**.
- Data source: `v_delay_cause_breakdown`.
- Dimension: `reporting_airline`.
- Breakdown metrics (in order): `carrier_delay_min`, `weather_delay_min`,
  `nas_delay_min`, `security_delay_min`, `late_aircraft_delay_min`.
- Filter control above chart: `month` (range).
- Title: "Where Do Delays Come From? (by Airline)".

### Panel 3 — Airport delay heatmap
- Chart: **Geo chart → Google Maps → Bubble map**.
- Data source: `v_airport_delay_heatmap`.
- Location: `latitude_deg, longitude_deg` (create a Geo field concatenating
  them if needed).
- Bubble size metric: `total_flights`.
- Bubble color metric: `avg_arr_delay_min`.
- Title: "Average Arrival Delay by Origin Airport".

### Panel 4 — Weather vs delay rate
- Chart: **Pivot table** or **heatmap**.
- Data source: `v_weather_correlation`.
- Rows: `wind_bucket`.
- Columns: `visib_bucket`.
- Metric: `delay_rate` (format as percent).
- Title: "Delay Rate by Wind × Visibility Bucket (Origin Weather)".

### Panel 5 — Airline KPI table
- Chart: **Table with heatmap**.
- Data source: `v_airline_kpi`.
- Dimension: `reporting_airline`.
- Metrics: `flights`, `avg_arr_delay_min`, `on_time_pct`, `cancellation_pct`.
- Conditional formatting: color-scale `avg_arr_delay_min` (red = higher).
- Title: "Airline Performance Summary (2019–2025)".

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
