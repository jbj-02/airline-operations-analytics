-- ============================================================
-- File: 06_create_flight_economics.sql
-- Purpose:
-- Combine operational and commercial data to create one
-- economics record per commercial flight.
--
-- Note:
-- Revenue is synthetic and operating costs are estimates
-- created for portfolio-analysis purposes.
-- ============================================================


-- ------------------------------------------------------------
-- 1. Remove the existing table so the script is rerunnable
-- ------------------------------------------------------------

DROP TABLE IF EXISTS flight_economics;


-- ------------------------------------------------------------
-- 2. Aggregate fare classes and create flight-level economics
-- ------------------------------------------------------------

CREATE TABLE flight_economics AS
WITH sales_summary AS (
    SELECT
        flight_id,

        /*
        Each fare-class row contains the total aircraft
        capacity. MAX prevents capacity from being counted
        three times.
        */
        MAX(seat_capacity) AS seat_capacity,

        SUM(passengers) AS passengers,
        SUM(ticket_revenue) AS ticket_revenue,

        ROUND(
            SUM(ticket_revenue) /
            NULLIF(SUM(passengers), 0),
            2
        ) AS revenue_per_passenger

    FROM flight_fare_sales
    GROUP BY flight_id
)

SELECT
    cf.flight_id,
    cf.flight_date,
    cf.flight_year,
    cf.flight_month,
    cf.day_of_week_number,
    cf.day_of_week_name,

    cf.carrier_code,
    cf.flight_number,
    cf.origin_airport,
    cf.destination_airport,
    cf.route,
    cf.distance,

    cf.departure_delay,
    cf.arrival_delay,
    cf.is_departure_delayed_15,
    cf.is_arrival_delayed_15,

    ss.seat_capacity,
    ss.passengers,
    ss.ticket_revenue,
    ss.revenue_per_passenger,

    ROUND(
        ss.passengers::NUMERIC /
        NULLIF(ss.seat_capacity, 0),
        4
    ) AS load_factor,

    /*
    Synthetic operating-cost model:
      $3,500 fixed cost per flight
      $9.50 per mile
      $18 per passenger
      Additional disruption cost for arrival delays
    */

    ROUND(
        (
            3500
            + cf.distance * 9.50
            + ss.passengers * 18
            + CASE
                WHEN cf.arrival_delay >= 180 THEN 15000
                WHEN cf.arrival_delay >= 120 THEN 9000
                WHEN cf.arrival_delay >= 60 THEN 4500
                WHEN cf.arrival_delay >= 15 THEN 1500
                ELSE 0
              END
        )::NUMERIC,
        2
    ) AS estimated_operating_cost,

    ROUND(
        (
            ss.ticket_revenue
            -
            (
                3500
                + cf.distance * 9.50
                + ss.passengers * 18
                + CASE
                    WHEN cf.arrival_delay >= 180 THEN 15000
                    WHEN cf.arrival_delay >= 120 THEN 9000
                    WHEN cf.arrival_delay >= 60 THEN 4500
                    WHEN cf.arrival_delay >= 15 THEN 1500
                    ELSE 0
                  END
            )
        )::NUMERIC,
        2
    ) AS estimated_profit

FROM commercial_flights AS cf
INNER JOIN sales_summary AS ss
    ON cf.flight_id = ss.flight_id;


-- ------------------------------------------------------------
-- 3. Add calculated economics columns
-- ------------------------------------------------------------

ALTER TABLE flight_economics
ADD COLUMN profit_margin NUMERIC(10,4),
ADD COLUMN revenue_per_mile NUMERIC(12,4),
ADD COLUMN revenue_per_available_seat_mile NUMERIC(12,4);


-- ------------------------------------------------------------
-- 4. Populate calculated economics columns
-- ------------------------------------------------------------

UPDATE flight_economics
SET
    profit_margin =
        estimated_profit /
        NULLIF(ticket_revenue, 0),

    revenue_per_mile =
        ticket_revenue /
        NULLIF(distance, 0),

    revenue_per_available_seat_mile =
        ticket_revenue /
        NULLIF(seat_capacity * distance, 0);


-- ------------------------------------------------------------
-- 5. Add the primary key
-- ------------------------------------------------------------

ALTER TABLE flight_economics
ADD CONSTRAINT flight_economics_primary_key
PRIMARY KEY (flight_id);


-- ------------------------------------------------------------
-- 6. Add indexes used by business-analysis queries
-- ------------------------------------------------------------

CREATE INDEX idx_economics_route
ON flight_economics (route);

CREATE INDEX idx_economics_carrier
ON flight_economics (carrier_code);

CREATE INDEX idx_economics_date
ON flight_economics (flight_date);

CREATE INDEX idx_economics_month
ON flight_economics (flight_month);

CREATE INDEX idx_economics_profit
ON flight_economics (estimated_profit);

CREATE INDEX idx_economics_arrival_delay
ON flight_economics (arrival_delay);


-- ------------------------------------------------------------
-- 7. Update PostgreSQL query-planning statistics
-- ------------------------------------------------------------

ANALYZE flight_economics;


-- ------------------------------------------------------------
-- 8. Validation
-- Expected total: 424,145 flight-level rows
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_flights,
    COUNT(DISTINCT flight_id) AS distinct_flight_ids
FROM flight_economics;


SELECT
    COUNT(*) AS null_economics_records
FROM flight_economics
WHERE ticket_revenue IS NULL
   OR estimated_operating_cost IS NULL
   OR estimated_profit IS NULL
   OR load_factor IS NULL;


SELECT
    COUNT(*) AS invalid_load_factor_records
FROM flight_economics
WHERE load_factor < 0
   OR load_factor > 1;


SELECT
    ROUND(SUM(ticket_revenue), 2) AS total_revenue,
    ROUND(SUM(estimated_operating_cost), 2) AS total_cost,
    ROUND(SUM(estimated_profit), 2) AS total_profit,

    ROUND(
        SUM(estimated_profit) /
        NULLIF(SUM(ticket_revenue), 0) * 100,
        2
    ) AS overall_profit_margin_pct,

    ROUND(
        AVG(load_factor) * 100,
        2
    ) AS average_load_factor_pct

FROM flight_economics;