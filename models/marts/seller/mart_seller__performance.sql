-- Grain: seller_key. One row per seller, with the measures an ops team needs to rank them.
-- Review scores are attributed to every seller on the order, so a two-seller order counts
-- the same review twice across the seller population. Documented in the requirements matrix.
with items as (

    select seller_key, order_id, price, freight_value from {{ ref('fct_order_items') }}

),

seller_orders as (

    select distinct seller_key, order_id from items

),

orders as (

    select
        order_id,
        order_status,
        is_delivered,
        is_late,
        delivery_days,
        latest_review_score
    from {{ ref('fct_orders') }}

),

sellers as (

    select seller_key, seller_id, city, state from {{ ref('dim_sellers') }}

),

item_metrics as (

    select
        seller_key,
        count(*)             as item_count,
        sum(price)           as item_revenue,
        sum(freight_value)   as freight_value
    from items
    group by seller_key

),

order_metrics as (

    select
        so.seller_key,
        count(*)                                                              as order_count,
        count(*) filter (where o.order_status in ('canceled', 'unavailable')) as cancelled_orders,
        count(*) filter (where o.is_delivered)                                as delivered_orders,
        count(*) filter (where o.is_delivered and o.is_late)                  as late_orders,
        avg(case when o.is_delivered then o.delivery_days end)                as avg_delivery_days,
        count(o.latest_review_score)                                          as reviewed_orders,
        avg(o.latest_review_score)                                            as avg_review_score,
        count(*) filter (where o.latest_review_score <= 2)                    as low_score_orders
    from seller_orders so
    join orders o on so.order_id = o.order_id
    group by so.seller_key

),

final as (

    select
        s.seller_key,
        s.seller_id,
        s.city,
        s.state,

        om.order_count,
        im.item_count,
        im.item_revenue,
        im.freight_value,

        om.cancelled_orders,
        round(om.cancelled_orders * 1.0 / nullif(om.order_count, 0), 4)      as cancel_rate,

        om.delivered_orders,
        om.late_orders,
        round(om.late_orders * 1.0 / nullif(om.delivered_orders, 0), 4)      as late_rate,
        round(om.avg_delivery_days, 1)                                        as avg_delivery_days,

        om.reviewed_orders,
        round(om.avg_review_score, 2)                                         as avg_review_score,
        round(om.low_score_orders * 1.0 / nullif(om.reviewed_orders, 0), 4)  as low_score_rate,

        rank() over (order by om.late_orders * 1.0 / nullif(om.delivered_orders, 0) desc nulls last) as late_rate_rank
    from sellers s
    left join order_metrics om on s.seller_key = om.seller_key
    left join item_metrics im  on s.seller_key = im.seller_key

)

select * from final
