-- Seller rollup. Grain: seller_id.
-- Order-level metrics (late rate) are computed after deduplicating to seller x order, so multi-item orders are not double counted.
with items as (

    select order_id, seller_id, price, freight_value from {{ ref('stg_olist__order_items') }}

),

orders as (

    select order_id, purchased_at from {{ ref('stg_olist__orders') }}

),

delivery as (

    select order_id, is_delivered, is_late from {{ ref('int_orders__delivery') }}

),

seller_orders as (

    select distinct seller_id, order_id from items

),

order_level as (

    select
        so.seller_id,
        so.order_id,
        o.purchased_at,
        d.is_delivered,
        d.is_late
    from seller_orders so
    left join orders o    on so.order_id = o.order_id
    left join delivery d  on so.order_id = d.order_id

),

order_metrics as (

    select
        seller_id,
        count(*)          as order_count,
        min(purchased_at) as first_sold_at,
        max(purchased_at) as last_sold_at,
        avg(case when is_delivered and is_late then 1.0
                 when is_delivered then 0.0 end) as late_rate
    from order_level
    group by seller_id

),

item_metrics as (

    select
        seller_id,
        count(*)            as item_count,
        sum(price)          as gross_revenue,
        sum(freight_value)  as freight_value
    from items
    group by seller_id

)

select
    om.seller_id,
    om.order_count,
    om.first_sold_at,
    om.last_sold_at,
    om.late_rate,
    im.item_count,
    im.gross_revenue,
    im.freight_value
from order_metrics om
left join item_metrics im on om.seller_id = im.seller_id
