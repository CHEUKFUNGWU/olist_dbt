-- Dashboard feed. Writes a Parquet file and leaves a view of the same name pointing at it,
-- so the model stays queryable while the file is what a dashboard reads.
--
-- The feed is deliberately wider than fct_orders. A dashboard or a Semantic Layer tool
-- cannot join dimensions itself, so it gets a real order date instead of the integer key,
-- the customer's state, and 0/1 flags it can sum into rates. The star keeps the integer
-- keys and the boolean flags; only this denormalised copy carries the extras.
{{ config(
    materialized='external',
    format='parquet',
    location='exports/fct_orders.parquet'
) }}

select
    o.*,

    d.date_day as order_date,
    c.state    as customer_state,

    case when o.is_late then 1 else 0 end                         as late_flag,
    case when o.is_delivered then 1 else 0 end                    as delivered_flag,
    case when o.latest_review_score is not null then 1 else 0 end as reviewed_flag,
    case when o.latest_review_score <= 2 then 1 else 0 end        as low_score_flag

from {{ ref('fct_orders') }} o
left join {{ ref('dim_dates') }} d     on o.order_date_key = d.date_key
left join {{ ref('dim_customers') }} c on o.customer_key = c.customer_key
