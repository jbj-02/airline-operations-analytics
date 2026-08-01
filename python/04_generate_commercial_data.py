from __future__ import annotations

import os
from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_FOLDER = PROJECT_ROOT / "data" / "processed"
OUTPUT_FOLDER.mkdir(parents=True, exist_ok=True)

OUTPUT_FILE = OUTPUT_FOLDER / "flight_fare_sales.csv"

DATABASE_NAME = "airline_analytics"
DATABASE_USER = "postgres"
DATABASE_HOST = "localhost"
DATABASE_PORT = "5432"

# For security, set this as an environment variable before running:
# Windows PowerShell:
# $env:POSTGRES_PASSWORD="your_password"
DATABASE_PASSWORD = os.getenv("POSTGRES_PASSWORD")

if not DATABASE_PASSWORD:
    raise RuntimeError(
        "POSTGRES_PASSWORD environment variable is not set."
    )

DATABASE_URL = (
    f"postgresql+psycopg2://{DATABASE_USER}:"
    f"{DATABASE_PASSWORD}@{DATABASE_HOST}:"
    f"{DATABASE_PORT}/{DATABASE_NAME}"
)

RANDOM_SEED = 42
rng = np.random.default_rng(RANDOM_SEED)


def assign_aircraft_capacity(distance: pd.Series) -> np.ndarray:
    """
    Assign realistic capacity ranges based partly on route distance.

    This is synthetic commercial data and does not represent actual
    aircraft assignments.
    """
    conditions = [
        distance < 600,
        distance < 1500,
        distance >= 1500,
    ]

    choices = [
        rng.integers(76, 151, size=len(distance)),
        rng.integers(140, 201, size=len(distance)),
        rng.integers(180, 291, size=len(distance)),
    ]

    return np.select(conditions, choices).astype(int)


def create_sales_records(flights: pd.DataFrame) -> pd.DataFrame:
    """Create three aggregated fare-class records per flight."""

    flights = flights.copy()

    flights["seat_capacity"] = assign_aircraft_capacity(
        flights["distance"]
    )

    month = pd.to_datetime(flights["flight_date"]).dt.month
    day_of_week = pd.to_datetime(
        flights["flight_date"]
    ).dt.dayofweek

    peak_month = month.isin([3, 6, 7, 8, 11, 12]).astype(float)
    weekend = day_of_week.isin([4, 5, 6]).astype(float)

    base_load_factor = (
        0.76
        + 0.06 * peak_month
        + 0.03 * weekend
        + rng.normal(0, 0.07, len(flights))
    )

    flights["load_factor"] = np.clip(
        base_load_factor,
        0.48,
        0.98,
    )

    flights["passengers"] = np.floor(
        flights["seat_capacity"] * flights["load_factor"]
    ).astype(int)

    records = []

    fare_classes = {
        "Economy": {
            "seat_share": 0.82,
            "fare_multiplier": 1.00,
        },
        "Premium Economy": {
            "seat_share": 0.12,
            "fare_multiplier": 1.65,
        },
        "Business": {
            "seat_share": 0.06,
            "fare_multiplier": 2.90,
        },
    }

    base_fare = (
        165
        + flights["distance"] * 0.055
        + rng.normal(0, 18, len(flights))
    )

    base_fare = np.maximum(base_fare, 120)

    for fare_class, parameters in fare_classes.items():
        passenger_count = np.floor(
            flights["passengers"]
            * parameters["seat_share"]
        ).astype(int)

        average_fare = (
            base_fare
            * parameters["fare_multiplier"]
            * rng.uniform(0.90, 1.12, len(flights))
        )

        revenue = passenger_count * average_fare

        class_records = pd.DataFrame(
            {
                "flight_id": flights["flight_id"].astype("int64"),
                "fare_class": fare_class,
                "seat_capacity": flights["seat_capacity"],
                "passengers": passenger_count,
                "average_fare": average_fare.round(2),
                "ticket_revenue": revenue.round(2),
            }
        )

        records.append(class_records)

    sales = pd.concat(records, ignore_index=True)

    # Correct rounding differences so class passengers equal total passengers.
    passenger_totals = (
        sales.groupby("flight_id")["passengers"]
        .sum()
        .rename("allocated_passengers")
    )

    expected = flights.set_index("flight_id")["passengers"]

    difference = expected - passenger_totals

    economy_mask = sales["fare_class"].eq("Economy")

    sales.loc[economy_mask, "passengers"] += (
        sales.loc[economy_mask, "flight_id"]
        .map(difference)
        .fillna(0)
        .astype(int)
        .values
    )
    # Minimum fare floors prevent unrealistically low short-haul fares.
    # These values are synthetic and intended to create more balanced
    # route economics across different flight distances.

    fare_floors = {
        "Economy": 110.00,
        "Premium Economy": 180.00,
        "Business": 320.00,
    }

    sales["average_fare"] = np.maximum(
        sales["average_fare"],
        sales["fare_class"].map(fare_floors),
    )

    sales["average_fare"] = sales["average_fare"].round(2)

    # Recalculate revenue after applying the fare floors.
    sales["ticket_revenue"] = (
        sales["passengers"] * sales["average_fare"]
    ).round(2)

    return sales


def main() -> None:
    engine = create_engine(DATABASE_URL)

    query = text(
        """
        SELECT
            flight_id,
            flight_date,
            carrier_code,
            route,
            distance
        FROM commercial_flights
        ORDER BY flight_id;
        """
    )

    print("Reading commercial flights from PostgreSQL...")

    with engine.connect() as connection:
        flights = pd.read_sql(query, connection)

    print(f"Flights loaded: {len(flights):,}")

    sales = create_sales_records(flights)

    sales.to_csv(OUTPUT_FILE, index=False)

    print("\nCommercial data generation complete.")
    print(f"Sales records written: {len(sales):,}")
    print(f"Unique flights: {sales['flight_id'].nunique():,}")
    print(f"Output file: {OUTPUT_FILE}")

    print("\nSummary:")
    print(
        sales.groupby("fare_class")
        .agg(
            passengers=("passengers", "sum"),
            revenue=("ticket_revenue", "sum"),
            average_fare=("average_fare", "mean"),
        )
        .round(2)
    )


if __name__ == "__main__":
    main()