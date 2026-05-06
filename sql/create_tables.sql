-- Dashboard-backing tables. Run after join_flights_weather.py has populated
-- flight_delay_analytics.flights_weather_enriched.
--
-- Replace `flight-delay-pipeline-494116` if running on a different project.

-- ============================================================
-- View: v_monthly_ontime_trend (Panel: monthly on-time %)
-- ============================================================
CREATE OR REPLACE VIEW `flight-delay-pipeline-494116.flight_delay_analytics.v_monthly_ontime_trend` AS
SELECT
  DATE_TRUNC(flight_date, MONTH)                     AS month,
  COUNT(*)                                           AS total_flights,
  COUNTIF(cancelled = 1)                             AS cancelled_flights,
  COUNTIF(arr_del15 = 1 AND cancelled = 0)           AS delayed_flights,
  SAFE_DIVIDE(COUNTIF(arr_del15 = 0 AND cancelled = 0), COUNT(*)) AS on_time_rate
FROM `flight-delay-pipeline-494116.flight_delay_analytics.flights_weather_enriched`
GROUP BY month;

-- ============================================================
-- View: v_delay_cause_breakdown (Panel: carrier/weather/NAS/security/late split)
-- ============================================================
CREATE OR REPLACE VIEW `flight-delay-pipeline-494116.flight_delay_analytics.v_delay_cause_breakdown` AS
SELECT
  reporting_airline,
  DATE_TRUNC(flight_date, MONTH) AS month,
  SUM(COALESCE(carrier_delay, 0))          AS carrier_delay_min,
  SUM(COALESCE(weather_delay, 0))          AS weather_delay_min,
  SUM(COALESCE(nas_delay, 0))              AS nas_delay_min,
  SUM(COALESCE(security_delay, 0))         AS security_delay_min,
  SUM(COALESCE(late_aircraft_delay, 0))    AS late_aircraft_delay_min,
  COUNT(*)                                  AS flights
FROM `flight-delay-pipeline-494116.flight_delay_analytics.flights_weather_enriched`
WHERE arr_del15 = 1
GROUP BY reporting_airline, month;

-- ============================================================
-- View: v_airport_delay_heatmap (Panel: geographic heatmap)
-- ============================================================
CREATE OR REPLACE VIEW `flight-delay-pipeline-494116.flight_delay_analytics.v_airport_delay_heatmap` AS
WITH ap AS (
  SELECT faa_identifier AS iata, latitude, longitude, name
  FROM `bigquery-public-data.faa.us_airports`
  WHERE faa_identifier IS NOT NULL
)
SELECT
  f.origin                                  AS iata,
  ap.name,
  ap.latitude,
  ap.longitude,
  COUNT(*)                                  AS total_flights,
  AVG(f.dep_delay_minutes)                  AS avg_dep_delay_min,
  AVG(f.arr_delay_minutes)                  AS avg_arr_delay_min,
  SAFE_DIVIDE(COUNTIF(f.cancelled = 1), COUNT(*)) AS cancellation_rate
FROM `flight-delay-pipeline-494116.flight_delay_analytics.flights_weather_enriched` f
JOIN ap ON f.origin = ap.iata
GROUP BY iata, name, latitude, longitude;

-- ============================================================
-- View: v_weather_correlation (Panel: weather buckets vs delay rate)
-- ============================================================
CREATE OR REPLACE VIEW `flight-delay-pipeline-494116.flight_delay_analytics.v_weather_correlation` AS
SELECT
  CASE
    WHEN origin_wdsp < 5   THEN '00-05 kt'
    WHEN origin_wdsp < 10  THEN '05-10 kt'
    WHEN origin_wdsp < 20  THEN '10-20 kt'
    WHEN origin_wdsp < 30  THEN '20-30 kt'
    ELSE '30+ kt'
  END                                       AS wind_bucket,
  CASE
    WHEN origin_prcp = 0   THEN 'none'
    WHEN origin_prcp < 0.1 THEN 'light'
    WHEN origin_prcp < 0.5 THEN 'moderate'
    ELSE 'heavy'
  END                                       AS precip_bucket,
  CASE
    WHEN origin_visib >= 10 THEN 'clear (>=10 mi)'
    WHEN origin_visib >= 3  THEN 'reduced (3-10 mi)'
    ELSE 'poor (<3 mi)'
  END                                       AS visib_bucket,
  COUNT(*)                                  AS flights,
  SAFE_DIVIDE(COUNTIF(arr_del15 = 1), COUNT(*)) AS delay_rate,
  SAFE_DIVIDE(COUNTIF(cancelled = 1), COUNT(*)) AS cancellation_rate
FROM `flight-delay-pipeline-494116.flight_delay_analytics.flights_weather_enriched`
WHERE origin_wdsp IS NOT NULL
GROUP BY wind_bucket, precip_bucket, visib_bucket;

-- ============================================================
-- View: v_airline_kpi (Panel: airline performance comparison)
-- ============================================================
CREATE OR REPLACE VIEW `flight-delay-pipeline-494116.flight_delay_analytics.v_airline_kpi` AS
SELECT
  reporting_airline,
  COUNT(*)                                               AS flights,
  ROUND(AVG(arr_delay_minutes), 2)                       AS avg_arr_delay_min,
  ROUND(SAFE_DIVIDE(COUNTIF(arr_del15 = 0 AND cancelled = 0), COUNT(*)) * 100, 2)
                                                         AS on_time_pct,
  ROUND(SAFE_DIVIDE(COUNTIF(cancelled = 1), COUNT(*)) * 100, 2)
                                                         AS cancellation_pct,
  ROUND(SAFE_DIVIDE(COUNTIF(diverted = 1), COUNT(*)) * 100, 2)
                                                         AS diversion_pct
FROM `flight-delay-pipeline-494116.flight_delay_analytics.flights_weather_enriched`
GROUP BY reporting_airline
ORDER BY flights DESC;
