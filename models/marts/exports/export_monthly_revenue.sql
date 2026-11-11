-- Dashboard feed: monthly revenue by category, already aggregated.
-- Dashboards should read this rather than fct_order_items.
{{ config(
    materialized='external',
    format='parquet',
    location='exports/monthly_revenue.parquet'
) }}

select * from {{ ref('mart_finance__monthly_revenue') }}
