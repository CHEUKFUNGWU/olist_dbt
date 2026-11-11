-- Sentinel test for the translation join: the CSV header carries a BOM, so a column name mismatch makes the join fail silently and
-- every category silently becomes 'unknown' while the not_null test still passes.
-- Fewer than 10 distinct categories means the translation join is broken. Rows returned = test fails.
with categories as (

    select count(distinct category_en) as n
    from {{ ref('stg_olist__products') }}

)

select n as distinct_categories
from categories
where n < 10
