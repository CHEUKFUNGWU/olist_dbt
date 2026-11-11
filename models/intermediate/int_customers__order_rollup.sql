-- Customer rollup. Grain: customer_unique_id (person), not customer_id.
-- 99,441 customer_ids map to 96,096 people; 2,997 people ordered more than once (max 17 orders).
with orders as (

    select order_id, customer_id, purchased_at from {{ ref('stg_olist__orders') }}

),

customers as (

    select customer_id, customer_unique_id, zip_code_prefix, city, state
    from {{ ref('stg_olist__customers') }}

),

payments as (

    select order_id, payment_total from {{ ref('int_orders__payment_aggregates') }}

),

reviews as (

    select order_id, latest_review_score from {{ ref('int_orders__review_aggregates') }}

),

enriched as (

    select
        c.customer_unique_id,
        c.zip_code_prefix,
        c.city,
        c.state,
        o.order_id,
        o.purchased_at,
        coalesce(p.payment_total, 0) as payment_total,
        r.latest_review_score
    from orders o
    join customers c        on o.customer_id = c.customer_id
    left join payments p    on o.order_id = p.order_id
    left join reviews r     on o.order_id = r.order_id

),

ranked as (

    select
        *,
        row_number() over (
            partition by customer_unique_id
            order by purchased_at desc, order_id desc
        ) as rn
    from enriched

),

aggregated as (

    select
        customer_unique_id,
        count(*)                 as order_count,
        min(purchased_at)        as first_order_at,
        max(purchased_at)        as last_order_at,
        sum(payment_total)       as lifetime_value,
        avg(payment_total)       as avg_order_value,
        avg(latest_review_score) as avg_review_score,
        -- city/state from the most recent order; people move
        max(case when rn = 1 then zip_code_prefix end) as zip_code_prefix,
        max(case when rn = 1 then city end)            as city,
        max(case when rn = 1 then state end)           as state
    from ranked
    group by customer_unique_id

)

select * from aggregated
