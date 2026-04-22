"""
join_flights_weather.py
-----------------------
Join cleaned flights with NOAA GSOD daily weather for both origin and
destination airports, via the IATA->station lookup table built by
airport_station_map.py. Writes the enriched analytical table to BigQuery.

Output:
  BigQuery: <project>.flight_delay_analytics.flights_weather_enriched
"""

import argparse

from pyspark.sql import SparkSession
from pyspark.sql import functions as F


def load_gsod(spark, start_year: int, end_year: int):
    """Union GSOD yearly tables into one DataFrame with a date column."""
    dfs = []
    for y in range(start_year, end_year + 1):
        table = f"bigquery-public-data.noaa_gsod.gsod{y}"
        df = (
            spark.read.format("bigquery")
            .option("table", table)
            .load()
            .filter(F.col("wban") != "99999")
            .select(
                F.col("wban").alias("station_id"),
                # BQ column "date" is fine in SQL but trips Spark's column resolver;
                # reassemble from year/mo/da instead.
                F.to_date(F.concat_ws("-", F.col("year"), F.col("mo"), F.col("da")),
                          "yyyy-MM-dd").alias("weather_date"),
                F.col("temp").cast("double"),
                F.col("dewp").cast("double"),
                F.col("slp").cast("double"),
                F.col("visib").cast("double"),
                F.col("wdsp").cast("double"),
                F.col("mxpsd").cast("double"),
                F.col("gust").cast("double"),
                F.col("max").cast("double").alias("temp_max"),
                F.col("min").cast("double").alias("temp_min"),
                F.col("prcp").cast("double"),
                F.col("sndp").cast("double"),
                F.col("fog"),
                F.col("rain_drizzle").alias("rain"),
                F.col("snow_ice_pellets").alias("snow"),
                F.col("hail"),
                F.col("thunder"),
                F.col("tornado_funnel_cloud").alias("tornado"),
            )
        )
        dfs.append(df)

    out = dfs[0]
    for d in dfs[1:]:
        out = out.unionByName(d)
    # Same WBAN may appear under different (stn) codes with identical readings;
    # collapse to one row per (station_id, weather_date) so the join doesn't
    # fan out.
    return out.dropDuplicates(["station_id", "weather_date"])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    parser.add_argument("--raw-bucket", required=False)
    parser.add_argument("--processed-bucket", required=True)
    parser.add_argument("--staging-bucket", required=True)
    parser.add_argument("--dataset", default="flight_delay_analytics")
    parser.add_argument("--start-year", type=int, default=2019)
    parser.add_argument("--end-year", type=int, default=2025)
    args, _ = parser.parse_known_args()

    spark = (
        SparkSession.builder
        .appName("join_flights_weather")
        .config("temporaryGcsBucket", args.staging_bucket)
        .getOrCreate()
    )

    flights = spark.read.parquet(f"gs://{args.processed_bucket}/flights_clean/")
    mapping = spark.read.parquet(f"gs://{args.processed_bucket}/lookups/airport_station/")

    # Attach origin and destination station ids.
    flights = (
        flights
        .join(mapping.select(F.col("iata").alias("origin"),
                             F.col("station_id").alias("origin_station")),
              on="origin", how="left")
        .join(mapping.select(F.col("iata").alias("dest"),
                             F.col("station_id").alias("dest_station")),
              on="dest", how="left")
    )

    weather = load_gsod(spark, args.start_year, args.end_year)

    origin_wx = weather.select(
        F.col("station_id").alias("origin_station"),
        F.col("weather_date").alias("flight_date"),
        *[F.col(c).alias(f"origin_{c}") for c in
          ["temp", "dewp", "visib", "wdsp", "mxpsd", "gust", "prcp",
           "fog", "rain", "snow", "thunder"]],
    )

    dest_wx = weather.select(
        F.col("station_id").alias("dest_station"),
        F.col("weather_date").alias("flight_date"),
        *[F.col(c).alias(f"dest_{c}") for c in
          ["temp", "dewp", "visib", "wdsp", "mxpsd", "gust", "prcp",
           "fog", "rain", "snow", "thunder"]],
    )

    enriched = (
        flights
        .join(origin_wx, on=["origin_station", "flight_date"], how="left")
        .join(dest_wx, on=["dest_station", "flight_date"], how="left")
    )

    target = f"{args.project}.{args.dataset}.flights_weather_enriched"
    print(f"Writing: {target}")

    (enriched.write
        .format("bigquery")
        .option("table", target)
        .option("partitionField", "flight_date")
        .option("partitionType", "DAY")
        .option("clusteredFields", "reporting_airline,origin,dest")
        .option("writeMethod", "indirect")
        .mode("overwrite")
        .save())

    print("join_flights_weather: done")
    spark.stop()


if __name__ == "__main__":
    main()
