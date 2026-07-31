from pathlib import Path
from zipfile import ZipFile

import pandas as pd

PROJECT_ROOT = Path(__file__).resolve().parents[1]

INPUT_FOLDER = (
    PROJECT_ROOT
    / "data"
    / "raw"
    / "monthly_zips"
)

OUTPUT_FOLDER = (
    PROJECT_ROOT
    / "data"
    / "processed"
)

OUTPUT_FOLDER.mkdir(parents=True, exist_ok=True)

frames = []

zip_files = sorted(INPUT_FOLDER.glob("*.zip"))

for zip_file in zip_files:
    print(f"Processing {zip_file.name}")

    with ZipFile(zip_file) as archive:
        csv_name = [
            name for name in archive.namelist()
            if name.endswith(".csv")
        ][0]

        with archive.open(csv_name) as csv_file:
            df = pd.read_csv(
                csv_file,
                low_memory=False
            )

        frames.append(df)

combined = pd.concat(
    frames,
    ignore_index=True
)

print("\nRows:", len(combined))
print("Columns:", len(combined.columns))

output_path = (
    OUTPUT_FOLDER
    / "all_flights_2024.csv"
)

combined.to_csv(
    output_path,
    index=False
)

print(f"\nSaved to:\n{output_path}")