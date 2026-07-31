DROP TABLE IF EXISTS flights;

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

    EXTRACT(YEAR FROM flight_date)::INTEGER AS flight_year,
    EXTRACT(MONTH FROM flight_date)::INTEGER AS flight_month,
    EXTRACT(DOW FROM flight_date)::INTEGER AS day_of_week_number,
    TO_CHAR(flight_date, 'Day') AS day_of_week_name

FROM flights_staging;