-- Conformed date dimension. Surrogate key date_key = YYYYMMDD as an integer.
-- Carries the Kimball unknown member (date_key = 0) so lifecycle dates that have not
-- happened yet map to a real row instead of null.
-- Bounds cover every date column the facts use, plus padding:
--   earliest purchase          2016-09-04
--   latest estimated delivery  2018-11-12
--   latest shipping limit      2020-04-09  (a handful of outlier rows)
-- The relationships tests on the date keys fail loudly if a future load falls outside.
{{ config(materialized='table') }}

with spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2016-09-01' as date)",
        end_date="cast('2021-01-01' as date)"
    ) }}

),

calendar as (

    select
        cast(strftime(date_day, '%Y%m%d') as integer)  as date_key,
        date_day::date                                 as date_day,
        extract(year from date_day)                    as year,
        extract(quarter from date_day)                 as quarter,
        extract(month from date_day)                   as month,
        strftime(date_day, '%B')                       as month_name,
        date_trunc('month', date_day)                  as month_start,
        extract(day from date_day)                     as day_of_month,
        extract(dow from date_day)                     as day_of_week,
        strftime(date_day, '%A')                       as day_name,
        case when extract(dow from date_day) in (0, 6) then true else false end as is_weekend
    from spine

),

unknown_member as (

    select
        0                          as date_key,
        cast('1900-01-01' as date) as date_day,
        1900                       as year,
        0                          as quarter,
        0                          as month,
        'Unknown'                  as month_name,
        cast('1900-01-01' as date) as month_start,
        0                          as day_of_month,
        0                          as day_of_week,
        'Unknown'                  as day_name,
        false                      as is_weekend

),

final as (

    select * from calendar
    union all
    select * from unknown_member

)

select * from final
