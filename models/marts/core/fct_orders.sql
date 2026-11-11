-- Accumulated snapshot fact. Grain: one row per order, 99,441 rows.
-- Five role-playing date keys point at dim_dates: purchase, approval, carrier handover,
-- delivery and the promised date. Events that have not happened map to the unknown
-- member (0) rather than null, so every foreign key is populated.
with orders as (

    select * from {{ ref('stg_olist__orders') }}

),

items as (

    select * from {{ ref('int_orders__item_aggregates') }}

),

payments as (

    select * from {{ ref('int_orders__payment_aggregates') }}

),

reviews as (

    select * from {{ ref('int_orders__review_aggregates') }}

),

delivery as (

    select * from {{ ref('int_orders__delivery') }}

),

customers as (

    select customer_id, customer_unique_id from {{ ref('stg_olist__customers') }}

),

dim_customers as (

    select customer_unique_id, customer_key from {{ ref('dim_customers') }}

),

joined as (

    select
        o.order_id,
        dc.customer_key,
        o.customer_id,

        cast(strftime(o.purchased_at, '%Y%m%d') as integer)                       as order_date_key,
        coalesce(cast(strftime(o.approved_at, '%Y%m%d') as integer), 0)            as approved_date_key,
        coalesce(cast(strftime(o.handed_to_carrier_at, '%Y%m%d') as integer), 0)   as carrier_date_key,
        coalesce(cast(strftime(o.delivered_to_customer_at, '%Y%m%d') as integer), 0) as delivered_date_key,
        coalesce(cast(strftime(o.estimated_delivery_at, '%Y%m%d') as integer), 0)  as estimated_date_key,

        o.order_status,
        d.is_delivered,
        d.is_late,
        d.delivery_days,
        d.estimated_days,
        d.days_late,

        coalesce(i.item_count, 0)        as item_count,
        coalesce(i.distinct_products, 0) as distinct_products,
        coalesce(i.distinct_sellers, 0)  as distinct_sellers,
        coalesce(i.items_value, 0)       as items_value,
        coalesce(i.freight_value, 0)     as freight_value,

        coalesce(p.payment_total, 0)     as payment_total,
        coalesce(p.payment_count, 0)     as payment_count,
        p.max_installments,
        p.payment_types,

        r.latest_review_score,
        coalesce(r.review_count, 0)      as review_count
    from orders o
    left join customers c     on o.customer_id = c.customer_id
    left join dim_customers dc on c.customer_unique_id = dc.customer_unique_id
    left join items i         on o.order_id = i.order_id
    left join payments p      on o.order_id = p.order_id
    left join reviews r       on o.order_id = r.order_id
    left join delivery d      on o.order_id = d.order_id

)

select * from joined
