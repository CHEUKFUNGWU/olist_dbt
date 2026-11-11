-- Grain: month_start + is_late. Answers whether late delivery is what drives bad reviews.
-- Only delivered orders appear: is_late is null for undelivered ones, so they have no side.
with orders as (

    select
        order_date_key,
        is_delivered,
        is_late,
        delivery_days,
        latest_review_score
    from {{ ref('fct_orders') }}
    where is_delivered

),

dates as (

    select date_key, month_start from {{ ref('dim_dates') }}

),

final as (

    select
        d.month_start,
        o.is_late,
        count(*)                                                              as orders,
        count(o.latest_review_score)                                          as reviewed_orders,
        round(avg(o.latest_review_score), 2)                                  as avg_review_score,
        count(*) filter (where o.latest_review_score <= 2)                    as low_score_orders,
        round(
            count(*) filter (where o.latest_review_score <= 2) * 1.0
            / nullif(count(o.latest_review_score), 0), 4
        )                                                                     as low_score_rate,
        round(avg(o.delivery_days), 1)                                        as avg_delivery_days
    from orders o
    join dates d on o.order_date_key = d.date_key
    group by 1, 2

)

select * from final
