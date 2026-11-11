-- The raw table holds many coordinates per zip prefix (1,000,163 rows, 19,015 prefixes).
-- This aggregates rather than renames, so it is materialised as a table to avoid scanning a million rows per join.
{{ config(materialized='table') }}

with source as (

    select * from {{ source('olist', 'geolocation') }}

),

aggregated as (

    select
        lpad(cast(geolocation_zip_code_prefix as varchar), 5, '0') as zip_code_prefix,
        avg(geolocation_lat)        as latitude,
        avg(geolocation_lng)        as longitude,
        any_value(geolocation_city)  as city,
        upper(any_value(geolocation_state)) as state
    from source
    group by 1

)

select * from aggregated
