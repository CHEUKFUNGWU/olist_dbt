-- Dashboard feed. Writes a Parquet file and leaves a view of the same name pointing at it,
-- so the model stays queryable while the file is what a dashboard reads.
{{ config(
    materialized='external',
    format='parquet',
    location='exports/fct_orders.parquet'
) }}

select * from {{ ref('fct_orders') }}
