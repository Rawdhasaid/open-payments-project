import duckdb

con = duckdb.connect("compact.duckdb")
con.execute("ATTACH 'open_payments.duckdb' AS old (READ_ONLY)")

for t in ["dim_physician", "dim_teaching_hospital", "dim_manufacturer",
          "dim_product", "dim_date", "dim_payment_form",
          "dim_payment_nature", "payments_src"]:
    con.execute(f"CREATE TABLE {t} AS SELECT * FROM old.{t}")
    n_new = con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
    n_old = con.execute(f"SELECT COUNT(*) FROM old.{t}").fetchone()[0]
    print(t, n_old, n_new, "OK" if n_old == n_new else "MISMATCH")

print(len(con.execute("DESCRIBE payments_src").fetchall()), "columns in payments_src")
con.close()