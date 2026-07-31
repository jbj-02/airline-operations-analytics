DROP TABLE IF EXISTS flights_staging;

CREATE TABLE flights_staging (
    flight_date DATE,
    carrier_code VARCHAR(10),
    tail_number VARCHAR(20),
    flight_number INTEGER,

    origin_airport_id INTEGER,
    origin_airport VARCHAR(10),

    destination_airport_id INTEGER,
    destination_airport VARCHAR(10),

    scheduled_departure_time INTEGER,
    actual_departure_time INTEGER,

    departure_delay NUMERIC,
    departure_delay_nonnegative NUMERIC,

    scheduled_arrival_time INTEGER,
    actual_arrival_time INTEGER,

    arrival_delay NUMERIC,
    arrival_delay_nonnegative NUMERIC,

    cancelled BOOLEAN,
    cancellation_code VARCHAR(5),
    diverted BOOLEAN,

    scheduled_elapsed_time NUMERIC,
    actual_elapsed_time NUMERIC,
    air_time NUMERIC,
    distance NUMERIC,

    route VARCHAR(25),
    departure_hour INTEGER,

    is_arrival_delayed_15 BOOLEAN,
    is_departure_delayed_15 BOOLEAN
);