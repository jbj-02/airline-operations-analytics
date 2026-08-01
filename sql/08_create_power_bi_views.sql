-- ============================================================
-- File: 08_create_power_bi_views.sql
-- Purpose:
-- Create dashboard-ready PostgreSQL views for Power BI.
--
-- Notes:
-- - Operational flight data is based on BTS records.
-- - Passenger, fare, revenue, cost, and profit data are
--   synthetic and intended for portfolio analysis.
-- - These views summarize the validated business-analysis
--   queries stored in 07_business_analysis_queries.sql.
-- - This file creates database objects and should be both:
--      1. Saved in VS Code
--      2. Executed in pgAdmin
-- ============================================================


-- ============================================================
-- View 1: Executive summary
--
-- Power BI use:
-- KPI cards for total flights, passengers, revenue, cost,
-- profit, margin, load factor, and delay performance.
-- ============================================================

CREATE OR REPLACE VIEW vw_executive_summary AS
SELECT
    COUNT(*) AS total_flights,

    SUM(passengers) AS total_passengers,

    ROUND(
        SUM(ticket_revenue),
        2
    ) AS total_revenue,

    ROUND(
        SUM(estimated_operating_cost),
        2
    ) AS total_operating_cost,

    ROUND(
        SUM(estimated_profit),
        2
    ) AS total_profit,

    ROUND(
        SUM(estimated_profit)
        / NULLIF(SUM(ticket_revenue), 0)
        * 100,
        2
    ) AS profit_margin_pct,

    ROUND(
        SUM(passengers)::NUMERIC
        / NULLIF(SUM(seat_capacity), 0)
        * 100,
        2
    ) AS weighted_load_factor_pct,

    ROUND(
        AVG(arrival_delay),
        2
    ) AS average_arrival_delay,

    ROUND(
        AVG(is_arrival_delayed_15::INTEGER)
        * 100,
        2
    ) AS arrival_delay_rate_pct

FROM flight_economics;


-- ============================================================
-- View 2: Carrier performance
--
-- Power BI use:
-- Compare American, Delta, and United on revenue, profit,
-- margins, demand, load factor, fares, and delays.
-- ============================================================

CREATE OR REPLACE VIEW vw_carrier_performance AS
SELECT
    carrier_code,

    COUNT(*) AS total_flights,

    SUM(passengers) AS total_passengers,

    ROUND(
        SUM(ticket_revenue),
        2
    ) AS total_revenue,

    ROUND(
        SUM(estimated_operating_cost),
        2
    ) AS total_operating_cost,

    ROUND(
        SUM(estimated_profit),
        2
    ) AS total_profit,

    ROUND(
        SUM(estimated_profit)
        / NULLIF(SUM(ticket_revenue), 0)
        * 100,
        2
    ) AS profit_margin_pct,

    ROUND(
        SUM(passengers)::NUMERIC
        / NULLIF(SUM(seat_capacity), 0)
        * 100,
        2
    ) AS weighted_load_factor_pct,

    ROUND(
        SUM(ticket_revenue)
        / NULLIF(SUM(passengers), 0),
        2
    ) AS weighted_revenue_per_passenger,

    ROUND(
        AVG(arrival_delay),
        2
    ) AS average_arrival_delay,

    ROUND(
        AVG(is_arrival_delayed_15::INTEGER)
        * 100,
        2
    ) AS arrival_delay_rate_pct

FROM flight_economics

GROUP BY carrier_code;


-- ============================================================
-- View 3: Monthly performance
--
-- Power BI use:
-- Monthly trend visuals for flights, passengers, revenue,
-- profit, margin, load factor, and delays.
-- ============================================================

