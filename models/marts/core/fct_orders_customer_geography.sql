-- Grain: one row per order. The customer's state as recorded on the order itself.
--
-- fct_orders joins dim_customers, which is one row per person, so any state rollup answers
-- "where does this person live now", not "where was this order shipped". The customers
-- snapshot is keyed by customer_id, which in Olist is order-scoped, so it keeps the address
-- recorded with each order. This model puts both next to each other and flags the difference.
--
-- The snapshot cannot reconstruct history before its first run: the source carries no
-- change timestamp, so a version's dbt_valid_from is the run that first saw it. That is why
-- this model takes the earliest recorded version rather than filtering on the order date.
with orders as (

    select order_id, order_date_key, customer_key, customer_id from {{ ref('fct_orders') }}

),

dates as (

    select date_key, date_day from {{ ref('dim_dates') }}

),

people as (

    select customer_key, state as person_state from {{ ref('dim_customers') }}

),

order_address as (

    select
        customer_id,
        state         as order_state,
        dbt_valid_from as order_state_recorded_at
    from {{ ref('customers_snapshot') }}
    qualify row_number() over (partition by customer_id order by dbt_valid_from) = 1

),

final as (

    select
        o.order_id,
        d.date_day                                        as order_date,
        o.customer_key,
        o.customer_id,
        p.person_state,
        a.order_state,
        a.order_state_recorded_at,
        case when p.person_state <> a.order_state then true else false end as state_differs_from_person
    from orders o
    left join dates d         on o.order_date_key = d.date_key
    left join people p        on o.customer_key = p.customer_key
    left join order_address a on o.customer_id = a.customer_id

)

select * from final
