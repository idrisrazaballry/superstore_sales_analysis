"""Normalise the flat Superstore CSV into a relational SQLite database."""

import pathlib
import sqlite3

import pandas as pd

ROOT = pathlib.Path(__file__).parent
DB = ROOT / "superstore.db"
CSV = ROOT / "Sample-Superstore.csv"

if DB.exists():
    DB.unlink()

conn = sqlite3.connect(DB)
conn.executescript((ROOT / "01_schema.sql").read_text())

df = pd.read_csv(CSV, encoding="latin-1")
df.columns = (df.columns.str.strip().str.lower()
              .str.replace(r"[ \-]", "_", regex=True))

for col in ("order_date", "ship_date"):
    df[col] = pd.to_datetime(df[col], dayfirst=False,
                             format="mixed").dt.strftime("%Y-%m-%d")

# --- dimensions: one row per entity ---------------------------------------
customers = (df[["customer_id", "customer_name", "segment"]]
             .drop_duplicates("customer_id"))

products = (df[["product_id", "product_name", "category", "sub_category"]]
            .drop_duplicates("product_id"))

orders = (df[["order_id", "order_date", "ship_date", "ship_mode",
              "customer_id", "city", "state", "postal_code", "region"]]
          .drop_duplicates("order_id"))

# --- fact: one row per product line within an order -----------------------
order_items = df[["row_id", "order_id", "product_id",
                  "sales", "quantity", "discount", "profit"]]

for name, table in [("customers", customers), ("products", products),
                    ("orders", orders), ("order_items", order_items)]:
    table.to_sql(name, conn, if_exists="append", index=False)
    n = conn.execute(f"SELECT COUNT(*) FROM {name}").fetchone()[0]
    print(f"{name:12} {n:>6} rows")

print(f"\nFlat CSV was {len(df)} rows; normalising removed "
      f"{len(df) - len(orders)} duplicate order headers.")

conn.commit()
conn.close()
