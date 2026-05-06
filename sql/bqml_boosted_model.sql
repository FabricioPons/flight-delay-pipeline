-- BigQuery ML: boosted-tree classifier (XGBoost) on the same features as
-- delay_clf so we can compare a nonlinear ensemble against the logistic
-- baseline. Train on 2019-2024, evaluate on 2025 holdout.
--
-- Run after sql/bqml_delay_model.sql (we reuse the same train/holdout split).

CREATE OR REPLACE MODEL `flight-delay-pipeline-494116.flight_delay_analytics.delay_clf_boosted`
OPTIONS(
  model_type           = 'BOOSTED_TREE_CLASSIFIER',
  input_label_cols     = ['is_delayed_15'],
  auto_class_weights   = TRUE,
  enable_global_explain= TRUE,
  num_parallel_tree    = 1,
  max_iterations       = 50,
  max_tree_depth       = 8,
  learn_rate           = 0.1,
  subsample            = 0.8,
  data_split_method    = 'NO_SPLIT'
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
