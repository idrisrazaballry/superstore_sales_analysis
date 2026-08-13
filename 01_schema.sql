-- Superstore sales analysis: schema
-- Target: SQLite 3. Adjust types for Postgres/MySQL if you switch.

DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS returns;
DROP TABLE IF EXISTS managers;

CREATE TABLE orders (
    row_id        INTEGER PRIMARY KEY,
    order_id      TEXT    NOT NULL,
    order_date    DATE    NOT NULL,
    ship_date     DATE,
    ship_mode     TEXT,
    customer_id   TEXT    NOT NULL,
    customer_name TEXT,
    segment       TEXT,
    country       TEXT,
    city          TEXT,
    state         TEXT,
    postal_code   TEXT,
    region        TEXT    NOT NULL,
    product_id    TEXT    NOT NULL,
    category      TEXT,
    sub_category  TEXT,
    product_name  TEXT,
    sales         REAL    NOT NULL,
    quantity      INTEGER,
    discount      REAL,
    profit        REAL
);

CREATE TABLE returns (
    order_id  TEXT PRIMARY KEY,
    returned  TEXT NOT NULL          -- 'Yes'
);

CREATE TABLE managers (
    region  TEXT PRIMARY KEY,
    manager TEXT NOT NULL
);

-- Indexes on the columns the analysis queries filter and join on.
CREATE INDEX idx_orders_order_id   ON orders(order_id);
CREATE INDEX idx_orders_region     ON orders(region);
CREATE INDEX idx_orders_order_date ON orders(order_date);
CREATE INDEX idx_orders_category   ON orders(category, sub_category);
