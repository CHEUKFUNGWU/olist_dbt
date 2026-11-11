-- Aggregate payments to order grain first. Joining the detail inflates amounts because one order can have several payments.
with payments as (

    select * from {{ ref('stg_olist__order_payments') }}

),

totals as (

    select
        order_id,
        sum(payment_value)        as payment_total,
        count(*)                  as payment_count,
        max(payment_installments) as max_installments
    from payments
    group by order_id

),

types as (

    select
        order_id,
        string_agg(payment_type, ', ' order by payment_type) as payment_types
    from (
        select distinct order_id, payment_type from payments
    )
    group by order_id

)

select
    t.order_id,
    t.payment_total,
    t.payment_count,
    t.max_installments,
    ty.payment_types
from totals t
left join types ty
    on t.order_id = ty.order_id
