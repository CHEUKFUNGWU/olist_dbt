# Olist dbt project (DuckDB)

A dbt project over the Brazilian E-Commerce Public Dataset by Olist (9 CSVs). Full design notes live in [olist_dbt_plan.md](olist_dbt_plan.md).

Status: 22 models and 5 singular tests written and structurally checked. Not executed end to end yet, because the machine used to build them has no dbt, no DuckDB and no network.

## Layout

```text
.
├── dbt_project.yml
├── profiles.yml                    # local DuckDB, no credentials
├── packages.yml                    # dbt_utils
├── load/load_raw.sql               # 9 CSVs -> raw schema
├── macros/generate_schema_name.sql # dev gets a prefix, prod gets the bare schema
├── models/
│   ├── staging/olist/              # 8 models, 1:1 with source tables
│   ├── intermediate/               # 6 models, aggregated to the target grain
│   └── marts/                      # core dims and facts + finance/ops aggregates
└── tests/                          # singular assertions and reconciliation checks
```

## Running locally

Python dependencies are managed with [uv](https://docs.astral.sh/uv/): packages and constraints live in `pyproject.toml`, exact versions in `uv.lock`. dbt packages are separate and still come from `packages.yml` via `dbt deps`.

```bash
# once
brew install uv

# 1. put the 9 Kaggle CSVs in data/ (keep the original file names)
#    https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

# 2. create .venv and install dbt-duckdb plus duckdb
uv sync

# 3. load the CSVs into DuckDB
uv run python -c "import duckdb; duckdb.connect('olist.duckdb').execute(open('load/load_raw.sql').read())"

# 4. install dbt packages, then build
uv run dbt deps --profiles-dir .
uv run dbt build --profiles-dir .
```

`uv run` executes inside the project environment, so there is nothing to activate. If you want a shell in it anyway, use `source .venv/bin/activate`.

Prefer plain pip? `pip install "dbt-duckdb>=1.11.1,<1.12"` installs the same dependency set, but you lose the lock file.

## What the loader prints

`load/load_raw.sql` ends with a row count per table. Measured on the public dataset:

| table | rows |
|---|---|
| orders | 99,441 |
| order_items | 112,650 |
| order_payments | 103,886 |
| order_reviews | 99,224 |
| customers | 99,441 |
| sellers | 3,095 |
| products | 32,951 |
| geolocation | 1,000,163 |
| category translation | 71 |

## Data facts that shaped the design

- 99,441 `customer_id` values map to 96,096 `customer_unique_id` values. 2,997 people ordered more than once, one of them 17 times. Person-level analysis needs `customer_unique_id`.
- 112,650 item rows cover 98,666 orders, and one order has 21 item rows. Payments average 1.04 rows per order but peak at 29. Joining the two details directly turns the worst order into 609 rows.
- `geolocation` holds 1,000,163 rows for 19,015 zip prefixes, about 53 rows each. It is aggregated to one row per prefix and materialised as a table.
- `review_id` is not unique in the raw data: 789 ids repeat, up to 3 rows each. Staging deduplicates to the latest row.
- The category translation CSV carries a UTF-8 BOM, so the loader reads it with explicit columns. Without that, the join fails silently and every category becomes `unknown` while `not_null` still passes. A sentinel test guards it.
- 775 orders have no item rows, 1 has no payment, 768 have no review. Facts therefore use left joins with `coalesce(..., 0)` instead of inner joins, which would drop rows.
- 2,965 orders have no delivery date. `is_late` is null for those, neither on time nor late.

## Grain map

| model | grain |
|---|---|
| `stg_olist__orders` | `order_id` |
| `stg_olist__order_items` | `order_id` + `order_item_id` |
| `stg_olist__order_payments` | `order_id` + `payment_sequential` |
| `stg_olist__order_reviews` | `review_id` (after deduplication) |
| `stg_olist__customers` | `customer_id` |
| `stg_olist__geolocation` | `zip_code_prefix` (after aggregation) |
| `fct_orders` | `order_id` |
| `fct_order_items` | `order_id` + `order_item_id` |
| `dim_customers` | `customer_unique_id` |
| `mart_finance__monthly_revenue` | `month_start` + `category_en` |
| `mart_ops__delivery_sla` | `month_start` + `state` |

## Dimensional model (Kimball)

The marts follow Kimball's dimensional approach; the full write-up is in [docs/kimball_model.md](docs/kimball_model.md).

- Every dimension has a single-column surrogate key (`customer_key`, `product_key`, `seller_key`, `date_key`) as its primary key, with the source identifier kept as an alternate key.
- `dim_dates` carries a numeric `date_key` (YYYYMMDD) and an unknown member at key 0, so lifecycle events that have not happened map to a row instead of null.
- `fct_orders` is an accumulated snapshot fact with five role-playing date keys (purchase, approval, carrier, delivery, promised). `fct_order_items` is a transaction fact with two.
- `order_id` and `order_item_id` are degenerate dimensions; product categories and coordinates are flattened into their dimensions rather than snowflaked.
- `dim_customers` and `dim_sellers` also hold derived attributes (order counts, revenue, late rate). Kimball permits this when every query needs them; the stricter alternative is a periodic snapshot fact, noted in the design doc.

## Verification

Structural checks only, run on the files: Jinja braces balanced in every file, every `ref()` resolves to an existing model, no cycles in the DAG, every model has a YAML entry with no duplicates, and no staging model references an upper layer.

Behavioural verification needs `dbt build`: the reconciliation tests (`assert_fct_orders_row_count`, `assert_payment_total_reconciles`, `assert_items_value_reconciles`, `assert_dim_customers_row_count`, `assert_category_translation_joined`) are what prove the fan-out defences hold.

## Caveats

- `database: olist` in the sources file must match the DuckDB file name `olist.duckdb`.
- The dev target uses schema `dbt_dev`, which the macro expands to `dbt_dev_staging` and `dbt_dev_marts`. Change the schema per developer.
- Olist is static historical data, so `dbt source freshness` only means something if you reload regularly.
- DuckDB has no `dbt clone`, so slim CI cannot use state-based cloning here.
