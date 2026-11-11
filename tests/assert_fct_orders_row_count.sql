-- Grain assertion: fct_orders must match the row count of the orders table. Rows returned = test fails.
with fct as (
    select count(*) as n from {{ ref('fct_orders') }}
),

stg as (
    select count(*) as n from {{ ref('stg_olist__orders') }}
)

select fct.n as fct_orders_rows, stg.n as stg_orders_rows
from fct, stg
where fct.n <> stg.n
