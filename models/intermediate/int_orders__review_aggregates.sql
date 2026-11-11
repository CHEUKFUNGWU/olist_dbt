-- An order can have several reviews: keep the latest by creation time and keep the review count.
with reviews as (

    select * from {{ ref('stg_olist__order_reviews') }}

),

ranked as (

    select
        order_id,
        review_score,
        review_created_at,
        row_number() over (
            partition by order_id
            order by review_created_at desc, review_id
        ) as rn,
        count(*) over (partition by order_id) as review_count
    from reviews

),

latest as (

    select
        order_id,
        review_score  as latest_review_score,
        review_count
    from ranked
    where rn = 1

)

select * from latest
