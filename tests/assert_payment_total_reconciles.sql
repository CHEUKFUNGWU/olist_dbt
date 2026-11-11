-- Amount assertion: order-level payment totals must equal the sum of the payments table. Fan-out or filtering bugs surface here.
with fct as (
    select sum(payment_total) as total from {{ ref('fct_orders') }}
),

payments as (
    select sum(payment_value) as total from {{ ref('stg_olist__order_payments') }}
)

select fct.total as fct_payment_total, payments.total as stg_payment_total
from fct, payments
where abs(coalesce(fct.total, 0) - coalesce(payments.total, 0)) > 0.01
