-- Transaction fact. Grain: one row per order line (order_id + order_item_id), 112,650 rows.
-- Surrogate dimension keys plus two role-playing date keys; order_id and order_item_id are
-- degenerate dimensions. Static historical data, so full rebuild as a table.
{{ config(materialized='table') }}

with items as (

    select * from {{ ref('stg_olist__order_items') }}

),

orders as (

    select order_id, customer_id, purchased_at from {{ ref('stg_olist__orders') }}

),

customers as (

    select customer_id, customer_unique_id from {{ ref('stg_olist__customers') }}

),

dim_customers as (

    select customer_unique_id, customer_key from {{ ref('dim_customers') }}

),

dim_products as (

    select product_id, product_key from {{ ref('dim_products') }}

),

dim_sellers as (

    select seller_id, seller_key from {{ ref('dim_sellers') }}

),

delivery as (

    select order_id, is_late from {{ ref('int_orders__delivery') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['i.order_id', 'i.order_item_id']) }} as order_item_key,

        i.order_id,
        i.order_item_id,

        dc.customer_key,
        dp.product_key,
        ds.seller_key,

        cast(strftime(o.purchased_at, '%Y%m%d') as integer)                       as order_date_key,
        coalesce(cast(strftime(i.shipping_limit_at, '%Y%m%d') as integer), 0)      as shipping_limit_date_key,

        1                    as quantity,
        i.price,
        i.freight_value,
        d.is_late
    from items i
    left join orders o        on i.order_id = o.order_id
    left join customers c     on o.customer_id = c.customer_id
    left join dim_customers dc on c.customer_unique_id = dc.customer_unique_id
    left join dim_products dp on i.product_id = dp.product_id
    left join dim_sellers ds  on i.seller_id = ds.seller_id
    left join delivery d      on i.order_id = d.order_id

)

select * from final
