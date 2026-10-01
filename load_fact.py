import duckdb

# No read_only here, so the Postgres attach is allowed to write
con = duckdb.connect("open_payments.duckdb")
con.execute("INSTALL postgres; LOAD postgres;")

con.execute(f"""
ATTACH 'host=localhost port=5432 dbname=open_payments_dwh
        user={os.environ["PG_USER"]} password={os.environ["PG_PASSWORD"]}'
AS pg (TYPE postgres, READ_ONLY);
""")
LIMIT = ""   # test run. For the full load change to:  LIMIT = ""

con.execute(f"""
INSERT INTO pg.stg.fct_payments (
    record_id, physician_key, teaching_hospital_key, manufacturer_key, product_key,
    payment_date, payment_date_key, payment_publication_date, publication_date_key,
    payment_year, related_product_indicator, number_of_payments_included_in_total_amount,
    total_payment_us_dollars, payment_form_key, payment_nature_key
)
SELECT record_id, physician_key, teaching_hospital_key, manufacturer_key, product_key,
       payment_date, payment_date_key, payment_publication_date, publication_date_key,
       payment_year, related_product_indicator, number_of_payments_included_in_total_amount,
       total_payment_us_dollars, payment_form_key, payment_nature_key
FROM fct_build ORDER BY record_id {LIMIT}
""")

print(con.execute("SELECT COUNT(*) FROM pg.stg.fct_payments").fetchone())
con.close()