-- Type 2 dimension for customer geography.
--
-- Olist is a static extract with no updated_at that changes, so the check strategy is used:
-- dbt compares the tracked columns and writes a new version only when one of them changes.
-- On the first run this produces one current row per customer, which is the correct
-- behaviour for unchanging data. Change a city in raw.olist_customers_dataset, run
-- `dbt snapshot`, and a second version appears with dbt_valid_to set on the first.
{% snapshot customers_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='customer_id',
      strategy='check',
      check_cols=['zip_code_prefix', 'city', 'state']
    )
}}

select * from {{ ref('stg_olist__customers') }}

{% endsnapshot %}
