-- ============================================================
-- Views — feed these directly into Power BI
-- ============================================================
-- Build these once your business_questions.sql queries are
-- solid — a view per dashboard panel keeps Power BI's queries
-- simple (SELECT * FROM view) instead of duplicating complex
-- SQL inside the report itself.
-- ============================================================

-- Example skeleton — replace with your actual logic:
--
-- CREATE OR REPLACE VIEW vw_revenue_by_route AS
-- SELECT
--     f.origin,
--     f.dest,
--     SUM(b.ticket_price) AS total_revenue,
--     COUNT(DISTINCT b.booking_id) AS total_bookings
-- FROM flights f
-- JOIN bookings b ON b.flight_id = f.flight_id
-- GROUP BY f.origin, f.dest;

-- CREATE OR REPLACE VIEW vw_monthly_ops_summary AS ...

-- CREATE OR REPLACE VIEW vw_customer_ltv AS ...
