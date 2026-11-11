# Olist dbt project (DuckDB)

A dbt project over the Brazilian E-Commerce Public Dataset by Olist (9 CSVs). Full design notes live in [olist_dbt_plan.md](olist_dbt_plan.md).

Status: 32 models, 180 data tests, 1 unit test and 1 snapshot, green end to end. `dbt build` passes all 214 nodes on DuckDB in a few seconds; see [Verification](#verification).

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
│   └── marts/                      # core dims and facts, finance/ops/seller/cx aggregates, parquet exports
├── dashboards/                     # dashboard definitions over the Parquet feeds
├── snapshots/                      # Type 2 history for customer geography
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

The marts follow Kimball's dimensional approach; the full write-up is in [docs/kimball_model.md](docs/kimball_model.md) the entity relationships are drawn in [docs/erd.md](docs/erd.md), every metric is defined in [docs/metric_dictionary.md](docs/metric_dictionary.md), and the Semantic Layer definitions drafted from it sit in [docs/semantic_layer_draft.yml](docs/semantic_layer_draft.yml).

- Every dimension has a single-column surrogate key (`customer_key`, `product_key`, `seller_key`, `date_key`) as its primary key, with the source identifier kept as an alternate key.
- `dim_dates` carries a numeric `date_key` (YYYYMMDD) and an unknown member at key 0, so lifecycle events that have not happened map to a row instead of null.
- `fct_orders` is an accumulated snapshot fact with five role-playing date keys (purchase, approval, carrier, delivery, promised). `fct_order_items` is a transaction fact with two.
- `order_id` and `order_item_id` are degenerate dimensions; product categories and coordinates are flattened into their dimensions rather than snowflaked.
- `dim_customers` and `dim_sellers` also hold derived attributes (order counts, revenue, late rate). Kimball permits this when every query needs them; the stricter alternative is a periodic snapshot fact, noted in the design doc.

## Verification

`uv run dbt build --profiles-dir .` builds every model, runs the full test suite, the unit test and the snapshot, and completes green.

The last full run on dbt 1.12.6 with the DuckDB adapter: `PASS=214 WARN=0 ERROR=0 SKIP=0` — 32 models, 180 data tests, 1 unit test and 1 snapshot, in under five seconds.

- **Contracts** are enforced on `dim_customers`, `fct_orders`, `fct_order_items` and `fct_payments`: every column is declared with its data type, and each model carries a `primary_key` constraint. A column rename or type drift fails the build.
- **Unit test** `is_late_covers_late_on_time_and_undelivered` pins three fixtures against `int_orders__delivery`: late, on time, and never delivered.
- **Snapshot** `customers_snapshot` gives customer geography a Type 2 history; run `uv run dbt snapshot --profiles-dir .` to write it.
- **Reconciliation tests** (`assert_fct_orders_row_count`, `assert_payment_total_reconciles`, `assert_items_value_reconciles`, `assert_dim_customers_row_count`, `assert_category_translation_joined`) are what prove the fan-out defences hold.

## Dashboard feed (Parquet)

Six models under `models/marts/exports/` publish the tables a dashboard needs as Parquet files, so the dashboard does not need the `.duckdb` file at all:

| File | Content | Grain |
|---|---|---|
| `exports/fct_orders.parquet` | orders with delivery and payment measures | order |
| `exports/monthly_revenue.parquet` | revenue by month and category | month + category |
| `exports/delivery_sla.parquet` | delivery performance by month and state | month + state |
| `exports/payment_mix.parquet` | payment method and installment share | month + payment type |
| `exports/review_delivery.parquet` | review outcome against lateness | month + is_late |
| `exports/seller_performance.parquet` | seller scorecard for ranking and drill-down | seller |

They use dbt-duckdb's `external` materialization: dbt writes the file and leaves a view of the same name pointing at it, so `ref()` still works in dbt while a dashboard reads the file directly.

Any tool that speaks DuckDB can read them, and so can pandas, Polars or Spark:

```sql
select month_start, sum(revenue) as revenue
from 'exports/monthly_revenue.parquet'
group by 1
order by 1;
```

Two feeds are deliberately wider than the table they copy, because a dashboard cannot join dimensions itself:

- `export_fct_orders` adds a real `order_date` (from `dim_dates`), `customer_state` (from `dim_customers`) and four 0/1 flags (`late_flag`, `delivered_flag`, `reviewed_flag`, `low_score_flag`) so rates can be summed instead of averaged
- `export_seller_performance` adds `as_of_date`, the latest order date in the load. The scorecard has no time dimension, so this is a single as-of point: filter on it, never trend across it

`exports/` is gitignored: the files are rebuilt by `dbt build` and should never be committed.

## Dashboards

Three dashboards read the feeds directly; the definitions live in `dashboards/` and hold no data of their own. The file names come from the dashboard tool and must not be renamed: the app finds a dashboard by its path, so a rename leaves the card pointing at nothing. The readable name is the dashboard's title.

| File | Source feed | Answers |
|---|---|---|
| `dashboards/dashboard.dashboard.json` | `fct_orders.parquet` | revenue and orders over time, late rate by state, whether lateness drags the review score |
| `dashboards/dashboard-2.dashboard.json` | `payment_mix.parquet` | how people pay, and how much of it is in installments |
| `dashboards/dashboard-3.dashboard.json` | `seller_performance.parquet` | which sellers carry the late and cancelled orders |

One dashboard reads one file, so the six analyses split across grains. Row-level order drill-down is the exception: a dashboard widget aggregates, so inspecting a single order means querying `exports/fct_orders.parquet` directly.

## Caveats

- `database: olist` in the sources file must match the DuckDB file name `olist.duckdb`.
- The dev target uses schema `dbt_dev`, which the macro expands to `dbt_dev_staging` and `dbt_dev_marts`. Change the schema per developer.
- Olist is static historical data, so `dbt source freshness` only means something if you reload regularly.
- DuckDB has no `dbt clone`, so slim CI cannot use state-based cloning here.
