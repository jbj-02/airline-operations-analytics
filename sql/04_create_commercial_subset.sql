-- ============================================================
-- File: 04_create_commercial_subset.sql
-- Purpose:
-- Create a focused commercial subset containing completed
-- 2024 flights operated by AA, DL, and UA on the 130
-- highest-volume directional routes.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Remove the existing commercial subset
-- ------------------------------------------------------------

DROP TABLE IF EXISTS commercial_flights;


-- ------------------------------------------------------------
-- 2. Rank routes by annual completed-flight volume and retain
--    the 130 highest-volume directional routes
-- ------------------------------------------------------------

CREATE TABLE commercial_flights AS
WITH route_volume AS (
    SELECT
        origin_airport,
        destination_airport,
        COUNT(*) AS annual_flights
    FROM flights
    WHERE carrier_code IN ('AA', 'DL', 'UA')
      AND flight_date >= DATE '2024-01-01'
      AND flight_date < DATE '2025-01-01'
      AND cancelled IS FALSE
      AND diverted IS FALSE
    GROUP BY
        origin_airport,
        destination_airport
),
top_routes AS (
    SELECT
        origin_airport,
        destination_airport,
        annual_flights
    FROM route_volume
    ORDER BY
        annual_flights DESC,
        origin_airport,
        destination_airport
    LIMIT 130
)
SELECT
    f.*
FROM flights AS f
INNER JOIN top_routes AS tr
    ON f.origin_airport = tr.origin_airport
   AND f.destination_airport = tr.destination_airport
WHERE f.carrier_code IN ('AA', 'DL', 'UA')
  AND f.flight_date >= DATE '2024-01-01'
  AND f.flight_date < DATE '2025-01-01'
  AND f.cancelled IS FALSE
  AND f.diverted IS FALSE;


-- ------------------------------------------------------------
-- 3. Add primary key
-- ------------------------------------------------------------

ALTER TABLE commercial_flights
ADD CONSTRAINT commercial_flights_primary_key
PRIMARY KEY (flight_id);


-- ------------------------------------------------------------
-- 4. Add supporting indexes
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
-- 5. Update query-planning statistics
-- ------------------------------------------------------------

ANALYZE commercial_flights;


-- ------------------------------------------------------------
-- 6. Validate scope
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_flights,
    COUNT(DISTINCT route) AS total_routes,
    COUNT(DISTINCT carrier_code) AS total_carriers,
    MIN(flight_date) AS first_date,
    MAX(flight_date) AS last_date
FROM commercial_flights;


-- ------------------------------------------------------------
-- 7. Confirm all 12 months are represented
-- ------------------------------------------------------------

SELECT
    flight_month,
    COUNT(*) AS commercial_flights
FROM commercial_flights
GROUP BY flight_month
ORDER BY flight_month;