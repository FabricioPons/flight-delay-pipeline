"""
airport_station_map.py
----------------------
Build an IATA (airport) -> NOAA weather station mapping by taking, for each
U.S. airport, the nearest NOAA GSOD station within 50 km (haversine).

Sources (BigQuery public):
  - `bigquery-public-data.faa.us_airports`         (IATA + lat/lon)
  - `bigquery-public-data.noaa_gsod.stations`      (station id + lat/lon)

Output: gs://<processed>/lookups/airport_station/*.parquet
"""

import argparse

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window


AIRPORTS_TABLE = "bigquery-public-data.faa.us_airports"
STATIONS_TABLE = "bigquery-public-data.noaa_gsod.stations"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    parser.add_argument("--raw-bucket", required=False)
    parser.add_argument("--processed-bucket", required=True)
    parser.add_argument("--staging-bucket", required=True)
    args, _ = parser.parse_known_args()

    spark = (
        SparkSession.builder
        .appName("airport_station_map")
        .config("temporaryGcsBucket", args.staging_bucket)
        .getOrCreate()
    )

    # bigquery-public-data.faa.us_airports uses faa_identifier, which equals
    # the IATA code for virtually all US commercial airports (LAX, JFK, ORD, ...).
    airports = (
        spark.read.format("bigquery")
        .option("table", AIRPORTS_TABLE)
        .load()
        .select(
            F.col("faa_identifier").alias("iata"),
            F.col("latitude").cast("double").alias("ap_lat"),
            F.col("longitude").cast("double").alias("ap_lon"),
        )
        .filter(F.col("iata").isNotNull())
        .filter(F.col("ap_lat").isNotNull() & F.col("ap_lon").isNotNull())
    )

    # USAF='999999' is a "no code" placeholder; those rows in GSOD are rare and
    # many major airports have a duplicate row in the stations table — one with
    # a real USAF and one with 999999. Only the real-USAF version actually joins
    # against GSOD's stn column. Filter placeholders out before matching.
    stations = (
        spark.read.format("bigquery")
        .option("table", STATIONS_TABLE)
        .load()
        .select(
            F.col("usaf"),
            F.col("wban"),
            F.concat_ws("-", F.col("usaf"), F.col("wban")).alias("station_id"),
            F.col("lat").cast("double").alias("st_lat"),
            F.col("lon").cast("double").alias("st_lon"),
            F.col("country"),
        )
        .filter(F.col("country") == "US")
        .filter(F.col("usaf") != "999999")
        .filter(F.col("wban") != "99999")
        .filter(F.col("st_lat").isNotNull() & F.col("st_lon").isNotNull())
    )

    # Haversine distance (km). We cross-join after pre-filtering by a lat/lon box
    # (~1 degree ~ 111 km) to keep the cross-product tractable.
    joined = (
        airports.alias("a")
        .join(
            stations.alias("s"),
            (F.abs(F.col("a.ap_lat") - F.col("s.st_lat")) < 0.75) &
            (F.abs(F.col("a.ap_lon") - F.col("s.st_lon")) < 0.75),
            "inner",
        )
    )

    R = 6371.0  # Earth radius, km.
    dist = (
        2 * R * F.asin(F.sqrt(
            F.pow(F.sin((F.radians("s.st_lat") - F.radians("a.ap_lat")) / 2), 2) +
            F.cos(F.radians("a.ap_lat")) * F.cos(F.radians("s.st_lat")) *
            F.pow(F.sin((F.radians("s.st_lon") - F.radians("a.ap_lon")) / 2), 2)
        ))
    )
    joined = joined.withColumn("distance_km", dist).filter(F.col("distance_km") < 50)

    # Pick nearest station per airport.
    w = Window.partitionBy("iata").orderBy(F.col("distance_km").asc())
    mapping = (
        joined
        .withColumn("rn", F.row_number().over(w))
        .filter(F.col("rn") == 1)
        .select("iata", "station_id", "distance_km")
    )

    out = f"gs://{args.processed_bucket}/lookups/airport_station/"
    print(f"Writing: {out}")
    mapping.write.mode("overwrite").parquet(out)

    print(f"airport_station_map: {mapping.count()} airport-station pairs written")
    spark.stop()


if __name__ == "__main__":
    main()
