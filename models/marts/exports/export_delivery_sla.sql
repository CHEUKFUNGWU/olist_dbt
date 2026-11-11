-- Dashboard feed: delivery performance by month and state.
{{ config(
    materialized='external',
    format='parquet',
    location='exports/delivery_sla.parquet'
) }}

select * from {{ ref('mart_ops__delivery_sla') }}
