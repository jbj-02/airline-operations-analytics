DROP TABLE IF EXISTS commercial_flights;

CREATE TABLE commercial_flights AS
SELECT *
FROM flights
WHERE carrier_code IN ('AA', 'DL', 'UA')
  AND origin_airport IN (
      'ATL',
      'BOS',
      'CLT',
      'DEN',
      'DFW',
      'EWR',
      'JFK',
      'LAX',
      'MIA',
      'ORD',
      'SEA',
      'SFO'
  )
  AND destination_airport IN (
      'ATL',
      'BOS',
      'CLT',
      'DEN',
      'DFW',
      'EWR',
      'JFK',
      'LAX',
      'MIA',
      'ORD',
      'SEA',
      'SFO'
  )
  AND cancelled = FALSE
  AND diverted = FALSE
  AND tail_number IS NOT NULL;