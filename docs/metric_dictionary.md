# Metric dictionary

One definition per metric, so that two people asking the same question get the same number. This document is the human-readable twin of what becomes `semantic_models` and `metrics` YAML when the project moves to a Semantic Layer.

Every value below was measured on the current load: 99,441 orders, order lines 112,650, payments 103,886.

## Conventions

- **Currency**: BRL, `decimal(10,2)`. Never float.
- **Time**: local time as delivered by the source, no timezone conversion. A "month" is a calendar month resolved through `dim_dates.month_start`.
- **Order**: one row in `fct_orders`. **Item**: one row in `fct_order_items`. **Payment**: one row in `fct_payments`. **Customer**: one row in `dim_customers`, keyed by `customer_unique_id`.
- **All dates are role-playing keys** into `dim_dates`; join to get `month_start`, `year` or `day_name`.

## Metrics at a glance

| Metric | Definition | Grain | Additive | Value today |
|---|---|---|---|---|
| `order_count` | `count(*)` on `fct_orders` | order | no, count | 99,441 |
| `delivered_order_count` | `count(*) where is_delivered` | order | no, count | 96,476 |
| `item_revenue` | `sum(price)` on `fct_order_items` | item | yes | 13,591,643.70 |
| `freight_value` | `sum(freight_value)` on `fct_order_items` | item | yes | 2,251,909.54 |
| `gross_item_value` | `item_revenue + freight_value` | item | yes | 15,843,553.24 |
| `payment_total` | `sum(payment_value)` on `fct_payments` | payment | yes | 16,008,872.12 |
| `average_order_value` | `payment_total / order_count` | order | no, ratio | 160.99 |
| `average_item_value` | `item_revenue / order_count` | order | no, ratio | 136.68 |
| `late_rate` | late delivered orders / delivered orders | order | no, ratio | 8.11% |
| `avg_delivery_days` | `avg(delivery_days) where is_delivered` | order | no, average only | 12.50 |
| `customer_count` | `count(distinct customer_unique_id)` | customer | no, count | 96,096 |
| `repeat_customer_rate` | customers with `order_count > 1` / customers | customer | no, ratio | 3.12% |
| `lifetime_value` | `sum(payment_total)` per customer, averaged | customer | yes per customer | 166.59 |

## The four that get argued about

### 1. Revenue

**`item_revenue` = sum of product prices, excluding freight, across every order status.**

Three defensible answers exist in this data and they differ by 18%:

| Definition | Value |
|---|---|
| Product prices only | 13,591,643.70 |
| Product prices plus freight | 15,843,553.24 |
| Cash actually collected | 16,008,872.12 |

Payment total exceeds product plus freight by **165,318.88**, which comes from installment interest and voucher handling in the source. If a report says "revenue" without naming the definition, it is not reproducible.

`mart_finance__monthly_revenue.revenue` uses the first definition.

### 2. Revenue by order status

`item_revenue` currently includes every status, because `fct_order_items` does not filter. The split:

| Status | Orders | Item revenue |
|---|---|---|
| delivered | 96,478 | 13,221,498.11 |
| shipped | 1,106 | 150,727.44 |
| canceled | 461 | 95,235.27 |
| invoiced | 312 | 61,526.37 |
| processing | 301 | 60,439.22 |
| unavailable | 6 | 2,007.69 |
| approved | 2 | 209.60 |

Excluding canceled and unavailable would remove **97,242.96**. Decide once, write it here, and encode it in the model rather than in each report.

### 3. Late rate

**`late_rate` = delivered orders whose delivery timestamp is after the promised date, divided by delivered orders.**

- Delivered orders with a delivery timestamp: **96,476**
- Of those, late: **7,827**, which is **8.11%**

Note the discrepancy: 96,478 orders carry `order_status = 'delivered'`, but only 96,476 have `delivered_to_customer_at` filled. Two orders claim delivery without a timestamp. `late_rate` uses the timestamp, because lateness cannot be measured without a date. Any report that defines the denominator by status will differ by those two rows today and more if upstream ever becomes sloppy.

Undelivered orders are `null`, not `false`, so they never enter the denominator.

### 4. Customer count

**`customer_count` counts `customer_unique_id`, never `customer_id`.**

- `customer_id` values: 99,441, one per order
- `customer_unique_id` values: 96,096, one per person
- Repeat customers: 2,997, which is **3.12%**
- Orders per customer: 1.035

Counting `customer_id` produces 99,441 "customers" and a repeat rate of zero. That mistake is invisible in a dashboard and wrong by 3,345 people.

## Still open

1. Should canceled and unavailable orders sit in `item_revenue`? Impact 97,242.96.
2. Is freight part of revenue? Impact 2,251,909.54.
3. Do we report delivery performance by order status or by timestamp? Impact 2 orders today.
4. Are partial refunds in scope? The source has no refund table, so no.

Each of these is a business decision, not a technical one. Record the answer here before changing a model.

## Where each metric lives

| Metric | Model | Column |
|---|---|---|
| `item_revenue`, `freight_value` | `fct_order_items` | `price`, `freight_value` |
| `payment_total` | `fct_payments`, or `fct_orders.payment_total` | `payment_value` |
| `late_rate`, `avg_delivery_days` | `fct_orders` | `is_delivered`, `is_late`, `delivery_days` |
| `customer_count`, `repeat_customer_rate` | `dim_customers` | `customer_unique_id`, `order_count` |
| monthly grouping | `dim_dates` | `month_start` via `order_date_key` |
