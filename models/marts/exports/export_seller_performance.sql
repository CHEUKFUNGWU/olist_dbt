-- Dashboard feed: seller scorecard for ranking and drill-down.
{{ config(
    materialized='external',
    format='parquet',
    location='exports/seller_performance.parquet'
) }}

select * from {{ ref('mart_seller__performance') }}
