-- Ad-hoc analytical queries that back the final report's "Results" section.
-- Use in the BigQuery console; each SELECT returns a table you can screenshot.

-- 1. Headline numbers ----------------------------------------------------------
SELECT
  COUNT(*)                                AS total_flights,
  COUNTIF(cancelled = 1)                  AS cancelled,
  COUNTIF(diverted = 1)                   AS diverted,
  ROUND(AVG(arr_delay_minutes), 2)        AS avg_arr_delay_min,
  MIN(flight_date)                        AS min_date,
  MAX(flight_date)                        AS max_date
FROM `flight-delay-pipeline-494116.flight_delay_analytics.flights_weather_enriched`;

-- 2. COVID impact: 2019 baseline vs 2020 drop --------------------------------
SELECT
  EXTRACT(YEAR FROM flight_date) AS year,
  COUNT(*)                        AS flights,
  ROUND(AVG(arr_delay_minutes), 2) AS avg_arr_delay_min,
  ROUND(SAFE_DIVIDE(COUNTIF(cancelled = 1), COUNT(*)) * 100, 2) AS cancel_pct
FROM `flight-delay-pipeline-494116.flight_delay_analytics.flights_weather_enriched`
GROUP BY year
ORDER BY year;

-- 3. Worst 10 airports by average delay (min. 50k flights) --------------------
SELECT
  origin,
  COUNT(*)                             AS flights,
  ROUND(AVG(arr_delay_minutes), 2)     AS avg_arr_delay_min,
  ROUND(SAFE_DIVIDE(COUNTIF(arr_del15 = 1), COUNT(*)) * 100, 2) AS delay_pct
FROM `flight-delay-pipeline-494116.flight_delay_analytics.flights_weather_enriched`
WHERE cancelled = 0
GROUP BY origin
HAVING flights >= 50000
ORDER BY avg_arr_delay_min DESC
LIMIT 10;

-- 4. Weather-driven delays: high wind vs calm at origin -----------------------
SELECT
  CASE WHEN origin_wdsp >= 20 THEN 'windy (>=20 kt)' ELSE 'calm (<20 kt)' END AS wind_cat,
  COUNT(*)                                                     AS flights,
  ROUND(AVG(arr_delay_minutes), 2)                              AS avg_arr_delay_min,
  ROUND(SAFE_DIVIDE(COUNTIF(arr_del15 = 1), COUNT(*)) * 100, 2) AS delay_pct
FROM `flight-delay-pipeline-494116.flight_delay_analytics.flights_weather_enriched`
WHERE origin_wdsp IS NOT NULL
GROUP BY wind_cat;

-- 5. Delay cause attribution across all delayed flights -----------------------
SELECT
  SUM(carrier_delay)        AS total_carrier_min,
  SUM(weather_delay)        AS total_weather_min,
  SUM(nas_delay)            AS total_nas_min,
  SUM(security_delay)       AS total_security_min,
  SUM(late_aircraft_delay)  AS total_late_aircraft_min
FROM `flight-delay-pipeline-494116.flight_delay_analytics.flights_weather_enriched`
WHERE arr_del15 = 1;
