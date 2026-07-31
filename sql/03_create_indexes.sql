-- ============================================================
-- File: 03_create_indexes.sql
-- Purpose:
-- Create indexes that improve performance for common filters,
-- joins, aggregations, and dashboard queries on the flights
-- table.
--
-- Run this file only after:
--   1. flights_staging has been loaded
--   2. the final flights table has been created
-- ============================================================


-- ------------------------------------------------------------
-- 1. Remove existing indexes
--
-- This makes the script rerunnable without producing
-- "relation already exists" errors.
-- ------------------------------------------------------------

DROP INDEX IF EXISTS idx_flights_date;
DROP INDEX IF EXISTS idx_flights_carrier;
DROP INDEX IF EXISTS idx_flights_origin;
DROP INDEX IF EXISTS idx_flights_destination;
DROP INDEX IF EXISTS idx_flights_route;
DROP INDEX IF EXISTS idx_flights_tail_number;
DROP INDEX IF EXISTS idx_flights_cancelled;
DROP INDEX IF EXISTS idx_flights_arrival_delay;
DROP INDEX IF EXISTS idx_flights_month;


-- ------------------------------------------------------------
-- 2. Date index
--
-- Supports date-range filters, monthly reporting, and trend
-- analysis.
-- ------------------------------------------------------------

CREATE INDEX idx_flights_date
ON flights (flight_date);


-- ------------------------------------------------------------
-- 3. Carrier index
--
-- Supports airline comparisons and carrier-level filtering.
-- ------------------------------------------------------------

CREATE INDEX idx_flights_carrier
ON flights (carrier_code);


-- ------------------------------------------------------------
-- 4. Origin-airport index
--
-- Supports airport-level departure analysis.
-- ------------------------------------------------------------

CREATE INDEX idx_flights_origin
ON flights (origin_airport);


-- ------------------------------------------------------------
-- 5. Destination-airport index
--
-- Supports airport-level arrival analysis.
-- ------------------------------------------------------------

CREATE INDEX idx_flights_destination
ON flights (destination_airport);


-- ------------------------------------------------------------
-- 6. Route index
--
-- Supports route-level aggregation and profitability analysis.
-- ------------------------------------------------------------

CREATE INDEX idx_flights_route
ON flights (route);


-- ------------------------------------------------------------
-- 7. Aircraft index
--
-- Supports aircraft utilization and tail-number analysis.
-- ------------------------------------------------------------

CREATE INDEX idx_flights_tail_number
ON flights (tail_number);


-- ------------------------------------------------------------
-- 8. Cancellation index
--
-- Supports filtering between completed and cancelled flights.
-- ------------------------------------------------------------

CREATE INDEX idx_flights_cancelled
ON flights (cancelled);


-- ------------------------------------------------------------
-- 9. Arrival-delay indicator index
--
-- Supports filtering flights delayed by at least 15 minutes.
-- ------------------------------------------------------------

CREATE INDEX idx_flights_arrival_delay
ON flights (is_arrival_delayed_15);


-- ------------------------------------------------------------
-- 10. Month index
--
-- Supports month-level aggregation and seasonal analysis.
-- ------------------------------------------------------------

CREATE INDEX idx_flights_month
ON flights (flight_month);


-- ------------------------------------------------------------
-- 11. Update PostgreSQL query-planning statistics
-- ------------------------------------------------------------

ANALYZE flights;


-- ------------------------------------------------------------
-- 12. Validate the indexes
--
-- This query should return each of the indexes created above,
-- along with the flights table primary-key index.
-- ------------------------------------------------------------

SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'flights'
ORDER BY indexname;


-- ------------------------------------------------------------
-- 13. Confirm table size and index size
--
-- These values help document the scale of the project and the
-- storage cost of indexing more than seven million records.
-- ------------------------------------------------------------

SELECT
    pg_size_pretty(
        pg_relation_size('flights')
    ) AS table_size,

    pg_size_pretty(
        pg_indexes_size('flights')
    ) AS total_index_size,

    pg_size_pretty(
        pg_total_relation_size('flights')
    ) AS total_table_and_index_size;


-- ------------------------------------------------------------
-- 14. Confirm row count after index creation
--
-- Creating indexes should not change the number of records.
-- Expected result:
-- 7,106,619 rows
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_flights
FROM flights;