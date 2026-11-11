-- Dashboard feed: review outcome against delivery lateness by month.
{{ config(
    materialized='external',
    format='parquet',
    location='exports/review_delivery.parquet'
) }}

select * from {{ ref('mart_cx__review_delivery') }}
