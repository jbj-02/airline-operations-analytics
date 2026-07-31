from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]

INPUT_FILE = (
    PROJECT_ROOT
    / "data"
    / "processed"
    / "all_flights_2024.csv"
)

OUTPUT_FILE = (
    PROJECT_ROOT
    / "data"
    / "processed"
    / "flights_clean.csv"
)


COLUMN_RENAMES = {
    "FL_DATE": "flight_date",
    "OP_UNIQUE_CARRIER": "carrier_code",
    "TAIL_NUM": "tail_number",
    "OP_CARRIER_FL_NUM": "flight_number",
    "ORIGIN_AIRPORT_ID": "origin_airport_id",
    "ORIGIN": "origin_airport",
    "DEST_AIRPORT_ID": "destination_airport_id",
    "DEST": "destination_airport",
    "CRS_DEP_TIME": "scheduled_departure_time",
    "DEP_TIME": "actual_departure_time",
    "DEP_DELAY": "departure_delay",
    "DEP_DELAY_NEW": "departure_delay_nonnegative",
    "CRS_ARR_TIME": "scheduled_arrival_time",
    "ARR_TIME": "actual_arrival_time",
    "ARR_DELAY": "arrival_delay",
    "ARR_DELAY_NEW": "arrival_delay_nonnegative",
    "CANCELLED": "cancelled",
    "CANCELLATION_CODE": "cancellation_code",
    "DIVERTED": "diverted",
    "CRS_ELAPSED_TIME": "scheduled_elapsed_time",
    "ACTUAL_ELAPSED_TIME": "actual_elapsed_time",
    "AIR_TIME": "air_time",
    "DISTANCE": "distance",
}


def clean_chunk(chunk: pd.DataFrame) -> pd.DataFrame:
    """Clean and standardize one chunk of flight records."""

    chunk = chunk.rename(columns=COLUMN_RENAMES)

    chunk["flight_date"] = pd.to_datetime(
        chunk["flight_date"],
        errors="coerce",
    ).dt.date

    text_columns = [
        "carrier_code",
        "tail_number",
        "origin_airport",
        "destination_airport",
        "cancellation_code",
    ]

    for column in text_columns:
        chunk[column] = (
            chunk[column]
            .astype("string")
            .str.strip()
            .replace({"": pd.NA})
        )

    integer_columns = [
        "flight_number",
        "origin_airport_id",
        "destination_airport_id",
        "scheduled_departure_time",
        "actual_departure_time",
        "scheduled_arrival_time",
        "actual_arrival_time",
    ]

    for column in integer_columns:
        chunk[column] = pd.to_numeric(
            chunk[column],
            errors="coerce",
        ).astype("Int64")

    numeric_columns = [
        "departure_delay",
        "departure_delay_nonnegative",
        "arrival_delay",
        "arrival_delay_nonnegative",
        "scheduled_elapsed_time",
        "actual_elapsed_time",
        "air_time",
        "distance",
    ]

    for column in numeric_columns:
        chunk[column] = pd.to_numeric(
            chunk[column],
            errors="coerce",
        )

    chunk["cancelled"] = (
        pd.to_numeric(chunk["cancelled"], errors="coerce")
        .fillna(0)
        .astype(int)
        .astype(bool)
    )

    chunk["diverted"] = (
        pd.to_numeric(chunk["diverted"], errors="coerce")
        .fillna(0)
        .astype(int)
        .astype(bool)
    )

    chunk["route"] = (
        chunk["origin_airport"]
        + "-"
        + chunk["destination_airport"]
    )

    chunk["departure_hour"] = (
        chunk["scheduled_departure_time"] // 100
    ).astype("Int64")

    chunk["is_arrival_delayed_15"] = (
        chunk["arrival_delay"] >= 15
    )

    chunk["is_departure_delayed_15"] = (
        chunk["departure_delay"] >= 15
    )

    return chunk


def main() -> None:
    if not INPUT_FILE.exists():
        raise FileNotFoundError(
            f"Input file not found: {INPUT_FILE}"
        )

    if OUTPUT_FILE.exists():
        OUTPUT_FILE.unlink()

    chunk_size = 250_000
    total_rows = 0
    first_chunk = True

    for chunk_number, chunk in enumerate(
        pd.read_csv(
            INPUT_FILE,
            chunksize=chunk_size,
            low_memory=False,
        ),
        start=1,
    ):
        cleaned = clean_chunk(chunk)

        cleaned.to_csv(
            OUTPUT_FILE,
            mode="w" if first_chunk else "a",
            header=first_chunk,
            index=False,
        )

        first_chunk = False
        total_rows += len(cleaned)

        print(
            f"Processed chunk {chunk_number}: "
            f"{total_rows:,} total rows"
        )

    print("\nCleaning complete.")
    print(f"Rows written: {total_rows:,}")
    print(f"Output file: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()