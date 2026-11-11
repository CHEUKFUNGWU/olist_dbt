-- The customer dimension must be one row per person: 96,096 people, not 99,441 customer_ids. Rows returned = test fails.
with dim as (

    select count(*) as n from {{ ref('dim_customers') }}

),

people as (

    select count(distinct customer_unique_id) as n from {{ ref('stg_olist__customers') }}

)

select dim.n as dim_customers_rows, people.n as distinct_people
from dim, people
where dim.n <> people.n