CREATE OR REPLACE VIEW vw_monthly_performance AS
SELECT
    flight_month,

    TRIM(
        TO_CHAR(
            MAKE_DATE(2024, flight_month, 1),
            'Month'
        )
    ) AS month_name,

    COUNT(*) AS total_flights,

    SUM(passengers) AS total_passengers,

    ROUND(
        SUM(ticket_revenue),
        2
    ) AS total_revenue,

    ROUND(
        SUM(estimated_operating_cost),
        2
    ) AS total_operating_cost,

    ROUND(
        SUM(estimated_profit),
        2
    ) AS total_profit,

    ROUND(
        SUM(estimated_profit)
        / NULLIF(SUM(ticket_revenue), 0)
        * 100,
        2
    ) AS profit_margin_pct,

    ROUND(
        SUM(passengers)::NUMERIC
        / NULLIF(SUM(seat_capacity), 0)
        * 100,
        2
    ) AS weighted_load_factor_pct,

    ROUND(
        AVG(arrival_delay),
        2
    ) AS average_arrival_delay,

    ROUND(
        AVG(is_arrival_delayed_15::INTEGER)
        * 100,
        2
    ) AS arrival_delay_rate_pct

FROM flight_economics

GROUP BY flight_month;


-- ============================================================
-- View 4: Route performance
--
-- Power BI use:
-- Route rankings, scatterplots, drill-downs, slicers, and
-- route-level profitability and reliability analysis.
--
-- Unlike the top-20 SQL analysis queries, this view keeps all
-- routes so Power BI can filter and rank dynamically.
-- ============================================================

CREATE OR REPLACE VIEW vw_route_performance AS
SELECT
    route,
    origin_airport,
    destination_airport,

    COUNT(*) AS total_flights,

    SUM(passengers) AS total_passengers,

    SUM(seat_capacity) AS total_seat_capacity,

    ROUND(
        SUM(ticket_revenue),
        2
    ) AS total_revenue,

    ROUND(
        SUM(estimated_operating_cost),
        2
    ) AS total_operating_cost,

    ROUND(
        SUM(estimated_profit),
        2
    ) AS total_profit,

    ROUND(
        SUM(estimated_profit)
        / NULLIF(SUM(ticket_revenue), 0)
        * 100,
        2
    ) AS profit_margin_pct,

    ROUND(
        SUM(passengers)::NUMERIC
        / NULLIF(SUM(seat_capacity), 0)
        * 100,
        2
    ) AS weighted_load_factor_pct,

    ROUND(
        SUM(ticket_revenue)
        / NULLIF(SUM(passengers), 0),
        2
    ) AS weighted_revenue_per_passenger,

    ROUND(
        SUM(ticket_revenue)
        / NULLIF(
            SUM(seat_capacity * distance),
            0
        ),
        4
    ) AS route_rasm,

    ROUND(
        AVG(distance),
        2
    ) AS average_distance,

    ROUND(
        AVG(arrival_delay),
        2
    ) AS average_arrival_delay,

    ROUND(
        AVG(departure_delay),
        2
    ) AS average_departure_delay,

    ROUND(
        AVG(is_arrival_delayed_15::INTEGER)
        * 100,
        2
    ) AS arrival_delay_rate_pct,

    ROUND(
        AVG(is_departure_delayed_15::INTEGER)
        * 100,
        2
    ) AS departure_delay_rate_pct

FROM flight_economics

GROUP BY
    route,
    origin_airport,
    destination_airport;


-- ============================================================
-- View 5: Delay impact
--
-- Power BI use:
-- Analyze the relationship between delay severity, cost,
-- profit, margin, and flight volume.
-- ============================================================

CREATE OR REPLACE VIEW vw_delay_impact AS
WITH delay_categories AS (
    SELECT
        flight_id,
        arrival_delay,
        passengers,
        ticket_revenue,
        estimated_operating_cost,
        estimated_profit,

        CASE
            WHEN arrival_delay IS NULL
                THEN 'Unknown'

            WHEN arrival_delay < 15
                THEN 'On time or under 15 minutes'

            WHEN arrival_delay < 60
                THEN '15-59 minutes'

            WHEN arrival_delay < 120
                THEN '60-119 minutes'

            WHEN arrival_delay < 180
                THEN '120-179 minutes'

            ELSE '180+ minutes'
        END AS delay_category,

        CASE
            WHEN arrival_delay IS NULL THEN 6
            WHEN arrival_delay < 15 THEN 1
            WHEN arrival_delay < 60 THEN 2
            WHEN arrival_delay < 120 THEN 3
            WHEN arrival_delay < 180 THEN 4
            ELSE 5
        END AS delay_order

    FROM flight_economics
)

