CREATE INDEX idx_flights_date
ON flights (flight_date);

CREATE INDEX idx_flights_carrier
ON flights (carrier_code);

CREATE INDEX idx_flights_origin
ON flights (origin_airport);

CREATE INDEX idx_flights_destination
ON flights (destination_airport);

CREATE INDEX idx_flights_route
ON flights (route);

CREATE INDEX idx_flights_tail_number
ON flights (tail_number);

CREATE INDEX idx_flights_cancelled
ON flights (cancelled);

CREATE INDEX idx_flights_arrival_delay
ON flights (is_arrival_delayed_15);

CREATE INDEX idx_flights_month
ON flights (flight_month);