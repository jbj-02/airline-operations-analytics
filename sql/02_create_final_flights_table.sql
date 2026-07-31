-- ============================================================
-- File: 02_create_final_flights_table.sql
-- Purpose:
-- Transform the imported staging data into the final flights
-- table used throughout the analytics project.
--
-- The final table adds:
--   - A generated flight_id
--   - Year and month fields
--   - Day-of-week fields
--   - A primary key
--   - Validation checks
-- ============================================================


-- ------------------------------------------------------------
-- 1. Remove the existing final table
-- ------------------------------------------------------------

DROP TABLE IF EXISTS flights;


-- ------------------------------------------------------------
-- 2. Create the final flights table
-- ------------------------------------------------------------

CREATE TABLE flights AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY
            flight_date,
            carrier_code,
            flight_number,
            origin_airport,
            destination_airport,
            scheduled_departure_time
    ) AS flight_id,

    flight_date,
    carrier_code,
    tail_number,
    flight_number,

    origin_airport_id,
    origin_airport,

    destination_airport_id,
    destination_airport,

    scheduled_departure_time,
    actual_departure_time,

    departure_delay,
    departure_delay_nonnegative,

    scheduled_arrival_time,
    actual_arrival_time,

    arrival_delay,
    arrival_delay_nonnegative,

    cancelled,
    cancellation_code,
    diverted,

    scheduled_elapsed_time,
    actual_elapsed_time,
    air_time,
    distance,

    route,
    departure_hour,

    is_arrival_delayed_15,
    is_departure_delayed_15,

    EXTRACT(YEAR FROM flight_date)::INTEGER
        AS flight_year,

    EXTRACT(MONTH FROM flight_date)::INTEGER
        AS flight_month,

    EXTRACT(DOW FROM flight_date)::INTEGER
        AS day_of_week_number,

    TRIM(TO_CHAR(flight_date, 'Day'))
        AS day_of_week_name

FROM flights_staging;


-- ------------------------------------------------------------
-- 3. Add the primary key
-- ------------------------------------------------------------

ALTER TABLE flights
ADD CONSTRAINT flights_primary_key
PRIMARY KEY (flight_id);


-- ------------------------------------------------------------
-- 4. Update PostgreSQL query-planning statistics
-- ------------------------------------------------------------

ANALYZE flights;


-- ------------------------------------------------------------
-- 5. Validate the final table
--
-- Expected total:
-- 7,106,619 rows
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_flights,
    COUNT(DISTINCT flight_id) AS distinct_flight_ids,
    MIN(flight_date) AS first_flight_date,
    MAX(flight_date) AS last_flight_date
FROM flights;


-- ------------------------------------------------------------
-- 6. Confirm that staging and final row counts match
-- ------------------------------------------------------------

SELECT
    (SELECT COUNT(*) FROM flights_staging)
        AS staging_rows,

    (SELECT COUNT(*) FROM flights)
        AS final_rows,

    (
        SELECT COUNT(*)
        FROM flights_staging
    )
    -
    (
        SELECT COUNT(*)
        FROM flights
    )
        AS row_count_difference;


-- ------------------------------------------------------------
-- 7. Check generated flight IDs
-- ------------------------------------------------------------

SELECT
    MIN(flight_id) AS minimum_flight_id,
    MAX(flight_id) AS maximum_flight_id,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT flight_id) AS distinct_flight_ids
FROM flights;


-- ------------------------------------------------------------
-- 8. Check important fields for null values
-- ------------------------------------------------------------

SELECT
    COUNT(*) FILTER (
        WHERE flight_id IS NULL
    ) AS missing_flight_ids,

    COUNT(*) FILTER (
        WHERE flight_date IS NULL
    ) AS missing_flight_dates,

    COUNT(*) FILTER (
        WHERE carrier_code IS NULL
    ) AS missing_carriers,

    COUNT(*) FILTER (
        WHERE origin_airport IS NULL
    ) AS missing_origins,

    COUNT(*) FILTER (
        WHERE destination_airport IS NULL
    ) AS missing_destinations,

    COUNT(*) FILTER (
        WHERE route IS NULL
    ) AS missing_routes

FROM flights;


-- ------------------------------------------------------------
-- 9. Validate derived calendar fields
-- ------------------------------------------------------------

SELECT
    COUNT(*) FILTER (
        WHERE flight_year
            <> EXTRACT(YEAR FROM flight_date)::INTEGER
    ) AS invalid_flight_years,

    COUNT(*) FILTER (
        WHERE flight_month
            <> EXTRACT(MONTH FROM flight_date)::INTEGER
    ) AS invalid_flight_months,

    COUNT(*) FILTER (
        WHERE day_of_week_number
            <> EXTRACT(DOW FROM flight_date)::INTEGER
    ) AS invalid_day_of_week_numbers,

    COUNT(*) FILTER (
        WHERE day_of_week_number < 0
           OR day_of_week_number > 6
    ) AS out_of_range_day_numbers,

    COUNT(*) FILTER (
        WHERE flight_month < 1
           OR flight_month > 12
    ) AS out_of_range_months

FROM flights;


-- ------------------------------------------------------------
-- 10. Validate route construction
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS inconsistent_routes
FROM flights
WHERE route IS DISTINCT FROM
      origin_airport || '-' || destination_airport;


-- ------------------------------------------------------------
-- 11. Preview final records
-- ------------------------------------------------------------

SELECT
    flight_id,
    flight_date,
    carrier_code,
    flight_number,
    origin_airport,
    destination_airport,
    route,
    departure_delay,
    arrival_delay,
    cancelled,
    diverted,
    flight_year,
    flight_month,
    day_of_week_number,
    day_of_week_name

FROM flights
ORDER BY flight_id
LIMIT 25;