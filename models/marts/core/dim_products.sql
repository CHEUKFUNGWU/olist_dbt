-- Conformed product dimension. Grain: one row per product_id, 32,951 rows.
-- Primary key is the surrogate product_key; product_id is the alternate key.
-- Category attributes are flattened here rather than snowflaked into a category table.
with products as (

    select * from {{ ref('stg_olist__products') }}

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['product_id']) }} as product_key,
        product_id,
        category_pt,
        category_en,
        weight_g,
        round(weight_g / 1000.0, 3)                            as weight_kg,
        length_cm,
        height_cm,
        width_cm,
        round(length_cm * height_cm * width_cm / 1000.0, 2)     as volume_liters
    from products

)

select * from final
