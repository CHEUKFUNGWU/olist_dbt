-- Delivery definitions live here. Anything computing lateness reuses this model.
-- Note: DuckDB and Snowflake use datediff('day', start, end); BigQuery uses date_diff(end, start, day), reversed.
with orders as (

    select * from {{ ref('stg_olist__orders') }}

),

metrics as (

    select
        order_id,
        purchased_at,
        estimated_delivery_at,
        delivered_to_customer_at,

        case
            when delivered_to_customer_at is not null then true
            else false
        end as is_delivered,

        datediff('day', purchased_at, delivered_to_customer_at) as delivery_days,
        datediff('day', purchased_at, estimated_delivery_at)    as estimated_days,

        case
            when delivered_to_customer_at is null then null
            when delivered_to_customer_at > estimated_delivery_at then true
            else false
        end as is_late,

        case
            when delivered_to_customer_at is null then null
            when delivered_to_customer_at > estimated_delivery_at
                then datediff('day', estimated_delivery_at, delivered_to_customer_at)
            else 0
        end as days_late
    from orders

)

select * from metrics
