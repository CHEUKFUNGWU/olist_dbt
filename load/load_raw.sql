-- Load the nine Kaggle CSVs as-is into DuckDB's raw schema, with a _loaded_at stamp.
--
-- Usage (from the project root):
--   duckdb olist.duckdb < load/load_raw.sql
-- Prerequisite: the CSVs are in data/ with their original Kaggle file names.

create schema if not exists raw;

create or replace table raw.olist_orders_dataset as
select *, current_timestamp as _loaded_at
from read_csv_auto('data/olist_orders_dataset.csv', header = true);

create or replace table raw.olist_order_items_dataset as
select *, current_timestamp as _loaded_at
from read_csv_auto('data/olist_order_items_dataset.csv', header = true);

create or replace table raw.olist_order_payments_dataset as
select *, current_timestamp as _loaded_at
from read_csv_auto('data/olist_order_payments_dataset.csv', header = true);

create or replace table raw.olist_order_reviews_dataset as
select *, current_timestamp as _loaded_at
from read_csv_auto('data/olist_order_reviews_dataset.csv', header = true);

create or replace table raw.olist_customers_dataset as
select *, current_timestamp as _loaded_at
from read_csv_auto('data/olist_customers_dataset.csv', header = true);

create or replace table raw.olist_sellers_dataset as
select *, current_timestamp as _loaded_at
from read_csv_auto('data/olist_sellers_dataset.csv', header = true);

create or replace table raw.olist_products_dataset as
select *, current_timestamp as _loaded_at
from read_csv_auto('data/olist_products_dataset.csv', header = true);

create or replace table raw.olist_geolocation_dataset as
select *, current_timestamp as _loaded_at
from read_csv_auto('data/olist_geolocation_dataset.csv', header = true);

-- Note: this CSV header carries a UTF-8 BOM, so read_csv_auto names the column "\ufeffproduct_category_name",
-- The join would then fail silently and every category would become 'unknown'. Read with explicit columns to bypass the BOM.
create or replace table raw.product_category_name_translation as
select *, current_timestamp as _loaded_at
from read_csv(
    'data/product_category_name_translation.csv',
    header = true,
    columns = {'product_category_name': 'VARCHAR', 'product_category_name_english': 'VARCHAR'}
);

-- Post-load check: all nine tables should have rows
select 'orders' as table_name, count(*) as row_count from raw.olist_orders_dataset
union all select 'order_items', count(*) from raw.olist_order_items_dataset
union all select 'order_payments', count(*) from raw.olist_order_payments_dataset
union all select 'order_reviews', count(*) from raw.olist_order_reviews_dataset
union all select 'customers', count(*) from raw.olist_customers_dataset
union all select 'sellers', count(*) from raw.olist_sellers_dataset
union all select 'products', count(*) from raw.olist_products_dataset
union all select 'geolocation', count(*) from raw.olist_geolocation_dataset
union all select 'category_translation', count(*) from raw.product_category_name_translation
order by 1;
