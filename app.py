"""Superstore SQL Analysis — interactive query browser.

Reads queries/analysis.sql, splits it on the '-- Qn.' headers, and lets the
user run each one against superstore.db. The SQL is shown alongside every
result: the queries are the point of this project, not the charts.
"""

import pathlib
import re
import sqlite3

import pandas as pd
import streamlit as st

ROOT = pathlib.Path(__file__).parent
DB_PATH = ROOT / "superstore.db"
SQL_PATH = ROOT / "analysis.sql"

st.set_page_config(page_title="Superstore SQL Analysis", layout="wide")


@st.cache_resource
def get_connection():
    # check_same_thread=False: Streamlit reruns the script on a different
    # thread than the one that opened the connection.
    return sqlite3.connect(str(DB_PATH), check_same_thread=False)


@st.cache_data
def load_queries():
    """Split analysis.sql into {title: sql} using the '-- Qn. <title>' headers."""
    text = SQL_PATH.read_text()

    # Find each header line and where it starts.
    headers = list(re.finditer(r"^--\s*Q(\d+)\.\s*(.+)$", text, re.MULTILINE))
    queries = {}

    for idx, match in enumerate(headers):
        num, title = match.group(1), match.group(2).strip()
        body_start = match.end()
        body_end = headers[idx + 1].start() if idx + 1 < len(headers) else len(text)
        body = text[body_start:body_end]

        # Drop every remaining comment line; keep the SQL.
        sql = "\n".join(
            line for line in body.splitlines()
            if line.strip() and not line.strip().startswith("--")
        ).strip().rstrip(";")

        if sql:
            queries[f"Q{num}. {title}"] = sql

    return queries


@st.cache_data
def run(sql):
    return pd.read_sql_query(sql, get_connection())


st.title("Superstore Sales Analysis")
st.caption(
    "9,994 order line-items, normalised into four related tables. "
    "Each question below is answered by a single SQL query."
)

try:
    queries = load_queries()
except FileNotFoundError:
    st.error(f"Couldn't find {SQL_PATH}. Run this from the project root.")
    st.stop()

if not queries:
    st.error("No queries parsed — check the '-- Qn.' headers in analysis.sql.")
    st.stop()

choice = st.sidebar.radio("Question", list(queries), label_visibility="collapsed")
sql = queries[choice]

st.subheader(choice)

try:
    df = run(sql)
except Exception as exc:
    st.error(f"Query failed: {exc}")
    st.code(sql, language="sql")
    st.stop()

left, right = st.columns([3, 2])

with left:
    st.dataframe(df, use_container_width=True, hide_index=True)

    # Chart when there's an obvious label + numeric pair.
    numeric = df.select_dtypes("number").columns.tolist()
    labels = [c for c in df.columns if c not in numeric]
    if labels and numeric and len(df) <= 40:
        st.bar_chart(df.set_index(labels[0])[numeric[0]])

with right:
    st.code(sql, language="sql")

st.download_button(
    "Download results as CSV",
    df.to_csv(index=False).encode(),
    file_name=f"{choice.split('.')[0].lower()}_results.csv",
    mime="text/csv",
)
