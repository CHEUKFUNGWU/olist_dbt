-- Amount assertion: order-level item totals must equal the sum of item prices.
with fct as (
    select sum(items_value) as total from {{ ref('fct_orders') }}
),

items as (
    select sum(price) as total from {{ ref('stg_olist__order_items') }}
)

select fct.total as fct_items_value, items.total as stg_items_value
from fct, items
where abs(coalesce(fct.total, 0) - coalesce(items.total, 0)) > 0.01
