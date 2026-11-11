-- Conformed seller dimension. Grain: one row per seller_id, 3,095 rows.
-- Primary key is the surrogate seller_key; seller_id is the alternate key.
with sellers as (

    select * from {{ ref('stg_olist__sellers') }}

),

rollup as (

    select * from {{ ref('int_sellers__order_rollup') }}

),

geo as (

    select zip_code_prefix, latitude, longitude from {{ ref('stg_olist__geolocation') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['s.seller_id']) }} as seller_key,
        s.seller_id,
        s.city,
        s.state,
        s.zip_code_prefix,
        g.latitude,
        g.longitude,
        coalesce(r.order_count, 0)    as order_count,
        coalesce(r.item_count, 0)     as item_count,
        coalesce(r.gross_revenue, 0)  as gross_revenue,
        r.late_rate,
        r.first_sold_at,
        r.last_sold_at
    from sellers s
    left join rollup r on s.seller_id = r.seller_id
    left join geo g    on s.zip_code_prefix = g.zip_code_prefix

)

select * from final
