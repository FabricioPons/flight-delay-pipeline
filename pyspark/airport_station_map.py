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

    # WBAN is a 5-digit US-specific station id and is stable across USAF-code
    # changes. The stations table has multiple rows per physical station (old
    # and new USAF codes), so we collapse by WBAN and pick any representative
    # lat/lon. Join back to GSOD is done on WBAN alone (US-only workload).
    stations = (
        spark.read.format("bigquery")
        .option("table", STATIONS_TABLE)
        .load()
        .filter(F.col("country") == "US")
        .filter(F.col("wban").isNotNull() & (F.col("wban") != "99999"))
        .filter(F.col("lat").isNotNull() & F.col("lon").isNotNull())
        .groupBy("wban")
        .agg(
            F.first("lat").cast("double").alias("st_lat"),
            F.first("lon").cast("double").alias("st_lon"),
        )
        .withColumnRenamed("wban", "station_id")
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
