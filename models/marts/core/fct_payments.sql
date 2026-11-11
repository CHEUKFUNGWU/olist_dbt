-- Transaction fact. Grain: one row per payment (order_id + payment_sequential), 103,886 rows.
-- The payments table carries no timestamp, so order_date_key uses the order purchase date as a proxy.
{{ config(materialized='table') }}

with payments as (

    select * from {{ ref('stg_olist__order_payments') }}

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

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['p.order_id', 'p.payment_sequential']) }} as payment_key,

        p.order_id,
        p.payment_sequential,

        dc.customer_key,
        cast(strftime(o.purchased_at, '%Y%m%d') as integer) as order_date_key,

        p.payment_type,
        p.payment_installments,
        p.payment_value
    from payments p
    left join orders o         on p.order_id = o.order_id
    left join customers c      on o.customer_id = c.customer_id
    left join dim_customers dc on c.customer_unique_id = dc.customer_unique_id

)

select * from final