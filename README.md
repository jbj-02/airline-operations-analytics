# Airline Operations Analytics

An end-to-end analytics project combining **real U.S. flight data** from the
Bureau of Transportation Statistics (BTS) with **synthetic commercial data**
(customers, bookings, ticket pricing) to simulate what an airline's internal
operational + commercial database might look like.

## Project Narrative

Built an airline operations analytics platform using real U.S. flight data
from the Bureau of Transportation Statistics. Designed a PostgreSQL database,
wrote advanced SQL to analyze profitability and delays, and built an
executive Power BI dashboard identifying operational bottlenecks and revenue
opportunities.

## Data Sources

- **Real:** BTS Reporting Carrier On-Time Performance data, full year 2024,
  all U.S. carriers. Source: https://www.transtats.bts.gov
- **Reference:** US airport metadata via the `airportsdata` Python package.
- **Synthetic:** Customers, bookings, and ticket pricing, generated to be
  internally consistent with the real flight data (see `python/` scripts
  for the generation logic and design rationale).

## Schema

| Table | Source | Description |
|---|---|---|
| `airports` | Real (reference) | Airport metadata |
| `aircraft` | Heuristic | Seat capacity derived from tail number's typical route distance |
| `flights` | Real (BTS) | One row per flight, 2024 |
| `customers` | Synthetic | Weighted loyalty tier distribution |
| `ticket_classes` | Static reference | Economy / Premium Economy / Business |
| `bookings` | Synthetic, tied to real flights | Distance-based pricing, loyalty-correlated behavior |

Full DDL: [`sql/schema.sql`](sql/schema.sql)

## Setup

1. Install PostgreSQL + pgAdmin 4.
2. Create a database, then run:
   ```bash
   psql -d your_db -f sql/schema.sql
   ```
3. Download 2024 BTS Reporting Carrier On-Time Performance data (all 12
   months) from TranStats and place the raw CSVs in `data/raw/`.
4. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```
5. Run the ETL pipeline to load real data + reference tables:
   ```bash
   python python/etl.py --db-url postgresql://user:pass@localhost/your_db
   ```
6. Generate synthetic customers and bookings:
   ```bash
   python python/generate_customers.py --count 20000 --out data/processed/customers.csv
   # load customers.csv into the customers table, then:
   python python/generate_bookings.py --db-url postgresql://user:pass@localhost/your_db
   ```
7. Run the analysis queries in `sql/business_questions.sql`, build views in
   `sql/views.sql`, and connect Power BI to the database for the dashboard.

## Business Questions Answered

See [`sql/business_questions.sql`](sql/business_questions.sql) for the full
list, covering revenue, operations, fleet utilization, customer analytics,
and strategic recommendations.

## SQL Skills Demonstrated

JOINs, CTEs, window functions (RANK, DENSE_RANK, ROW_NUMBER, LAG, LEAD),
CASE expressions, GROUP BY / HAVING, views, indexes, and aggregate functions.

## Repository Structure

```
airline-operations-analytics/
├── data/
│   ├── raw/            # Raw BTS monthly CSVs (not committed — see .gitignore)
│   └── processed/      # Generated synthetic data
├── sql/
│   ├── schema.sql
│   ├── import_data.sql
│   ├── business_questions.sql
│   └── views.sql
├── python/
│   ├── generate_customers.py
│   ├── generate_bookings.py
│   └── etl.py
├── dashboard/
│   └── AirlineDashboard.pbix
├── images/
└── README.md
```
