-- ============================================================
-- File: 04_create_commercial_subset.sql
-- Purpose:
-- Create a focused commercial-flight subset containing
-- American, Delta, and United flights on sufficiently active
-- routes during 2024.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Remove the existing table so the script is rerunnable
-- ------------------------------------------------------------

DROP TABLE IF EXISTS commercial_flights;


-- ------------------------------------------------------------
-- 2. Create the commercial-flight subset
-- ------------------------------------------------------------

CREATE TABLE commercial_flights AS
WITH eligible_routes AS (
    SELECT
        origin_airport,
        destination_airport
    FROM flights
    WHERE carrier_code IN ('AA', 'DL', 'UA')
      AND flight_date >= DATE '2024-01-01'
      AND flight_date < DATE '2025-01-01'
      AND cancelled = 0
      AND diverted = 0
    GROUP BY
        origin_airport,
        destination_airport
    HAVING COUNT(*) >= 1000
)

SELECT
    f.*
FROM flights AS f
INNER JOIN eligible_routes AS er
    ON f.origin_airport = er.origin_airport
   AND f.destination_airport = er.destination_airport
WHERE f.carrier_code IN ('AA', 'DL', 'UA')
  AND f.flight_date >= DATE '2024-01-01'
  AND f.flight_date < DATE '2025-01-01'
  AND f.cancelled = 0
  AND f.diverted = 0;


-- ------------------------------------------------------------
-- 3. Add a primary key
-- ------------------------------------------------------------

ALTER TABLE commercial_flights
ADD CONSTRAINT commercial_flights_primary_key
PRIMARY KEY (flight_id);


-- ------------------------------------------------------------
-- 4. Add indexes used by later analysis
-- ------------------------------------------------------------

CREATE INDEX idx_commercial_flights_date
ON commercial_flights (flight_date);

CREATE INDEX idx_commercial_flights_carrier
ON commercial_flights (carrier_code);

CREATE INDEX idx_commercial_flights_origin
ON commercial_flights (origin_airport);

CREATE INDEX idx_commercial_flights_destination
ON commercial_flights (destination_airport);

CREATE INDEX idx_commercial_flights_route
ON commercial_flights (route);


-- ------------------------------------------------------------
-- 5. Update PostgreSQL query-planning statistics
-- ------------------------------------------------------------

ANALYZE commercial_flights;


-- ------------------------------------------------------------
-- 6. Validation
-- Expected result from the completed project:
-- 424,145 flights
-- 3 carriers
-- 130 routes
-- 2024-01-01 through 2024-12-31
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_flights,
    COUNT(DISTINCT carrier_code) AS carriers,
    COUNT(DISTINCT route) AS routes,
    MIN(flight_date) AS first_date,
    MAX(flight_date) AS last_date
FROM commercial_flights;


SELECT
    carrier_code,
    COUNT(*) AS total_flights
FROM commercial_flights
GROUP BY carrier_code
ORDER BY total_flights DESC;