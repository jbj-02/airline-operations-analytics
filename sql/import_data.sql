-- ============================================================
-- Import raw BTS data into the flights table
-- ============================================================
-- BTS CSVs come one-per-month with a header row and a LOT of
-- columns you don't need. The cleanest approach:
--   1. Load each month's raw CSV into a staging table that
--      mirrors the BTS column names exactly.
--   2. INSERT ... SELECT from staging into the real `flights`
--      table, casting/renaming as needed.
--   3. Drop/truncate staging once done.
--
-- Repeat the COPY step for each of the 12 monthly files in
-- data/raw/, or loop it in etl.py instead (recommended once
-- you have more than 2-3 months to load).
-- ============================================================

DROP TABLE IF EXISTS staging_flights;

CREATE TABLE staging_flights (
    flightdate              DATE,
    reporting_airline       VARCHAR(5),
    tail_number             VARCHAR(10),
    flight_number_reporting_airline VARCHAR(10),
    origin                  CHAR(3),
    dest                    CHAR(3),
    crsdeptime              SMALLINT,
    deptime                 SMALLINT,
    depdelayminutes         NUMERIC(6,1),
    crsarrtime              SMALLINT,
    arrtime                 SMALLINT,
    arrdelayminutes         NUMERIC(6,1),
    cancelled               NUMERIC(2,1),   -- BTS encodes this as 0.00/1.00
    cancellationcode        CHAR(1),
    diverted                NUMERIC(2,1),
    distance                NUMERIC(8,1),
    airtime                 NUMERIC(6,1),
    crselapsedtime          NUMERIC(6,1),
    actualelapsedtime       NUMERIC(6,1)
);

-- Example load — repeat per monthly CSV, updating the path:
-- \copy staging_flights FROM 'data/raw/2024_01.csv' WITH (FORMAT csv, HEADER true)

INSERT INTO flights (
    flight_date, reporting_airline, flight_number, tail_number,
    origin, dest, crs_dep_time, dep_time, dep_delay_minutes,
    crs_arr_time, arr_time, arr_delay_minutes,
    cancelled, cancellation_code, diverted,
    distance, air_time, crs_elapsed_time, actual_elapsed_time
)
SELECT
    flightdate, reporting_airline, flight_number_reporting_airline, tail_number,
    origin, dest, crsdeptime, deptime, depdelayminutes,
    crsarrtime, arrtime, arrdelayminutes,
    (cancelled = 1)::boolean, cancellationcode, (diverted = 1)::boolean,
    distance, airtime, crselapsedtime, actualelapsedtime
FROM staging_flights;

-- Clear staging before loading the next month's file
TRUNCATE staging_flights;
