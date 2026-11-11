-- Conformed customer dimension. Grain: one row per person (customer_unique_id), 96,096 rows.
-- Primary key is the surrogate customer_key; customer_unique_id is the alternate key.
with customers as (

    select * from {{ ref('int_customers__order_rollup') }}

),

geo as (

    select zip_code_prefix, latitude, longitude from {{ ref('stg_olist__geolocation') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['c.customer_unique_id']) }} as customer_key,
        c.customer_unique_id,
        c.city,
        c.state,
        c.zip_code_prefix,
        g.latitude,
        g.longitude,
        c.first_order_at,
        c.last_order_at,
        c.order_count,
        case
            when c.order_count > 1 then 'repeat'
            else 'one_time'
        end as customer_segment,
        c.lifetime_value,
        c.avg_order_value,
        c.avg_review_score
    from customers c
    left join geo g on c.zip_code_prefix = g.zip_code_prefix

)

select * from final
