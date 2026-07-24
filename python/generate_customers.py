"""
generate_customers.py

Generates a synthetic customer base for the airline analytics project.

Key design choice: loyalty tier is NOT uniform random. Real airline
loyalty programs skew heavily toward the base tier, so we sample from
a weighted distribution. This matters downstream — generate_bookings.py
uses loyalty_tier to influence booking frequency and ticket class, which
is what makes "customer lifetime value" and "loyalty spending" business
questions have real signal instead of being pure noise.

Usage:
    python generate_customers.py --count 20000 --out ../data/processed/customers.csv
"""

import argparse
import csv
import random
from datetime import date, timedelta

from faker import Faker

fake = Faker()
Faker.seed(42)   # reproducible runs — remove/change if you want fresh data each time
random.seed(42)

# ------------------------------------------------------------
# Loyalty tier distribution
# ------------------------------------------------------------
# Skewed toward Basic, matching how real airline loyalty programs
# are structured (most flyers never advance past the entry tier).
LOYALTY_TIERS = ["Basic", "Silver", "Gold", "Platinum"]
LOYALTY_WEIGHTS = [0.65, 0.22, 0.09, 0.04]

SIGNUP_RANGE_START = date(2015, 1, 1)
SIGNUP_RANGE_END = date(2024, 12, 31)


def random_signup_date() -> date:
    delta_days = (SIGNUP_RANGE_END - SIGNUP_RANGE_START).days
    return SIGNUP_RANGE_START + timedelta(days=random.randint(0, delta_days))


def generate_customers(count: int) -> list[dict]:
    customers = []
    for i in range(1, count + 1):
        first = fake.first_name()
        last = fake.last_name()
        customers.append({
            "customer_id": i,
            "first_name": first,
            "last_name": last,
            "email": f"{first.lower()}.{last.lower()}{i}@{fake.free_email_domain()}",
            "signup_date": random_signup_date().isoformat(),
            "loyalty_tier": random.choices(LOYALTY_TIERS, weights=LOYALTY_WEIGHTS, k=1)[0],
        })
    return customers


def write_csv(customers: list[dict], out_path: str) -> None:
    fieldnames = ["customer_id", "first_name", "last_name", "email", "signup_date", "loyalty_tier"]
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(customers)


def main():
    parser = argparse.ArgumentParser(description="Generate synthetic customers.")
    parser.add_argument("--count", type=int, default=20000, help="Number of customers to generate.")
    parser.add_argument("--out", type=str, default="../data/processed/customers.csv", help="Output CSV path.")
    args = parser.parse_args()

    customers = generate_customers(args.count)
    write_csv(customers, args.out)

    # Quick sanity check on the distribution actually produced
    tier_counts = {tier: 0 for tier in LOYALTY_TIERS}
    for c in customers:
        tier_counts[c["loyalty_tier"]] += 1
    print(f"Generated {len(customers)} customers -> {args.out}")
    print("Loyalty tier breakdown:", tier_counts)


if __name__ == "__main__":
    main()
