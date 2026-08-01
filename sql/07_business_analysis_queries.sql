-- ============================================================
-- File: 07_business_analysis_queries.sql
-- Purpose:
-- Answer business questions using the completed operational
-- and commercial airline analytics tables.
--
-- Notes:
-- - Operational flight data is based on BTS records.
-- - Passenger, fare, revenue, cost, and profit data are
--   synthetic and intended for portfolio analysis.
-- - This file contains read-only SELECT queries.
-- - Run each query individually in pgAdmin while reviewing
--   the results.
-- ============================================================


-- ============================================================
-- Query 1: Executive KPI summary
--
-- Business question:
-- What are the overall commercial and operational results?
-- ============================================================

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
-- Query 2: Most profitable high-volume routes
--
-- Business question:
-- Which frequently operated routes generate the most
-- estimated profit?
-- ============================================================

SELECT
    route,
    origin_airport,
    destination_airport,

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
    route,
    origin_airport,
    destination_airport

HAVING COUNT(*) >= 1000

ORDER BY total_profit DESC

LIMIT 20;


-- ============================================================
-- Query 3: Least profitable high-volume routes
--
-- Business question:
-- Which frequently operated routes may need commercial or
-- operational intervention?
-- ============================================================

SELECT
    route,
    origin_airport,
    destination_airport,

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
    route,
    origin_airport,
    destination_airport

HAVING COUNT(*) >= 1000

ORDER BY total_profit ASC

LIMIT 20;


-- ============================================================
-- Query 4: Carrier performance
--
-- Business question:
-- How do American, Delta, and United compare commercially and
-- operationally?
-- ============================================================

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
        AVG(revenue_per_passenger),
        2
    ) AS average_revenue_per_passenger,

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

GROUP BY carrier_code

ORDER BY total_profit DESC;


-- ============================================================
-- Query 5: Monthly performance
--
-- Business question:
-- How do demand, revenue, profit, and delays change throughout
-- the year?
-- ============================================================

SELECT
    flight_month,

    TO_CHAR(
        MAKE_DATE(2024, flight_month, 1),
        'Month'
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

GROUP BY flight_month

ORDER BY flight_month;


-- ============================================================
-- Query 6: Financial effect of arrival delays
--
-- Business question:
-- How does arrival-delay severity affect operating costs,
-- profit, and margin?
-- ============================================================

WITH delay_categories AS (
    SELECT
        flight_id,
        arrival_delay,
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
    delay_category,

    COUNT(*) AS total_flights,

    ROUND(
        AVG(arrival_delay),
        2
    ) AS average_arrival_delay,

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
    ) AS profit_margin_pct

FROM delay_categories

GROUP BY
    delay_category,
    delay_order

ORDER BY delay_order;


-- ============================================================
-- Query 7: Day-of-week performance
--
-- Business question:
-- Which days of the week deliver the strongest commercial and
-- operational performance?
-- ============================================================

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
    day_of_week_name

ORDER BY day_of_week_number;


-- ============================================================
-- Query 8: High-revenue routes with weak reliability
--
-- Business question:
-- Which commercially important routes also have meaningful
-- operational performance problems?
-- ============================================================

SELECT
    route,
    origin_airport,
    destination_airport,

    COUNT(*) AS total_flights,

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
    route,
    origin_airport,
    destination_airport

HAVING COUNT(*) >= 1000
   AND AVG(is_arrival_delayed_15::INTEGER) >= 0.20

ORDER BY total_revenue DESC

LIMIT 20;


-- ============================================================
-- Query 9: Fare-class performance
--
-- Business question:
-- How much passenger volume and revenue does each fare class
-- contribute?
-- ============================================================

SELECT
    fare_class,

    SUM(passengers) AS total_passengers,

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
        SUM(ticket_revenue)
        / NULLIF(
            SUM(SUM(ticket_revenue)) OVER (),
            0
        )
        * 100,
        2
    ) AS revenue_share_pct

FROM flight_fare_sales

GROUP BY fare_class

ORDER BY total_revenue DESC;


-- ============================================================
-- Query 10: Route revenue efficiency
--
-- Business question:
-- Which high-volume routes generate the strongest revenue per
-- available seat mile?
-- ============================================================

SELECT
    route,
    origin_airport,
    destination_airport,

    COUNT(*) AS total_flights,

    ROUND(
        SUM(ticket_revenue),
        2
    ) AS total_revenue,

    ROUND(
        SUM(ticket_revenue)
        / NULLIF(
            SUM(seat_capacity * distance),
            0
        ),
        4
    ) AS route_rasm,

    ROUND(
        SUM(passengers)::NUMERIC
        / NULLIF(SUM(seat_capacity), 0)
        * 100,
        2
    ) AS weighted_load_factor_pct,

    ROUND(
        SUM(estimated_profit)
        / NULLIF(SUM(ticket_revenue), 0)
        * 100,
        2
    ) AS profit_margin_pct

FROM flight_economics

GROUP BY
    route,
    origin_airport,
    destination_airport

HAVING COUNT(*) >= 1000

ORDER BY route_rasm DESC

LIMIT 20;