from pathlib import Path
from zipfile import BadZipFile, ZipFile

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ZIP_FOLDER = PROJECT_ROOT / "data" / "raw" / "monthly_zips"


def inspect_zip_files(zip_folder: Path) -> None:
    """Inspect CSV files contained in monthly ZIP archives."""

    if not zip_folder.exists():
        raise FileNotFoundError(
            f"Folder not found: {zip_folder}\n"
            "Create the folder and place the monthly ZIP files inside it."
        )

    zip_paths = sorted(zip_folder.glob("*.zip"))

    if not zip_paths:
        raise FileNotFoundError(
            f"No ZIP files were found in: {zip_folder}"
        )

    print(f"Found {len(zip_paths)} ZIP files.\n")

    column_sets: dict[str, tuple[str, ...]] = {}

    for zip_path in zip_paths:
        print("=" * 80)
        print(f"ZIP: {zip_path.name}")

        try:
            with ZipFile(zip_path, "r") as archive:
                csv_files = [
                    name
                    for name in archive.namelist()
                    if name.lower().endswith(".csv")
                ]

                if not csv_files:
                    print("  No CSV files found.")
                    continue

                for csv_name in csv_files:
                    print(f"  CSV: {csv_name}")

                    with archive.open(csv_name) as csv_file:
                        sample = pd.read_csv(
                            csv_file,
                            nrows=5,
                            low_memory=False,
                        )

                    columns = tuple(sample.columns)
                    column_sets[f"{zip_path.name}::{csv_name}"] = columns

                    print(f"  Column count: {len(columns)}")
                    print("  Columns:")
                    for column in columns:
                        print(f"    - {column}")

                    print("\n  Sample:")
                    print(sample.head().to_string(index=False))

        except BadZipFile:
            print("  ERROR: This is not a valid ZIP file.")
        except Exception as exc:
            print(f"  ERROR: {exc}")

    print("\n" + "=" * 80)
    print("SCHEMA COMPARISON")

    if not column_sets:
        print("No readable CSV schemas were found.")
        return

    first_name, first_columns = next(iter(column_sets.items()))
    mismatches = []

    for file_name, columns in column_sets.items():
        if columns != first_columns:
            mismatches.append(file_name)

    if not mismatches:
        print(
            f"All {len(column_sets)} CSV files use the same "
            f"{len(first_columns)} columns."
        )
    else:
        print(f"Reference file: {first_name}")
        print("The following files have different columns:")
        for mismatch in mismatches:
            print(f"  - {mismatch}")


if __name__ == "__main__":
    inspect_zip_files(ZIP_FOLDER)