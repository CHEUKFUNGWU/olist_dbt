with source as (

    select * from {{ source('olist', 'customers') }}

),

renamed as (

    select
        customer_id,
        customer_unique_id,
        lpad(cast(customer_zip_code_prefix as varchar), 5, '0') as zip_code_prefix,
        customer_city                                            as city,
        upper(customer_state)                                    as state
    from source

)

select * from renamed