SELECT
    delay_order,
    delay_category,

    COUNT(*) AS total_flights,

    SUM(passengers) AS total_passengers,

    ROUND(
        AVG(arrival_delay),
        2
    ) AS average_arrival_delay,

    ROUND(
        AVG(ticket_revenue),
        2
    ) AS average_revenue_per_flight,

    ROUND(
        AVG(estimated_operating_cost),
        2
    ) AS average_operating_cost,

    ROUND(
        AVG(estimated_profit),
        2
    ) AS average_profit_per_flight,

    ROUND(
        SUM(ticket_revenue),
        2
    ) AS total_revenue,

    ROUND(
        SUM(estimated_operating_cost),
        2
    ) AS total_operating_cost,

    ROUND(
        SUM(estimated_profit),
        2
    ) AS total_profit,

    ROUND(
        SUM(estimated_profit)
        / NULLIF(SUM(ticket_revenue), 0)
        * 100,
        2
    ) AS profit_margin_pct

FROM delay_categories

GROUP BY
    delay_order,
    delay_category;


-- ============================================================
-- View 6: Fare-class performance
--
-- Power BI use:
-- Revenue mix, passenger mix, weighted fares, and fare-class
-- load-factor comparisons.
-- ============================================================

CREATE OR REPLACE VIEW vw_fare_class_performance AS
SELECT
    fare_class,

    SUM(passengers) AS total_passengers,

    SUM(seat_capacity) AS total_seat_capacity,

    ROUND(
        SUM(ticket_revenue),
        2
    ) AS total_revenue,

    ROUND(
        SUM(ticket_revenue)
        / NULLIF(SUM(passengers), 0),
        2
    ) AS weighted_average_fare,

    ROUND(
        SUM(passengers)::NUMERIC
        / NULLIF(SUM(seat_capacity), 0)
        * 100,
        2
    ) AS fare_class_load_factor_pct,

    ROUND(
        SUM(passengers)::NUMERIC
        / NULLIF(
            SUM(SUM(passengers)) OVER (),
            0
        )
        * 100,
        2
    ) AS passenger_share_pct,

    ROUND(
        SUM(ticket_revenue)
        / NULLIF(
            SUM(SUM(ticket_revenue)) OVER (),
            0
        )
        * 100,
        2
    ) AS revenue_share_pct

FROM flight_fare_sales

GROUP BY fare_class;


-- ============================================================
-- View 7: Day-of-week performance
--
-- Power BI use:
-- Compare demand, profitability, and reliability by day.
-- ============================================================

CREATE OR REPLACE VIEW vw_day_of_week_performance AS
SELECT
    day_of_week_number,
    day_of_week_name,

    COUNT(*) AS total_flights,

    SUM(passengers) AS total_passengers,

    ROUND(
        SUM(ticket_revenue),
        2
    ) AS total_revenue,

    ROUND(
        SUM(estimated_operating_cost),
        2
    ) AS total_operating_cost,

    ROUND(
        SUM(estimated_profit),
        2
    ) AS total_profit,

    ROUND(
        SUM(estimated_profit)
        / NULLIF(SUM(ticket_revenue), 0)
        * 100,
        2
    ) AS profit_margin_pct,

    ROUND(
        SUM(passengers)::NUMERIC
        / NULLIF(SUM(seat_capacity), 0)
        * 100,
        2
    ) AS weighted_load_factor_pct,

    ROUND(
        AVG(arrival_delay),
        2
    ) AS average_arrival_delay,

    ROUND(
        AVG(is_arrival_delayed_15::INTEGER)
        * 100,
        2
    ) AS arrival_delay_rate_pct

