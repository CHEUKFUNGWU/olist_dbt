-- review_id repeats in the raw data (789 ids, up to 3 rows each) and one order_id can have several reviews.
-- Deduplicate by review_id, keeping the latest row; order-grain aggregation happens in int_orders__review_aggregates.
with source as (

    select * from {{ source('olist', 'order_reviews') }}

),

renamed as (

    select
        review_id,
        order_id,
        cast(review_score as integer)              as review_score,
        cast(review_creation_date as timestamp)    as review_created_at,
        cast(review_answer_timestamp as timestamp) as review_answered_at,
        review_comment_title,
        review_comment_message
    from source

),

ranked as (

    select
        *,
        row_number() over (
            partition by review_id
            order by review_created_at desc, order_id
        ) as rn
    from renamed

)

select
    review_id,
    order_id,
    review_score,
    review_created_at,
    review_answered_at,
    review_comment_title,
    review_comment_message
from ranked
where rn = 1
