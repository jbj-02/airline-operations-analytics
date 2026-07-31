DROP TABLE IF EXISTS flight_fare_sales;

CREATE TABLE flight_fare_sales (
    flight_id BIGINT,
    fare_class VARCHAR(30),
    seat_capacity INTEGER,
    passengers INTEGER,
    average_fare NUMERIC(10,2),
    ticket_revenue NUMERIC(12,2)
);