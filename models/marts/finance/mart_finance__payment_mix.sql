-- Grain: month_start + payment_type. Cash flow shape: how people pay, and how much of it is paid in installments.
with payments as (

    select
        order_date_key,
        order_id,
        payment_type,
        payment_installments,
        payment_value
    from {{ ref('fct_payments') }}

),

dates as (

    select date_key, month_start from {{ ref('dim_dates') }}

),

grouped as (

    select
        d.month_start,
        p.payment_type,
        count(*)                                                              as payment_count,
        count(distinct p.order_id)                                            as order_count,
        sum(p.payment_value)                                                  as payment_value,
        round(avg(p.payment_installments), 2)                                 as avg_installments,
        count(*) filter (where p.payment_installments > 1)                    as installment_payments
    from payments p
    join dates d on p.order_date_key = d.date_key
    group by 1, 2

),

final as (

    select
        month_start,
        payment_type,
        payment_count,
        order_count,
        round(payment_value, 2)                                               as payment_value,
        round(100.0 * payment_value / sum(payment_value) over (partition by month_start), 2) as pct_of_month,
        avg_installments,
        installment_payments,
        round(100.0 * installment_payments / nullif(payment_count, 0), 2)      as pct_installments
    from grouped

)

select * from final
