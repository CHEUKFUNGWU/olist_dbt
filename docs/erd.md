# Entity relationship diagram

Two views of the marts: the star that holds the dimensional core, and the aggregates built on top of it. Cardinality reads as `one dimension row` to `many fact rows`.

---

## 1. Star schema

```mermaid
erDiagram
    dim_customers {
        string customer_key PK
        string customer_unique_id UK
        string city
        string state
        string zip_code_prefix
        double latitude
        double longitude
        timestamp first_order_at
        timestamp last_order_at
        int order_count
        string customer_segment
        decimal lifetime_value
    }

    dim_products {
        string product_key PK
        string product_id UK
        string category_pt
        string category_en
        int weight_g
        decimal weight_kg
        decimal volume_liters
    }

    dim_sellers {
        string seller_key PK
        string seller_id UK
        string city
        string state
        string zip_code_prefix
        int order_count
        decimal gross_revenue
        double late_rate
    }

    dim_dates {
        int date_key PK
        date date_day UK
        int year
        int quarter
        int month
        string month_name
        date month_start
        int day_of_week
        boolean is_weekend
    }

    fct_orders {
        string order_id PK
        string customer_key FK
        string customer_id
        int order_date_key FK
        int approved_date_key FK
        int carrier_date_key FK
        int delivered_date_key FK
        int estimated_date_key FK
        string order_status
        decimal payment_total
        decimal items_value
        int delivery_days
        boolean is_late
    }

    fct_order_items {
        string order_item_key PK
        string order_id
        int order_item_id
        string customer_key FK
        string product_key FK
        string seller_key FK
        int order_date_key FK
        int shipping_limit_date_key FK
        int quantity
        decimal price
        decimal freight_value
    }

    fct_payments {
        string payment_key PK
        string order_id
        int payment_sequential
        string customer_key FK
        int order_date_key FK
        string payment_type
        int payment_installments
        decimal payment_value
    }

    dim_customers ||--o{ fct_orders : "customer_key"
    dim_customers ||--o{ fct_order_items : "customer_key"
    dim_customers ||--o{ fct_payments : "customer_key"
    dim_products  ||--o{ fct_order_items : "product_key"
    dim_sellers   ||--o{ fct_order_items : "seller_key"
    dim_dates     ||--o{ fct_orders : "5 date roles"
    dim_dates     ||--o{ fct_order_items : "2 date roles"
    dim_dates     ||--o{ fct_payments : "order_date_key"
```

---

## 2. Aggregates

```mermaid
erDiagram
    fct_order_items ||--o{ mart_finance__monthly_revenue : "grouped by month and category"
    dim_products    ||--o{ mart_finance__monthly_revenue : "category_en"
    dim_dates       ||--o{ mart_finance__monthly_revenue : "month_start"

    fct_orders   ||--o{ mart_ops__delivery_sla : "grouped by month and state"
    dim_customers ||--o{ mart_ops__delivery_sla : "state"
    dim_dates    ||--o{ mart_ops__delivery_sla : "month_start"

    mart_finance__monthly_revenue {
        date month_start PK
        string category_en PK
        int order_count
        int item_count
        decimal revenue
        decimal freight_value
        decimal revenue_per_order
    }

    mart_ops__delivery_sla {
        date month_start PK
        string state PK
        int order_count
        int delivered_orders
        decimal avg_delivery_days
        decimal late_rate
    }
```

Both aggregates are keyed by the pair in their `PK` rows, which is what their `unique_combination_of_columns` tests assert.

---

## 3. Foreign key map

| Fact | Column | Dimension | Note |
|---|---|---|---|
| `fct_orders` | `customer_key` | `dim_customers.customer_key` | |
| `fct_orders` | `order_date_key` | `dim_dates.date_key` | purchase date |
| `fct_orders` | `approved_date_key` | `dim_dates.date_key` | role 2, `0` when payment was never approved |
| `fct_orders` | `carrier_date_key` | `dim_dates.date_key` | role 3, `0` when never handed to the carrier |
| `fct_orders` | `delivered_date_key` | `dim_dates.date_key` | role 4, `0` for the 2,965 orders never delivered |
| `fct_orders` | `estimated_date_key` | `dim_dates.date_key` | role 5, the promised date |
| `fct_order_items` | `customer_key` | `dim_customers.customer_key` | |
| `fct_order_items` | `product_key` | `dim_products.product_key` | |
| `fct_order_items` | `seller_key` | `dim_sellers.seller_key` | |
| `fct_order_items` | `order_date_key` | `dim_dates.date_key` | purchase date |
| `fct_order_items` | `shipping_limit_date_key` | `dim_dates.date_key` | role 2, the seller's deadline |
| `fct_payments` | `customer_key` | `dim_customers.customer_key` | |
| `fct_payments` | `order_date_key` | `dim_dates.date_key` | proxy: payments carry no timestamp, so the order date is used |

Every one of these is covered by a `relationships` test, so a key that stops resolving fails the build.

---

## 4. Reading notes

- **Degenerate dimensions.** `order_id`, `order_item_id` and `payment_sequential` live in the facts without a dimension table.
- **Unknown member.** `date_key = 0` in `dim_dates` (dated 1900-01-01) is what the null lifecycle dates point at, so no foreign key is ever null.
- **No snowflake.** Category attributes sit inside `dim_products`; latitude and longitude sit inside `dim_customers` and `dim_sellers`. Each dimension joins the fact in one hop.
- **Surrogate keys** are md5 hashes of the natural key, except `date_key`, which is the integer `YYYYMMDD`.
- **Derived attributes.** `order_count`, `lifetime_value`, `gross_revenue` and `late_rate` are refreshed on every build. Kimball allows them in a dimension when queries need them; a stricter star would move them into periodic snapshot facts.
