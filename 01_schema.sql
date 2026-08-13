-- Superstore sales analysis: normalised schema
--
-- Source is a single flat CSV (9,994 rows, 21 columns) where customer and
-- product attributes repeat on every line. This splits it into dimension
-- tables plus a fact table, so each fact is stored once.

DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id   TEXT PRIMARY KEY,
    customer_name TEXT NOT NULL,
    segment       TEXT NOT NULL
);

CREATE TABLE products (
    product_id   TEXT PRIMARY KEY,
    product_name TEXT NOT NULL,
    category     TEXT NOT NULL,
    sub_category TEXT NOT NULL
);

CREATE TABLE orders (
    order_id    TEXT PRIMARY KEY,
    order_date  DATE NOT NULL,
    ship_date   DATE,
    ship_mode   TEXT,
    customer_id TEXT NOT NULL REFERENCES customers(customer_id),
    city        TEXT,
    state       TEXT,
    postal_code TEXT,
    region      TEXT NOT NULL
);

CREATE TABLE order_items (
    row_id     INTEGER PRIMARY KEY,
    order_id   TEXT    NOT NULL REFERENCES orders(order_id),
    product_id TEXT    NOT NULL REFERENCES products(product_id),
    sales      REAL    NOT NULL,
    quantity   INTEGER NOT NULL,
    discount   REAL    NOT NULL,
    profit     REAL    NOT NULL
);

CREATE INDEX idx_items_order   ON order_items(order_id);
CREATE INDEX idx_items_product ON order_items(product_id);
CREATE INDEX idx_orders_cust   ON orders(customer_id);
CREATE INDEX idx_orders_date   ON orders(order_date);
CREATE INDEX idx_orders_region ON orders(region);
