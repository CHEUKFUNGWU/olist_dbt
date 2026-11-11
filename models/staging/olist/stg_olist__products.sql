with products as (

    select * from {{ source('olist', 'products') }}

),

translation as (

    select * from {{ source('olist', 'category_translation') }}

),

renamed as (

    select
        p.product_id,
        p.product_category_name                        as category_pt,
        coalesce(t.product_category_name_english, 'unknown') as category_en,
        cast(p.product_weight_g as integer)            as weight_g,
        cast(p.product_length_cm as integer)           as length_cm,
        cast(p.product_height_cm as integer)           as height_cm,
        cast(p.product_width_cm as integer)            as width_cm
    from products p
    left join translation t
        on p.product_category_name = t.product_category_name

)

select * from renamed
