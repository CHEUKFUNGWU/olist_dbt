-- Aggregate items to order grain first so downstream joins cannot fan out.
with order_items as (

    select * from {{ ref('stg_olist__order_items') }}

),

aggregated as (

    select
        order_id,
        count(*)                    as item_count,
        count(distinct product_id)  as distinct_products,
        count(distinct seller_id)   as distinct_sellers,
        sum(price)                  as items_value,
        sum(freight_value)          as freight_value,
        min(shipping_limit_at)      as earliest_shipping_limit_at
    from order_items
    group by order_id

)

select * from aggregated
