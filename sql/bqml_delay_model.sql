-- BigQuery ML: logistic regression to predict flight delay (arr_del15).
-- Train on 2019-2024, evaluate on 2025 holdout.

CREATE OR REPLACE MODEL `flight-delay-pipeline-494116.flight_delay_analytics.delay_clf`
OPTIONS(
  model_type = 'LOGISTIC_REG',
  input_label_cols = ['is_delayed_15'],
  auto_class_weights = TRUE,
  enable_global_explain = TRUE,
  data_split_method = 'NO_SPLIT'
) AS
SELECT
  is_delayed_15,
  reporting_airline,
  origin,
  dest,
  dep_hour,
  day_of_week,
  month,
  distance,
  origin_wdsp        AS wind_speed,
  origin_prcp        AS precipitation,
  origin_visib       AS visibility,
  origin_temp        AS temperature
FROM `flight-delay-pipeline-494116.flight_delay_analytics.flights_weather_enriched`
WHERE flight_date < DATE '2025-01-01'
  AND is_delayed_15 IS NOT NULL
  AND reporting_airline IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Evaluate on 2025 holdout
-- -----------------------------------------------------------------------------
SELECT *
FROM ML.EVALUATE(
  MODEL `flight-delay-pipeline-494116.flight_delay_analytics.delay_clf`,
  (
    SELECT
      is_delayed_15,
      reporting_airline, origin, dest, dep_hour, day_of_week, month, distance,
      origin_wdsp AS wind_speed,
      origin_prcp AS precipitation,
      origin_visib AS visibility,
      origin_temp AS temperature
    FROM `flight-delay-pipeline-494116.flight_delay_analytics.flights_weather_enriched`
    WHERE flight_date >= DATE '2025-01-01'
      AND is_delayed_15 IS NOT NULL
      AND reporting_airline IS NOT NULL
  )
);

-- -----------------------------------------------------------------------------
-- Confusion matrix at default 0.5 threshold
-- -----------------------------------------------------------------------------
SELECT *
FROM ML.CONFUSION_MATRIX(
  MODEL `flight-delay-pipeline-494116.flight_delay_analytics.delay_clf`,
  (
    SELECT
      is_delayed_15,
      reporting_airline, origin, dest, dep_hour, day_of_week, month, distance,
      origin_wdsp AS wind_speed,
      origin_prcp AS precipitation,
      origin_visib AS visibility,
      origin_temp AS temperature
    FROM `flight-delay-pipeline-494116.flight_delay_analytics.flights_weather_enriched`
    WHERE flight_date >= DATE '2025-01-01'
      AND is_delayed_15 IS NOT NULL
      AND reporting_airline IS NOT NULL
  )
);

-- -----------------------------------------------------------------------------
-- Global feature importance
-- -----------------------------------------------------------------------------
SELECT *
FROM ML.GLOBAL_EXPLAIN(
  MODEL `flight-delay-pipeline-494116.flight_delay_analytics.delay_clf`
)
ORDER BY attribution DESC;