FROM flight_economics

GROUP BY
    day_of_week_number,
    day_of_week_name;


-- ============================================================
-- View 8: Distance-band performance
--
-- Power BI use:
-- Explain how route distance relates to revenue, operating
-- costs, profitability, and load factor.
-- ============================================================

CREATE OR REPLACE VIEW vw_distance_band_performance AS
WITH distance_bands AS (
    SELECT
        CASE
            WHEN distance < 300
                THEN 'Under 300 miles'

            WHEN distance < 600
                THEN '300-599 miles'

            WHEN distance < 1000
                THEN '600-999 miles'

            WHEN distance < 1500
                THEN '1,000-1,499 miles'

            WHEN distance < 2500
                THEN '1,500-2,499 miles'

            ELSE '2,500+ miles'
        END AS distance_band,

        CASE
            WHEN distance < 300 THEN 1
            WHEN distance < 600 THEN 2
            WHEN distance < 1000 THEN 3
            WHEN distance < 1500 THEN 4
            WHEN distance < 2500 THEN 5
            ELSE 6
        END AS distance_order,

        passengers,
        seat_capacity,
        ticket_revenue,
        estimated_operating_cost,
        estimated_profit

    FROM flight_economics
)

SELECT
    distance_order,
    distance_band,

    COUNT(*) AS total_flights,

    SUM(passengers) AS total_passengers,

    ROUND(
        AVG(ticket_revenue),
        2
    ) AS average_revenue_per_flight,

    ROUND(
        AVG(estimated_operating_cost),
        2
    ) AS average_operating_cost,

    ROUND(
        AVG(estimated_profit),
        2
    ) AS average_profit_per_flight,

    ROUND(
        SUM(ticket_revenue),
        2
    ) AS total_revenue,

    ROUND(
        SUM(estimated_profit),
        2
    ) AS total_profit,

    ROUND(
        SUM(estimated_profit)
        / NULLIF(SUM(ticket_revenue), 0)
        * 100,
        2
    ) AS profit_margin_pct,

    ROUND(
        SUM(passengers)::NUMERIC
        / NULLIF(SUM(seat_capacity), 0)
        * 100,
        2
    ) AS weighted_load_factor_pct

FROM distance_bands

GROUP BY
    distance_order,
    distance_band;


-- ============================================================
-- Validation 1: Confirm all Power BI views exist
-- ============================================================

SELECT
    table_name
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name LIKE 'vw_%'
ORDER BY table_name;


-- ============================================================
-- Validation 2: Preview executive summary
-- Expected:
-- One row
-- Approximately $18.30B in revenue
-- Approximately $3.22B in estimated profit
-- Approximately 17.59% profit margin
-- Approximately 80% weighted load factor
-- ============================================================

SELECT *
FROM vw_executive_summary;


-- ============================================================
-- Validation 3: Preview carrier performance
-- Expected:
-- Three rows: AA, DL, and UA
-- ============================================================

SELECT *
FROM vw_carrier_performance
ORDER BY total_profit DESC;


-- ============================================================
-- Validation 4: Preview monthly performance
-- Expected:
-- Twelve rows ordered January through December
-- ============================================================

SELECT *
FROM vw_monthly_performance
ORDER BY flight_month;


-- ============================================================
-- Validation 5: Check route-view row count
-- Expected:
-- Approximately 130 directional routes
-- ============================================================

SELECT
    COUNT(*) AS total_routes
FROM vw_route_performance;


-- ============================================================
-- Validation 6: Preview delay categories
-- ============================================================

SELECT *
FROM vw_delay_impact
ORDER BY delay_order;


-- ============================================================
-- Validation 7: Preview fare classes
-- Expected:
-- Economy, Premium Economy, and Business
-- ============================================================

SELECT *
FROM vw_fare_class_performance
ORDER BY total_revenue DESC;


-- ============================================================
-- Validation 8: Preview distance bands
-- ============================================================

SELECT *
FROM vw_distance_band_performance
ORDER BY distance_order;