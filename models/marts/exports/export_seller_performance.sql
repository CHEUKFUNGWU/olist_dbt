-- Dashboard feed: seller scorecard for ranking and drill-down.
--
-- The scorecard itself has no time dimension, but BI and dashboard tools want a date
-- column. The feed therefore carries the latest order date in the load as a single
-- as-of point: filter on it, never trend across it.
{{ config(
    materialized='external',
    format='parquet',
    location='exports/seller_performance.parquet'
) }}

with as_of as (

    select max(d.date_day) as as_of_date
    from {{ ref('fct_orders') }} o
    join {{ ref('dim_dates') }} d on o.order_date_key = d.date_key

)

select
    p.*,
    a.as_of_date
from {{ ref('mart_seller__performance') }} p
cross join as_of a
