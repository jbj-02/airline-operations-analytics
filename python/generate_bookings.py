"""
generate_bookings.py

Generates synthetic bookings tied to REAL flights already loaded into
Postgres (via sql/schema.sql + sql/import_data.sql) and synthetic
customers already loaded (via generate_customers.py + etl.py).

Design principles (this is the part that makes the "commercial" data
feel non-arbitrary):

  1. Bookings reference real flight_id values, so load factor and
     revenue-by-route analysis is grounded in actual BTS flights.
  2. Ticket price is a function of distance, not a random number:
        price = base_rate_per_mile * distance * class_multiplier * noise
  3. Cancelled flights get zero bookings (can't sell seats on a flight
     that didn't fly — the whole point is internal consistency).
  4. Loyalty tier correlates with behavior, not just a label:
        - Platinum/Gold customers fly more often (weighted sampling)
        - Higher tiers skew toward Premium Economy / Business

Usage:
    python generate_bookings.py --db-url postgresql://user:pass@localhost/airline_db
"""

import argparse
import random
from datetime import date, timedelta

import psycopg2
from psycopg2.extras import execute_values

random.seed(42)

# ------------------------------------------------------------
# Pricing model
# ------------------------------------------------------------
BASE_RATE_PER_MILE = 0.13     # dollars/mile, rough real-world economy anchor
NOISE_RANGE = (0.85, 1.15)    # +/- 15% demand noise

CLASS_WEIGHTS_BY_TIER = {
    # class_id: 1=Economy, 2=Premium Economy, 3=Business
    "Basic":    {1: 0.88, 2: 0.10, 3: 0.02},
    "Silver":   {1: 0.75, 2: 0.20, 3: 0.05},
    "Gold":     {1: 0.55, 2: 0.30, 3: 0.15},
    "Platinum": {1: 0.30, 2: 0.35, 3: 0.35},
}

# Relative likelihood a customer of each tier books a given flight —
# this is what makes Platinum/Gold customers "fly more often."
TIER_BOOKING_WEIGHT = {"Basic": 1.0, "Silver": 1.8, "Gold": 3.0, "Platinum": 5.0}


def load_factor_for_flight(cancelled: bool) -> float:
    if cancelled:
        return 0.0
    # Beta distribution centered ~0.80 load factor, matching real industry averages
    return min(1.0, max(0.0, random.betavariate(8, 2)))


def price_for_flight(distance: float, class_id: int) -> float:
    class_multiplier = {1: 1.00, 2: 1.45, 3: 2.60}[class_id]
    noise = random.uniform(*NOISE_RANGE)
    price = BASE_RATE_PER_MILE * float(distance) * class_multiplier * noise
    return round(max(price, 35.0), 2)  # floor so short hops don't price near-zero


def pick_class(loyalty_tier: str) -> int:
    weights = CLASS_WEIGHTS_BY_TIER[loyalty_tier]
    classes, probs = zip(*weights.items())
    return random.choices(classes, weights=probs, k=1)[0]


def pick_customer(customers: list[tuple]) -> tuple:
    # customers: list of (customer_id, loyalty_tier)
    weights = [TIER_BOOKING_WEIGHT[tier] for _, tier in customers]
    return random.choices(customers, weights=weights, k=1)[0]


def random_booking_date(flight_date: date) -> date:
    # Bookings happen 1-330 days before the flight, skewed toward closer-in
    days_before = int(random.betavariate(2, 5) * 330) + 1
    return flight_date - timedelta(days=days_before)


def generate_bookings_for_flights(conn, batch_size: int = 5000, limit: int | None = None):
    cur = conn.cursor()

    cur.execute("SELECT customer_id, loyalty_tier FROM customers;")
    customers = cur.fetchall()
    if not customers:
        raise RuntimeError("No customers found — run generate_customers.py + load them first.")

    query = """
        SELECT f.flight_id, f.flight_date, f.distance, f.cancelled,
               COALESCE(a.seat_capacity, 150) AS seat_capacity
        FROM flights f
        LEFT JOIN aircraft a ON a.tail_number = f.tail_number
    """
    if limit:
        query += f" LIMIT {int(limit)}"
    cur.execute(query)

    insert_sql = """
        INSERT INTO bookings (flight_id, customer_id, class_id, ticket_price, booking_date)
        VALUES %s
    """

    buffer = []
    total_inserted = 0

    for flight_id, flight_date, distance, cancelled, seat_capacity in cur:
        lf = load_factor_for_flight(cancelled)
        n_bookings = int(seat_capacity * lf)

        for _ in range(n_bookings):
            customer_id, loyalty_tier = pick_customer(customers)
            class_id = pick_class(loyalty_tier)
            price = price_for_flight(distance or 0, class_id)
            booking_date = random_booking_date(flight_date)
            buffer.append((flight_id, customer_id, class_id, price, booking_date))

        if len(buffer) >= batch_size:
            execute_values(cur, insert_sql, buffer)
            conn.commit()
            total_inserted += len(buffer)
            buffer = []

    if buffer:
        execute_values(cur, insert_sql, buffer)
        conn.commit()
        total_inserted += len(buffer)

    cur.close()
    print(f"Inserted {total_inserted} bookings.")


def main():
    parser = argparse.ArgumentParser(description="Generate synthetic bookings for real flights.")
    parser.add_argument("--db-url", required=True, help="Postgres connection string.")
    parser.add_argument("--batch-size", type=int, default=5000)
    parser.add_argument("--limit", type=int, default=None, help="Limit # of flights processed (useful for testing).")
    args = parser.parse_args()

    conn = psycopg2.connect(args.db_url)
    try:
        generate_bookings_for_flights(conn, batch_size=args.batch_size, limit=args.limit)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
