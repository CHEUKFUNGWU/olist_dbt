-- Grain: month_start + state. Delivery performance for the ops view.
-- Month comes from dim_dates via order_date_key; state comes from dim_customers via customer_key.
--
-- late_rate ships with both of its components. A stored rate cannot be re-aggregated
-- (summing or averaging late_rate across months gives the wrong number), so anyone rolling
-- this table up sums late_orders and delivered_orders first and divides after.
with orders as (

    select * from {{ ref('fct_orders') }}

),

customers as (

    select customer_key, state from {{ ref('dim_customers') }}

),

dates as (

    select date_key, month_start from {{ ref('dim_dates') }}

),

final as (

    select
        d.month_start,
        c.state,
        count(*)                                                        as order_count,
        sum(case when o.is_delivered then 1 else 0 end)                 as delivered_orders,
        sum(case when o.is_delivered and o.is_late then 1 else 0 end)   as late_orders,
        round(avg(case when o.is_delivered then o.delivery_days end), 1) as avg_delivery_days,
        round(
            sum(case when o.is_delivered and o.is_late then 1 else 0 end) * 1.0
            / nullif(sum(case when o.is_delivered then 1 else 0 end), 0), 3
        )                                                               as late_rate
    from orders o
    left join dates d     on o.order_date_key = d.date_key
    left join customers c on o.customer_key = c.customer_key
    group by 1, 2

)

select * from final
