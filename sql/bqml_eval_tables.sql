-- Materialize BQML model outputs as persisted tables so Looker Studio can
-- chart them (Looker cannot call ML.EVALUATE directly).
--
-- Prereq: sql/bqml_delay_model.sql has already trained
-- `flight_delay_analytics.delay_clf`.

-- ----------------------------------------------------------------------------
-- Holdout evaluation metrics (one-row "KPI" table).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE `flight-delay-pipeline-494116.flight_delay_analytics.m_eval_metrics` AS
SELECT
  CURRENT_TIMESTAMP()        AS evaluated_at,
  "logistic_regression"      AS model_type,
  "2025-01-01 .. 2025-12-31" AS holdout_window,
  ROUND(precision, 4)        AS precision,
  ROUND(recall, 4)           AS recall,
  ROUND(accuracy, 4)         AS accuracy,
  ROUND(f1_score, 4)         AS f1,
  ROUND(log_loss, 4)         AS log_loss,
  ROUND(roc_auc, 4)          AS roc_auc
FROM ML.EVALUATE(
  MODEL `flight-delay-pipeline-494116.flight_delay_analytics.delay_clf`,
  (
    SELECT
      is_delayed_15,
      reporting_airline, origin, dest, dep_hour, day_of_week, month, distance,
      origin_wdsp  AS wind_speed,
      origin_prcp  AS precipitation,
      origin_visib AS visibility,
      origin_temp  AS temperature
    FROM `flight-delay-pipeline-494116.flight_delay_analytics.flights_weather_enriched`
    WHERE flight_date >= DATE '2025-01-01'
      AND is_delayed_15 IS NOT NULL
      AND reporting_airline IS NOT NULL
  )
);

-- ----------------------------------------------------------------------------
-- Confusion matrix at threshold 0.5 (2x2 grid, 4 rows for Looker-friendly
-- long format so it can be rendered as a pivot heatmap).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE `flight-delay-pipeline-494116.flight_delay_analytics.m_confusion_matrix` AS
WITH cm AS (
  SELECT * FROM ML.CONFUSION_MATRIX(
    MODEL `flight-delay-pipeline-494116.flight_delay_analytics.delay_clf`,
    (
      SELECT
        is_delayed_15,
        reporting_airline, origin, dest, dep_hour, day_of_week, month, distance,
        origin_wdsp  AS wind_speed,
        origin_prcp  AS precipitation,
        origin_visib AS visibility,
        origin_temp  AS temperature
      FROM `flight-delay-pipeline-494116.flight_delay_analytics.flights_weather_enriched`
      WHERE flight_date >= DATE '2025-01-01'
        AND is_delayed_15 IS NOT NULL
        AND reporting_airline IS NOT NULL
    )
  )
)
SELECT CAST(expected_label AS STRING) AS actual,
       "predicted_on_time"              AS predicted,
       _0                               AS flights
FROM cm
UNION ALL
SELECT CAST(expected_label AS STRING) AS actual,
       "predicted_delayed"              AS predicted,
       _1                               AS flights
FROM cm;

-- ----------------------------------------------------------------------------
-- Feature importance (global explain).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE `flight-delay-pipeline-494116.flight_delay_analytics.m_feature_importance` AS
SELECT
  feature,
  ROUND(attribution, 5) AS attribution
FROM ML.GLOBAL_EXPLAIN(
  MODEL `flight-delay-pipeline-494116.flight_delay_analytics.delay_clf`
)
ORDER BY attribution DESC;
