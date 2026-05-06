-- Run after both delay_clf (logistic) and delay_clf_boosted (XGBoost) exist.
-- Materializes a side-by-side metrics table and refreshes the
-- m_eval_metrics / m_confusion_matrix / m_feature_importance tables so the
-- Looker dashboard shows both models.

-- ----------------------------------------------------------------------------
-- 1. Side-by-side metrics table.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE `flight-delay-pipeline-494116.flight_delay_analytics.m_model_comparison` AS
WITH logistic AS (
  SELECT
    "logistic_regression"   AS model_type,
    ROUND(precision, 4)     AS precision,
    ROUND(recall, 4)        AS recall,
    ROUND(accuracy, 4)      AS accuracy,
    ROUND(f1_score, 4)      AS f1,
    ROUND(log_loss, 4)      AS log_loss,
    ROUND(roc_auc, 4)       AS roc_auc
  FROM ML.EVALUATE(
    MODEL `flight-delay-pipeline-494116.flight_delay_analytics.delay_clf`,
    (
      SELECT is_delayed_15, reporting_airline, origin, dest, dep_hour,
             day_of_week, month, distance,
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
),
boosted AS (
  SELECT
    "boosted_tree"          AS model_type,
    ROUND(precision, 4)     AS precision,
    ROUND(recall, 4)        AS recall,
    ROUND(accuracy, 4)      AS accuracy,
    ROUND(f1_score, 4)      AS f1,
    ROUND(log_loss, 4)      AS log_loss,
    ROUND(roc_auc, 4)       AS roc_auc
  FROM ML.EVALUATE(
    MODEL `flight-delay-pipeline-494116.flight_delay_analytics.delay_clf_boosted`,
    (
      SELECT is_delayed_15, reporting_airline, origin, dest, dep_hour,
             day_of_week, month, distance,
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
SELECT * FROM logistic
UNION ALL
SELECT * FROM boosted;

-- ----------------------------------------------------------------------------
-- 2. Refresh m_eval_metrics so Looker scorecards average across both models.
--    For the comparison page we'll also expose the model_type dimension.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE `flight-delay-pipeline-494116.flight_delay_analytics.m_eval_metrics` AS
SELECT
  CURRENT_TIMESTAMP()        AS evaluated_at,
  model_type,
  "2025-01-01 .. 2025-12-31" AS holdout_window,
  precision, recall, accuracy, f1, log_loss, roc_auc
FROM `flight-delay-pipeline-494116.flight_delay_analytics.m_model_comparison`;

-- ----------------------------------------------------------------------------
-- 3. Confusion matrix for the boosted model (logistic one is already in
--    m_confusion_matrix; we add the boosted rows alongside it).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE `flight-delay-pipeline-494116.flight_delay_analytics.m_confusion_matrix` AS
WITH cm_log AS (
  SELECT
    "logistic_regression" AS model_type,
    expected_label, _0, _1
  FROM ML.CONFUSION_MATRIX(
    MODEL `flight-delay-pipeline-494116.flight_delay_analytics.delay_clf`,
    (
      SELECT is_delayed_15, reporting_airline, origin, dest, dep_hour,
             day_of_week, month, distance,
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
),
cm_boost AS (
  SELECT
    "boosted_tree" AS model_type,
    expected_label, _0, _1
  FROM ML.CONFUSION_MATRIX(
    MODEL `flight-delay-pipeline-494116.flight_delay_analytics.delay_clf_boosted`,
    (
      SELECT is_delayed_15, reporting_airline, origin, dest, dep_hour,
             day_of_week, month, distance,
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
),
both AS (
  SELECT * FROM cm_log
  UNION ALL
  SELECT * FROM cm_boost
)
SELECT model_type,
       CAST(expected_label AS STRING) AS actual,
       "predicted_on_time"            AS predicted,
       _0                             AS flights
FROM both
UNION ALL
SELECT model_type,
       CAST(expected_label AS STRING) AS actual,
       "predicted_delayed"            AS predicted,
       _1                             AS flights
FROM both;

-- ----------------------------------------------------------------------------
-- 4. Feature importance for both models so we can show two side-by-side
--    bar charts.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE `flight-delay-pipeline-494116.flight_delay_analytics.m_feature_importance` AS
SELECT
  "logistic_regression" AS model_type,
  feature,
  ROUND(attribution, 5) AS attribution
FROM ML.GLOBAL_EXPLAIN(
  MODEL `flight-delay-pipeline-494116.flight_delay_analytics.delay_clf`
)
UNION ALL
SELECT
  "boosted_tree" AS model_type,
  feature,
  ROUND(attribution, 5) AS attribution
FROM ML.GLOBAL_EXPLAIN(
  MODEL `flight-delay-pipeline-494116.flight_delay_analytics.delay_clf_boosted`
);
