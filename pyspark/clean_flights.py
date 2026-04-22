"""
clean_flights.py
----------------
Read raw BTS On-Time Performance monthly zip files from GCS, parse the CSV
inside each zip, project to the columns we need, coerce types, and write
partitioned Parquet to the processed bucket.

Input : gs://<raw>/flights/year=YYYY/month=M/*.zip  (one CSV per zip)
Output: gs://<processed>/flights_clean/year=YYYY/month=M/part-*.parquet
"""

import argparse
import io
import zipfile

from pyspark.sql import SparkSession, Row
from pyspark.sql import functions as F
from pyspark.sql import types as T


# Columns we keep from the 100+-column BTS schema.
KEEP_COLS = [
    "FlightDate",
    "Reporting_Airline",
    "Tail_Number",
    "Flight_Number_Reporting_Airline",
    "Origin",
    "OriginState",
    "Dest",
    "DestState",
    "CRSDepTime",
    "DepTime",
    "DepDelay",
    "DepDelayMinutes",
    "DepDel15",
    "TaxiOut",
    "TaxiIn",
    "CRSArrTime",
    "ArrTime",
    "ArrDelay",
    "ArrDelayMinutes",
    "ArrDel15",
    "Cancelled",
    "CancellationCode",
    "Diverted",
    "ActualElapsedTime",
    "AirTime",
    "Distance",
    "CarrierDelay",
    "WeatherDelay",
    "NASDelay",
    "SecurityDelay",
    "LateAircraftDelay",
]


def extract_csv_rows(kv):
    """Yield dicts (one per CSV row) for each .zip file."""
    path, content = kv
    try:
        with zipfile.ZipFile(io.BytesIO(content)) as zf:
            for name in zf.namelist():
                if not name.lower().endswith(".csv"):
                    continue
                with zf.open(name) as f:
                    import csv
                    text_stream = io.TextIOWrapper(f, encoding="utf-8", errors="replace")
                    reader = csv.DictReader(text_stream)
                    for row in reader:
                        yield {k: row.get(k, "") for k in KEEP_COLS}
    except zipfile.BadZipFile:
        # Silently skip corrupted zips; surfaced in Dataproc job logs.
        return


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    parser.add_argument("--raw-bucket", required=True)
    parser.add_argument("--processed-bucket", required=True)
    parser.add_argument("--staging-bucket", required=False)
    args, _ = parser.parse_known_args()

    spark = (
        SparkSession.builder
        .appName("clean_flights")
        .getOrCreate()
    )
    sc = spark.sparkContext

    raw_pattern = f"gs://{args.raw_bucket}/flights/year=*/month=*/*.zip"
    print(f"Reading: {raw_pattern}")

    rdd = sc.binaryFiles(raw_pattern).flatMap(extract_csv_rows)

    # String schema; cast below.
    schema = T.StructType([T.StructField(c, T.StringType(), True) for c in KEEP_COLS])

    df_raw = spark.createDataFrame(rdd.map(lambda d: Row(**d)), schema=schema)

    # --- Type casting + derived columns ---
    num_int = [
        "Flight_Number_Reporting_Airline",
        "CRSDepTime", "DepTime", "DepDelay", "DepDelayMinutes", "DepDel15",
        "TaxiOut", "TaxiIn",
        "CRSArrTime", "ArrTime", "ArrDelay", "ArrDelayMinutes", "ArrDel15",
        "Cancelled", "Diverted",
        "ActualElapsedTime", "AirTime", "Distance",
        "CarrierDelay", "WeatherDelay", "NASDelay",
        "SecurityDelay", "LateAircraftDelay",
    ]

    df = df_raw
    for c in num_int:
        df = df.withColumn(c, F.col(c).cast("double").cast("int"))

    df = (
        df
        .withColumn("FlightDate", F.to_date("FlightDate", "yyyy-MM-dd"))
        .withColumn("year", F.year("FlightDate"))
        .withColumn("month", F.month("FlightDate"))
        .withColumn("day_of_week", F.dayofweek("FlightDate"))
        .withColumn("dep_hour",
                    F.when(F.col("CRSDepTime").isNotNull(),
                           (F.col("CRSDepTime") / 100).cast("int"))
                     .otherwise(F.lit(None)))
        .withColumn("is_delayed_15",
                    F.when(F.col("Cancelled") == 1, F.lit(1))
                     .when(F.col("ArrDel15").isNotNull(), F.col("ArrDel15"))
                     .otherwise(F.lit(0)))
    )

    # Drop rows with no flight date (parse failures).
    df = df.filter(F.col("FlightDate").isNotNull())

    # Rename to snake_case for downstream hygiene.
    rename = {
        "FlightDate": "flight_date",
        "Reporting_Airline": "reporting_airline",
        "Tail_Number": "tail_number",
        "Flight_Number_Reporting_Airline": "flight_number",
        "Origin": "origin",
        "OriginState": "origin_state",
        "Dest": "dest",
        "DestState": "dest_state",
        "CRSDepTime": "crs_dep_time",
        "DepTime": "dep_time",
        "DepDelay": "dep_delay",
        "DepDelayMinutes": "dep_delay_minutes",
        "DepDel15": "dep_del15",
        "TaxiOut": "taxi_out",
        "TaxiIn": "taxi_in",
        "CRSArrTime": "crs_arr_time",
        "ArrTime": "arr_time",
        "ArrDelay": "arr_delay",
        "ArrDelayMinutes": "arr_delay_minutes",
        "ArrDel15": "arr_del15",
        "Cancelled": "cancelled",
        "CancellationCode": "cancellation_code",
        "Diverted": "diverted",
        "ActualElapsedTime": "actual_elapsed_time",
        "AirTime": "air_time",
        "Distance": "distance",
        "CarrierDelay": "carrier_delay",
        "WeatherDelay": "weather_delay",
        "NASDelay": "nas_delay",
        "SecurityDelay": "security_delay",
        "LateAircraftDelay": "late_aircraft_delay",
    }
    for old, new in rename.items():
        df = df.withColumnRenamed(old, new)

    out = f"gs://{args.processed_bucket}/flights_clean/"
    print(f"Writing: {out}")

    (df
        .repartition("year", "month")
        .write
        .mode("overwrite")
        .partitionBy("year", "month")
        .parquet(out))

    print("clean_flights: done")
    spark.stop()


if __name__ == "__main__":
    main()
