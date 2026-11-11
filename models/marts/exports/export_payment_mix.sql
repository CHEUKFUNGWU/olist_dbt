-- Dashboard feed: payment method and installment mix by month.
{{ config(
    materialized='external',
    format='parquet',
    location='exports/payment_mix.parquet'
) }}

select * from {{ ref('mart_finance__payment_mix') }}
