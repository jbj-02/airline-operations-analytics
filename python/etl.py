"""
etl.py

Orchestrates the "real data" side of the pipeline:
  1. Load airport reference data (airportsdata package) into `airports`.
  2. Load/derive aircraft reference data into `aircraft`.
  3. Loop over the monthly BTS CSVs in data/raw/ and load them into
     `flights` via the staging table pattern in sql/import_data.sql.

Run this BEFORE generate_customers.py / generate_bookings.py, since
bookings depend on flights + aircraft already existing.

Usage:
    python etl.py --db-url postgresql://user:pass@localhost/airline_db --raw-dir ../data/raw
"""

import argparse
import glob
import os
import random

import pandas as pd
import psycopg2
from psycopg2.extras import execute_values

random.seed(42)

# ------------------------------------------------------------
# Aircraft capacity heuristic
# ------------------------------------------------------------
# BTS doesn't publish seat capacity. Since we don't have a licensed
# fleet database, we assign a plausible capacity bucketed by the
# flight's typical distance profile for that tail number — short-haul
# tail numbers skew toward smaller regional jets, long-haul toward
# widebody/larger narrowbody aircraft. This keeps "aircraft utilization"
# and "operating cost per seat" questions meaningful without pretending
# we know the exact real-world fleet assignment.
def capacity_for_avg_distance(avg_distance: float) -> int:
    if avg_distance < 500:
        return random.choice([50, 70, 76])          # regional jet
    elif avg_distance < 1500:
        return random.choice([140, 150, 160, 176])   # narrowbody (737/A320 family)
    else:
        return random.choice([180, 220, 250])        # larger narrowbody / widebody


def load_airports(conn):
    try:
        import airportsdata
    except ImportError:
        raise RuntimeError("pip install airportsdata first — see requirements.txt")

    airports = airportsdata.load("IATA")
    rows = []
    for code, info in airports.items():
        if info.get("country") != "US":
            continue
        rows.append((
            code, info.get("name"), info.get("city"),
            info.get("subd"), info.get("lat"), info.get("lon"),
        ))

    cur = conn.cursor()
    execute_values(
        cur,
        """
        INSERT INTO airports (airport_code, airport_name, city, state, latitude, longitude)
        VALUES %s
        ON CONFLICT (airport_code) DO NOTHING
        """,
        rows,
    )
    conn.commit()
    cur.close()
    print(f"Loaded {len(rows)} US airports.")


def load_aircraft(conn):
    """
    Derives one row per distinct tail_number seen in the flights table,
    with a heuristic seat_capacity based on that tail number's average
    flight distance. Run this AFTER flights are loaded.
    """
    cur = conn.cursor()
    cur.execute("""
        SELECT tail_number, AVG(distance) as avg_dist
        FROM flights
        WHERE tail_number IS NOT NULL
        GROUP BY tail_number
    """)
    rows = cur.fetchall()

    aircraft_rows = []
    for tail_number, avg_dist in rows:
        capacity = capacity_for_avg_distance(float(avg_dist or 0))
        aircraft_rows.append((tail_number, None, None, capacity, None))

    execute_values(
        cur,
        """
        INSERT INTO aircraft (tail_number, manufacturer, model, seat_capacity, year_manufactured)
        VALUES %s
        ON CONFLICT (tail_number) DO NOTHING
        """,
        aircraft_rows,
    )
    conn.commit()
    cur.close()
    print(f"Loaded {len(aircraft_rows)} aircraft (capacity-only, heuristic).")


def load_monthly_flight_files(conn, raw_dir: str):
    """
    Expects one CSV per month in raw_dir, with BTS's standard column
    names (case-insensitive). Adjust the column mapping here if your
    downloaded field selection differs from sql/import_data.sql.
    """
    cur = conn.cursor()
    files = sorted(glob.glob(os.path.join(raw_dir, "*.csv")))
    if not files:
        print(f"No CSV files found in {raw_dir} — download the BTS monthly files first.")
        return

    total_rows = 0
    for filepath in files:
        df = pd.read_csv(filepath, low_memory=False)
        df.columns = [c.strip().lower() for c in df.columns]

        # Normalize the columns we need — adjust names here if BTS's
        # export differs from what you selected in the download UI.
        col_map = {
            "flightdate": "flight_date",
            "reporting_airline": "reporting_airline",
            "tail_number": "tail_number",
            "flight_number_reporting_airline": "flight_number",
            "origin": "origin",
            "dest": "dest",
            "crsdeptime": "crs_dep_time",
            "deptime": "dep_time",
            "depdelayminutes": "dep_delay_minutes",
            "crsarrtime": "crs_arr_time",
            "arrtime": "arr_time",
            "arrdelayminutes": "arr_delay_minutes",
            "cancelled": "cancelled",
            "cancellationcode": "cancellation_code",
            "diverted": "diverted",
            "distance": "distance",
            "airtime": "air_time",
            "crselapsedtime": "crs_elapsed_time",
            "actualelapsedtime": "actual_elapsed_time",
        }
        available = {k: v for k, v in col_map.items() if k in df.columns}
        df = df[list(available.keys())].rename(columns=available)

        df["cancelled"] = df["cancelled"].fillna(0).astype(float) == 1
        df["diverted"] = df["diverted"].fillna(0).astype(float) == 1

        records = list(df.itertuples(index=False, name=None))
        columns = list(df.columns)

        insert_sql = f"""
            INSERT INTO flights ({", ".join(columns)})
            VALUES %s
        """
        execute_values(cur, insert_sql, records, page_size=2000)
        conn.commit()
        total_rows += len(records)
        print(f"Loaded {len(records)} rows from {os.path.basename(filepath)}")

    cur.close()
    print(f"Total flight rows loaded: {total_rows}")


def main():
    parser = argparse.ArgumentParser(description="ETL: load real BTS data + reference tables.")
    parser.add_argument("--db-url", required=True)
    parser.add_argument("--raw-dir", default="../data/raw")
    parser.add_argument("--skip-airports", action="store_true")
    parser.add_argument("--skip-flights", action="store_true")
    parser.add_argument("--skip-aircraft", action="store_true")
    args = parser.parse_args()

    conn = psycopg2.connect(args.db_url)
    try:
        if not args.skip_airports:
            load_airports(conn)
        if not args.skip_flights:
            load_monthly_flight_files(conn, args.raw_dir)
        if not args.skip_aircraft:
            load_aircraft(conn)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
