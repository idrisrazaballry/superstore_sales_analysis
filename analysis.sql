-- ============================================================
-- Superstore SQL Analysis
-- Source: one flat 9,994-row CSV, normalised into
--   customers / products / orders / order_items
-- Every query below needs a join because of that split.
-- ============================================================


-- Q1. Which sub-categories make money, and which lose it?
-- Technique: join, GROUP BY, aggregate arithmetic
SELECT
    p.category,
    p.sub_category,
    ROUND(SUM(i.sales), 2)                       AS revenue,
    ROUND(SUM(i.profit), 2)                      AS profit,
    ROUND(100.0 * SUM(i.profit) / SUM(i.sales), 1) AS margin_pct
FROM order_items i
JOIN products p ON i.product_id = p.product_id
GROUP BY p.category, p.sub_category
ORDER BY profit ASC;


-- Q2. Top 3 sub-categories by revenue within each region.
-- Technique: three-table join, RANK() window function inside a CTE
WITH regional AS (
    SELECT
        o.region,
        p.sub_category,
        SUM(i.sales) AS revenue,
        RANK() OVER (PARTITION BY o.region ORDER BY SUM(i.sales) DESC) AS rnk
    FROM order_items i
    JOIN orders   o ON i.order_id   = o.order_id
    JOIN products p ON i.product_id = p.product_id
    GROUP BY o.region, p.sub_category
)
SELECT region, sub_category, ROUND(revenue, 2) AS revenue, rnk
FROM regional
WHERE rnk <= 3
ORDER BY region, rnk;


-- Q3. Month-over-month revenue growth.
-- Technique: date truncation, LAG() to reach the previous row
WITH monthly AS (
    SELECT STRFTIME('%Y-%m', o.order_date) AS month,
           SUM(i.sales)                    AS revenue
    FROM order_items i
    JOIN orders o ON i.order_id = o.order_id
    GROUP BY month
)
SELECT
    month,
    ROUND(revenue, 2)                            AS revenue,
    ROUND(LAG(revenue) OVER (ORDER BY month), 2) AS prev_month,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
          / LAG(revenue) OVER (ORDER BY month), 1) AS growth_pct
FROM monthly
ORDER BY month;


-- Q4. Does discounting buy volume, or just erode margin?
-- Technique: CASE binning, GROUP BY a derived column
SELECT
    CASE WHEN discount = 0     THEN '0%'
         WHEN discount <= 0.20 THEN '1-20%'
         WHEN discount <= 0.40 THEN '21-40%'
         ELSE                       '40%+' END   AS discount_band,
    COUNT(*)                                     AS line_items,
    ROUND(SUM(sales), 2)                         AS revenue,
    ROUND(SUM(profit), 2)                        AS profit,
    ROUND(100.0 * SUM(profit) / SUM(sales), 1)   AS margin_pct,
    ROUND(AVG(quantity), 2)                      AS avg_qty
FROM order_items
GROUP BY discount_band
ORDER BY MIN(discount);


-- Q5. Top 10 customers, and what share of revenue they hold.
-- Technique: CTE, window aggregate SUM() OVER () across all rows
WITH totals AS (
    SELECT c.customer_id, c.customer_name, c.segment,
           SUM(i.sales)               AS revenue,
           COUNT(DISTINCT o.order_id) AS orders
    FROM order_items i
    JOIN orders    o ON i.order_id    = o.order_id
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_id, c.customer_name, c.segment
)
SELECT
    customer_name,
    segment,
    ROUND(revenue, 2)                                 AS revenue,
    orders,
    ROUND(revenue / orders, 2)                        AS avg_order_value,
    ROUND(100.0 * revenue / SUM(revenue) OVER (), 2)  AS pct_of_total
FROM totals
ORDER BY revenue DESC
LIMIT 10;


-- Q6. Cumulative revenue by year — the growth trajectory.
-- Technique: SUM() OVER with an explicit window frame
WITH yearly AS (
    SELECT STRFTIME('%Y', o.order_date) AS year,
           SUM(i.sales)                 AS revenue
    FROM order_items i
    JOIN orders o ON i.order_id = o.order_id
    GROUP BY year
)
SELECT
    year,
    ROUND(revenue, 2) AS revenue,
    ROUND(SUM(revenue) OVER (ORDER BY year
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS cumulative
FROM yearly
ORDER BY year;


-- Q7. Do customers come back? Repeat rate by segment.
-- Technique: nested aggregation — count orders per customer, then bucket
WITH per_customer AS (
    SELECT c.customer_id, c.segment, COUNT(DISTINCT o.order_id) AS orders
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.segment
)
SELECT
    segment,
    COUNT(*)                                                  AS customers,
    SUM(CASE WHEN orders = 1 THEN 1 ELSE 0 END)               AS one_time,
    SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END)               AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                      AS repeat_pct,
    ROUND(AVG(orders), 2)                                     AS avg_orders
FROM per_customer
GROUP BY segment
ORDER BY repeat_pct DESC;


-- Q8. Shipping speed: how long between order and dispatch?
-- Technique: date arithmetic (JULIANDAY), grouping on two dimensions
SELECT
    ship_mode,
    region,
    COUNT(*)                                                   AS orders,
    ROUND(AVG(JULIANDAY(ship_date) - JULIANDAY(order_date)), 2) AS avg_days,
    MAX(CAST(JULIANDAY(ship_date) - JULIANDAY(order_date) AS INT)) AS max_days
FROM orders
WHERE ship_date IS NOT NULL
GROUP BY ship_mode, region
ORDER BY ship_mode, avg_days DESC;
