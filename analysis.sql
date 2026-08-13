-- ============================================================
-- Superstore SQL Analysis
-- Each query answers one business question.
-- Run against the SQLite database built by schema/01_schema.sql
-- ============================================================


-- ------------------------------------------------------------
-- Q1. Which categories drive revenue, and which drive profit?
--     (These are not the same list — that is the finding.)
-- Technique: GROUP BY, aggregate arithmetic, HAVING
-- ------------------------------------------------------------
SELECT
    category,
    sub_category,
    ROUND(SUM(sales), 2)                          AS revenue,
    ROUND(SUM(profit), 2)                         AS profit,
    ROUND(100.0 * SUM(profit) / SUM(sales), 1)    AS margin_pct,
    COUNT(DISTINCT order_id)                      AS orders
FROM orders
GROUP BY category, sub_category
ORDER BY profit ASC;          -- loss-makers first


-- ------------------------------------------------------------
-- Q2. Top 3 sub-categories by revenue within each region.
-- Technique: window function (RANK) inside a CTE
-- ------------------------------------------------------------
WITH regional AS (
    SELECT
        region,
        sub_category,
        SUM(sales) AS revenue,
        RANK() OVER (PARTITION BY region ORDER BY SUM(sales) DESC) AS rnk
    FROM orders
    GROUP BY region, sub_category
)
SELECT region, sub_category, ROUND(revenue, 2) AS revenue, rnk
FROM regional
WHERE rnk <= 3
ORDER BY region, rnk;


-- ------------------------------------------------------------
-- Q3. Month-over-month revenue growth.
-- Technique: date truncation, LAG window function
-- ------------------------------------------------------------
WITH monthly AS (
    SELECT
        STRFTIME('%Y-%m', order_date) AS month,
        SUM(sales)                    AS revenue
    FROM orders
    GROUP BY month
)
SELECT
    month,
    ROUND(revenue, 2)                                   AS revenue,
    ROUND(LAG(revenue) OVER (ORDER BY month), 2)        AS prev_month,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
          / LAG(revenue) OVER (ORDER BY month), 1)      AS growth_pct
FROM monthly
ORDER BY month;


-- ------------------------------------------------------------
-- Q4. Return rate by category — do returns concentrate anywhere?
-- Technique: LEFT JOIN + conditional aggregation
--     LEFT JOIN matters: an INNER JOIN would silently drop every
--     order that was never returned and give a 100% return rate.
-- ------------------------------------------------------------
SELECT
    o.category,
    COUNT(DISTINCT o.order_id)                                     AS total_orders,
    COUNT(DISTINCT CASE WHEN r.returned IS NOT NULL
                        THEN o.order_id END)                       AS returned_orders,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN r.returned IS NOT NULL
                                      THEN o.order_id END)
          / COUNT(DISTINCT o.order_id), 2)                         AS return_rate_pct
FROM orders o
LEFT JOIN returns r ON o.order_id = r.order_id
GROUP BY o.category
ORDER BY return_rate_pct DESC;


-- ------------------------------------------------------------
-- Q5. Does discounting actually buy volume, or just erode margin?
-- Technique: CASE binning, GROUP BY on a derived column
-- ------------------------------------------------------------
SELECT
    CASE
        WHEN discount = 0              THEN '0%'
        WHEN discount <= 0.20          THEN '1-20%'
        WHEN discount <= 0.40          THEN '21-40%'
        ELSE                                '40%+'
    END                                        AS discount_band,
    COUNT(*)                                   AS line_items,
    ROUND(SUM(sales), 2)                       AS revenue,
    ROUND(SUM(profit), 2)                      AS profit,
    ROUND(100.0 * SUM(profit) / SUM(sales), 1) AS margin_pct,
    ROUND(AVG(quantity), 2)                    AS avg_qty
FROM orders
GROUP BY discount_band
ORDER BY MIN(discount);


-- ------------------------------------------------------------
-- Q6. Customer value: who are the top 10, and what share of
--     revenue do they represent?
-- Technique: CTE, window aggregate over the whole result set
-- ------------------------------------------------------------
WITH customer_totals AS (
    SELECT
        customer_id,
        customer_name,
        segment,
        SUM(sales)               AS revenue,
        COUNT(DISTINCT order_id) AS orders
    FROM orders
    GROUP BY customer_id, customer_name, segment
)
SELECT
    customer_name,
    segment,
    ROUND(revenue, 2)                                        AS revenue,
    orders,
    ROUND(revenue / orders, 2)                               AS avg_order_value,
    ROUND(100.0 * revenue / SUM(revenue) OVER (), 2)         AS pct_of_total_revenue
FROM customer_totals
ORDER BY revenue DESC
LIMIT 10;


-- ------------------------------------------------------------
-- Q7. Running cumulative revenue by year — the growth trajectory.
-- Technique: SUM() OVER with an ordered frame
-- ------------------------------------------------------------
WITH yearly AS (
    SELECT
        STRFTIME('%Y', order_date) AS year,
        SUM(sales)                 AS revenue
    FROM orders
    GROUP BY year
)
SELECT
    year,
    ROUND(revenue, 2)                                          AS revenue,
    ROUND(SUM(revenue) OVER (ORDER BY year
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS cumulative_revenue
FROM yearly
ORDER BY year;


-- ------------------------------------------------------------
-- Q8. Which regional managers oversee loss-making sub-categories?
-- Technique: three-table join, HAVING on an aggregate
-- ------------------------------------------------------------
SELECT
    m.manager,
    o.region,
    o.sub_category,
    ROUND(SUM(o.sales), 2)  AS revenue,
    ROUND(SUM(o.profit), 2) AS profit
FROM orders o
JOIN managers m ON o.region = m.region
GROUP BY m.manager, o.region, o.sub_category
HAVING SUM(o.profit) < 0
ORDER BY profit ASC;
