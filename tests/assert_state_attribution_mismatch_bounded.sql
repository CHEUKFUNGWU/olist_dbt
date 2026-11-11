-- Guards the approximation in dim_customers: it is one row per person, so order-level
-- geography is taken from the person's current state. Measured at 43 of 99,441 orders
-- (0.043%) when this test was written. A jump means addresses started changing, and the
-- marts that group by state should switch to fct_orders_customer_geography.
with m as (

    select
        count(*)                                                as orders,
        count(*) filter (where state_differs_from_person)        as mismatched,
        100.0 * count(*) filter (where state_differs_from_person) / count(*) as pct
    from {{ ref('fct_orders_customer_geography') }}

)

select orders, mismatched, round(pct, 4) as pct
from m
where pct > 0.1
