-- Grain: month_start + category_en. Monthly revenue for the finance view.
-- The month comes from dim_dates through the role-playing order_date_key.
with items as (

    select * from {{ ref('fct_order_items') }}

),

products as (

    select product_key, category_en from {{ ref('dim_products') }}

),

dates as (

    select date_key, month_start from {{ ref('dim_dates') }}

),

final as (

    select
        d.month_start,
        coalesce(p.category_en, 'unknown')  as category_en,
        count(distinct i.order_id)          as order_count,
        count(*)                            as item_count,
        sum(i.price)                        as revenue,
        sum(i.freight_value)                as freight_value,
        round(sum(i.price) / nullif(count(distinct i.order_id), 0), 2) as revenue_per_order
    from items i
    left join dates d    on i.order_date_key = d.date_key
    left join products p on i.product_key = p.product_key
    group by 1, 2

)

select * from final
