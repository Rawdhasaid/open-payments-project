# CMS Open Payments 2025: Data Warehouse

A star-schema data warehouse built from the CMS Open Payments **General Payments 2025** file (16,131,856 rows).

- **PostgreSQL** (in Docker) holds the staging table, the dimensions and the final fact table.
- **DuckDB** (local file) does the heavy joins, because joining 16M rows inside PostgreSQL was too slow.

Source data: download the General Payments file for program year 2025 from the CMS Open Payments site (https://openpaymentsdata.cms.gov). The raw CSV is not stored in this repo.

---

## 1. Design

### Star schema

| Table | Rows | Purpose |
|---|---|---|
| `stg.fct_payments` | 16,131,856 | One row per payment record |
| `stg.dim_physician` | 3,255,827 | Physicians and non-teaching-hospital recipients |
| `stg.dim_teaching_hospital` | 2,282 | Teaching hospitals |
| `stg.dim_manufacturer` | 1,782 | Companies / GPOs making the payment |
| `stg.dim_product` | 34,655 | Distinct product combinations (30 columns) |
| `stg.dim_date` | 546 | Calendar dates |
| `stg.dim_payment_form` | 6 | Form of payment |
| `stg.dim_payment_nature` | 16 | Nature of payment |

### Design rules

- Keep the source mostly as-is (minimum cleaning).
- Do **not** collapse genuine versions of a dimension record (for example, the same hospital with a changed address).
- `Record_ID` is **not unique** by itself, so the fact table has no UNIQUE constraint on it.
- Joins must never multiply rows. After every join the row count must stay exactly 16,131,856.

### Recipient design

Each payment goes to either a physician (or non-teaching-hospital recipient) or a teaching hospital:

- `Covered_Recipient_Type` containing `Covered Recipient Teaching Hospital` means a teaching hospital (35,569 rows). These rows have no `Covered_Recipient_Profile_ID`.
- Every other row is a physician row (16,096,287 rows).
- The fact table has both `physician_key` and `teaching_hospital_key`. Exactly one of them is filled on each row, the other is NULL.
- Physician NPI can be NULL in the source (2,795 dimension rows), so the NPI column must **not** be filtered. In DuckDB joins, nullable columns use a null-safe comparison.
- Teaching hospital attributes: ID, CCN, name, address lines 1 and 2, city, state, zip, country. The `*_of_Travel` columns are **not** included, because they describe the payment trip, not the hospital.

---

## 2. Run order

1. PostgreSQL: create the schema and tables (`DDL.sql`), load the staging table.
2. PostgreSQL: load the dimensions (section 4).
3. DuckDB: `build_fact_duckdb.py` copies the source and dimensions into a local file.
4. DuckDB: `build_fact_rows.py` builds the finished fact rows (`fct_build`).
5. DuckDB: `load_fact.py` writes `fct_build` into `stg.fct_payments` in PostgreSQL.
6. PostgreSQL: add foreign keys and indexes, then run the checks.

---

## 3. Setup

### Credentials

Passwords are never stored in the code. Set them in the same PowerShell window you run the scripts from:

```powershell
$env:PG_USER = "your_user"
$env:PG_PASSWORD = "your_password"
```

They only last while that window is open. Use `.env.example` with fake values for the repo, and keep real values out of git.

### `.gitignore`

```
*.duckdb
*.duckdb.wal
*.parquet
*.csv
.env
duck_tmp/
.venv/
```

### Python packages

```
pip install duckdb pyarrow psycopg2-binary
```

### Suggested structure

```
open-payments-project/
├── sql/                     # DDL and dimension loads
├── build_fact_duckdb.py
├── build_fact_rows.py
├── load_fact.py
├── compact_db.py            # maintenance only
├── .env.example
├── .gitignore
└── README.md
```

---

## 4. PostgreSQL: dimensions

The staging table is `stg.general_payments_2025_clean` (16,131,856 rows). Every dimension is loaded with `SELECT DISTINCT`, so exact duplicates are removed but genuine versions are kept.

> The load for `dim_manufacturer`, `dim_date`, `dim_payment_form` and `dim_payment_nature` is in `sql/` (`Stage Queries`). The three that changed during this project are below.

### 4.1 `dim_physician`

Rows that are not teaching hospitals. Do **not** add `NPI IS NOT NULL`.

```sql
TRUNCATE stg.dim_physician RESTART IDENTITY;

INSERT INTO stg.dim_physician (
    physician_profile_id, physician_npi, physician_name_suffix,
    physician_first_name, physician_middle_name, physician_last_name,
    physician_city, physician_country, physician_postal_code,
    physician_province, physician_state, physician_zip_code,
    physician_street_address_line1, physician_street_address_line2,
    physician_license_state_cd1, physician_license_state_cd2,
    physician_license_state_cd3, physician_license_state_cd4,
    physician_license_state_cd5,
    physician_specialty_1, physician_specialty_2, physician_type,
    physician_primary_type_1, physician_primary_type_2, physician_primary_type_3,
    physician_primary_type_4, physician_primary_type_5, physician_primary_type_6
)
SELECT DISTINCT
    "Covered_Recipient_Profile_ID", "Covered_Recipient_NPI", "Covered_Recipient_Name_Suffix",
    "Covered_Recipient_First_Name", "Covered_Recipient_Middle_Name", "Covered_Recipient_Last_Name",
    "Recipient_City", "Recipient_Country", "Recipient_Postal_Code",
    "Recipient_Province", "Recipient_State", "Recipient_Zip_Code",
    "Recipient_Primary_Business_Street_Address_Line1",
    "Recipient_Primary_Business_Street_Address_Line2",
    "Covered_Recipient_License_State_code1", "Covered_Recipient_License_State_code2",
    "Covered_Recipient_License_State_code3", "Covered_Recipient_License_State_code4",
    "Covered_Recipient_License_State_code5",
    "Covered_Recipient_Specialty_1", "Covered_Recipient_Specialty_2", "Covered_Recipient_Type",
    "Covered_Recipient_Primary_Type_1", "Covered_Recipient_Primary_Type_2",
    "Covered_Recipient_Primary_Type_3", "Covered_Recipient_Primary_Type_4",
    "Covered_Recipient_Primary_Type_5", "Covered_Recipient_Primary_Type_6"
FROM stg.general_payments_2025_clean
WHERE "Covered_Recipient_Profile_ID" IS NOT NULL
  AND "Covered_Recipient_Type" NOT LIKE '%Covered Recipient Teaching Hospital%';
```

### 4.2 `dim_teaching_hospital`

```sql
CREATE TABLE stg.dim_teaching_hospital (
    teaching_hospital_key SERIAL,
    teaching_hospital_id BIGINT,
    teaching_hospital_ccn VARCHAR(6),
    teaching_hospital_name VARCHAR(50),
    teaching_hospital_street_address_line1 VARCHAR(200),
    teaching_hospital_street_address_line2 VARCHAR(200),
    teaching_hospital_city VARCHAR(100),
    teaching_hospital_state VARCHAR(50),
    teaching_hospital_zip_code VARCHAR(50),
    teaching_hospital_country VARCHAR(100),
    PRIMARY KEY (teaching_hospital_key)
);
```

**Why `UPPER`:** the same hospital appeared with different letter case in different rows. Of 3,280 distinct rows, 998 differed only by case. Applying `UPPER` to the text columns leaves 2,282 rows for 1,296 hospital IDs. The remaining differences (address, zip) are real changes and are kept. The ID and CCN are not uppercased.

```sql
TRUNCATE stg.dim_teaching_hospital RESTART IDENTITY;

INSERT INTO stg.dim_teaching_hospital (
    teaching_hospital_id, teaching_hospital_ccn, teaching_hospital_name,
    teaching_hospital_street_address_line1, teaching_hospital_street_address_line2,
    teaching_hospital_city, teaching_hospital_state,
    teaching_hospital_zip_code, teaching_hospital_country
)
SELECT DISTINCT
    "Teaching_Hospital_ID",
    "Teaching_Hospital_CCN",
    UPPER("Teaching_Hospital_Name"),
    UPPER("Recipient_Primary_Business_Street_Address_Line1"),
    UPPER("Recipient_Primary_Business_Street_Address_Line2"),
    UPPER("Recipient_City"),
    UPPER("Recipient_State"),
    UPPER("Recipient_Zip_Code"),
    UPPER("Recipient_Country")
FROM stg.general_payments_2025_clean
WHERE "Covered_Recipient_Type" LIKE '%Covered Recipient Teaching Hospital%'
  AND "Teaching_Hospital_ID" IS NOT NULL;

SELECT COUNT(*) FROM stg.dim_teaching_hospital;   -- 2,282
```

### 4.3 `dim_product`

The product dimension is **one row per distinct combination of the 30 product columns** (5 each of name, indication, category, NDC, PDI and covered indicator). The first version of this table had 14.8M rows, but only 34,570 of them were distinct, so every product existed about 430 times. That duplication caused row multiplication and a full disk in the join. The fix is `SELECT DISTINCT`.

Products with **no name** are kept (about 1.3M payment rows have no product name). A payment without a product is still a real payment, and it gets a key too.

```sql
TRUNCATE stg.dim_product RESTART IDENTITY;

INSERT INTO stg.dim_product (
    name_of_drug_or_biological_or_device_or_medical_supply_1,
    name_of_drug_or_biological_or_device_or_medical_supply_2,
    name_of_drug_or_biological_or_device_or_medical_supply_3,
    name_of_drug_or_biological_or_device_or_medical_supply_4,
    name_of_drug_or_biological_or_device_or_medical_supply_5,
    indicate_drug_or_biological_or_device_or_medical_supply_1,
    indicate_drug_or_biological_or_device_or_medical_supply_2,
    indicate_drug_or_biological_or_device_or_medical_supply_3,
    indicate_drug_or_biological_or_device_or_medical_supply_4,
    indicate_drug_or_biological_or_device_or_medical_supply_5,
    product_category_or_therapeutic_area_1,
    product_category_or_therapeutic_area_2,
    product_category_or_therapeutic_area_3,
    product_category_or_therapeutic_area_4,
    product_category_or_therapeutic_area_5,
    associated_drug_or_biological_ndc_1,
    associated_drug_or_biological_ndc_2,
    associated_drug_or_biological_ndc_3,
    associated_drug_or_biological_ndc_4,
    associated_drug_or_biological_ndc_5,
    associated_device_or_medical_supply_pdi_1,
    associated_device_or_medical_supply_pdi_2,
    associated_device_or_medical_supply_pdi_3,
    associated_device_or_medical_supply_pdi_4,
    associated_device_or_medical_supply_pdi_5,
    covered_or_noncovered_indicator_1,
    covered_or_noncovered_indicator_2,
    covered_or_noncovered_indicator_3,
    covered_or_noncovered_indicator_4,
    covered_or_noncovered_indicator_5
)
SELECT DISTINCT
    "Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_1",
    "Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_2",
    "Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_3",
    "Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_4",
    "Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_5",
    "Indicate_Drug_or_Biological_or_Device_or_Medical_Supply_1",
    "Indicate_Drug_or_Biological_or_Device_or_Medical_Supply_2",
    "Indicate_Drug_or_Biological_or_Device_or_Medical_Supply_3",
    "Indicate_Drug_or_Biological_or_Device_or_Medical_Supply_4",
    "Indicate_Drug_or_Biological_or_Device_or_Medical_Supply_5",
    "Product_Category_or_Therapeutic_Area_1",
    "Product_Category_or_Therapeutic_Area_2",
    "Product_Category_or_Therapeutic_Area_3",
    "Product_Category_or_Therapeutic_Area_4",
    "Product_Category_or_Therapeutic_Area_5",
    "Associated_Drug_or_Biological_NDC_1",
    "Associated_Drug_or_Biological_NDC_2",
    "Associated_Drug_or_Biological_NDC_3",
    "Associated_Drug_or_Biological_NDC_4",
    "Associated_Drug_or_Biological_NDC_5",
    "Associated_Device_or_Medical_Supply_PDI_1",
    "Associated_Device_or_Medical_Supply_PDI_2",
    "Associated_Device_or_Medical_Supply_PDI_3",
    "Associated_Device_or_Medical_Supply_PDI_4",
    "Associated_Device_or_Medical_Supply_PDI_5",
    "Covered_or_Noncovered_Indicator_1",
    "Covered_or_Noncovered_Indicator_2",
    "Covered_or_Noncovered_Indicator_3",
    "Covered_or_Noncovered_Indicator_4",
    "Covered_or_Noncovered_Indicator_5"
FROM stg.general_payments_2025_clean;

SELECT COUNT(*) FROM stg.dim_product;   -- 34,655
```

---

## 5. PostgreSQL: fact table

Created **without** foreign keys and **without** a UNIQUE constraint on `record_id`. Foreign keys are added after the load because checking 16M rows against 8 tables during the load is very slow.

```sql
DROP TABLE IF EXISTS stg.fct_payments;

CREATE TABLE stg.fct_payments (
    payment_key SERIAL,
    record_id BIGINT,
    physician_key BIGINT,
    teaching_hospital_key BIGINT,
    manufacturer_key BIGINT,
    product_key BIGINT,
    payment_date DATE,
    payment_date_key BIGINT,
    payment_publication_date DATE,
    publication_date_key BIGINT,
    payment_year BIGINT,
    related_product_indicator VARCHAR(50),
    number_of_payments_included_in_total_amount BIGINT,
    total_payment_us_dollars DOUBLE PRECISION,
    payment_form_key BIGINT,
    payment_nature_key BIGINT,
    PRIMARY KEY (payment_key)
);
```

`physician_key` and `teaching_hospital_key` allow NULL on purpose, because each payment has only one of them.

---

## 6. DuckDB: copy source and dimensions locally

### `build_fact_duckdb.py`

Copies `payments_src` (75 source columns) and the seven dimensions from PostgreSQL into `open_payments.duckdb`. It takes about 10 to 20 minutes. The resulting file is about 2 to 4 GB.

`payments_src` contains only the columns needed to build the dimensions and the fact. The other columns stay in PostgreSQL.

```python
import os
import duckdb

con = duckdb.connect("open_payments.duckdb")

con.execute("INSTALL postgres;")
con.execute("LOAD postgres;")

con.execute(f"""
ATTACH 'host=localhost port=5432 dbname=open_payments_dwh
        user={os.environ["PG_USER"]} password={os.environ["PG_PASSWORD"]}'
AS pg (TYPE postgres, READ_ONLY);
""")

print("Postgres source:", con.execute(
    "SELECT COUNT(*) FROM pg.stg.general_payments_2025_clean"
).fetchone())

# ---------- payments_src (75 columns) ----------
bases = [
    "Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_",
    "Indicate_Drug_or_Biological_or_Device_or_Medical_Supply_",
    "Product_Category_or_Therapeutic_Area_",
    "Associated_Drug_or_Biological_NDC_",
    "Associated_Device_or_Medical_Supply_PDI_",
    "Covered_or_Noncovered_Indicator_",
]
product_cols = [f"{b}{i}" for b in bases for i in range(1, 6)]

other_cols = [
    "Record_ID", "Date_of_Payment", "Payment_Publication_Date", "Program_Year",
    "Related_Product_Indicator", "Number_of_Payments_Included_in_Total_Amount",
    "Total_Amount_of_Payment_USDollars",
    "Covered_Recipient_Profile_ID", "Covered_Recipient_NPI",
    "Covered_Recipient_Name_Suffix", "Covered_Recipient_First_Name",
    "Covered_Recipient_Middle_Name", "Covered_Recipient_Last_Name",
    "Recipient_City", "Recipient_Country", "Recipient_Postal_Code",
    "Recipient_Province", "Recipient_State", "Recipient_Zip_Code",
    "Recipient_Primary_Business_Street_Address_Line1",
    "Recipient_Primary_Business_Street_Address_Line2",
    "Covered_Recipient_License_State_code1", "Covered_Recipient_License_State_code2",
    "Covered_Recipient_License_State_code3", "Covered_Recipient_License_State_code4",
    "Covered_Recipient_License_State_code5",
    "Covered_Recipient_Specialty_1", "Covered_Recipient_Specialty_2",
    "Covered_Recipient_Type",
    "Covered_Recipient_Primary_Type_1", "Covered_Recipient_Primary_Type_2",
    "Covered_Recipient_Primary_Type_3", "Covered_Recipient_Primary_Type_4",
    "Covered_Recipient_Primary_Type_5", "Covered_Recipient_Primary_Type_6",
    "Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_ID",
    "Submitting_Applicable_Manufacturer_or_Applicable_GPO_Name",
    "Applicable_Manufacturer_or_Applicable_GPO_Making_Pymnt_Cntry",
    "Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_Name",
    "Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_State",
    "Form_of_Payment_or_Transfer_of_Value",
    "Nature_of_Payment_or_Transfer_of_Value",
    "Teaching_Hospital_ID", "Teaching_Hospital_CCN", "Teaching_Hospital_Name",
]

select_list = ",\n".join(f'"{c}"' for c in other_cols + product_cols)

con.execute(f"""
CREATE OR REPLACE TABLE payments_src AS
SELECT {select_list}
FROM pg.stg.general_payments_2025_clean
""")

print("payments_src rows:", con.execute("SELECT COUNT(*) FROM payments_src").fetchone())
print("payments_src columns:", len(con.execute("DESCRIBE payments_src").fetchall()))

# ---------- dimensions ----------
dims = [
    "dim_physician", "dim_teaching_hospital", "dim_manufacturer", "dim_product",
    "dim_date", "dim_payment_form", "dim_payment_nature",
]
for t in dims:
    con.execute(f"CREATE OR REPLACE TABLE {t} AS SELECT * FROM pg.stg.{t}")
    print(t, con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0])

con.close()
print("Done.")
```

**Expected output:** 16,131,856 rows, 75 columns, and dimension counts of physician 3,255,827, teaching hospital 2,282, manufacturer 1,782, product 34,655, date 546, payment form 6, payment nature 16.

> Note: after the `dim_product` reload, the product count is 34,655, not the original 14,835,122.

To refresh a single dimension without rebuilding everything, run only its `CREATE OR REPLACE TABLE ... AS SELECT * FROM pg.stg.<table>` line.

---

## 7. DuckDB: build the fact rows

### `build_fact_rows.py`

Joins `payments_src` to all dimensions and writes the finished rows to a DuckDB table called `fct_build`.

**How the joins work**

- Each dimension is matched on its ID **plus** all of its attributes, so that different versions of the same record get different keys.
- Comparing many nullable columns with `IS NOT DISTINCT FROM` forces DuckDB into a very slow join. Instead, each side builds one `md5` hash of all attribute columns (NULL replaced by a marker), and the join compares the two short hashes with a plain `=`.
- The text columns that were uppercased in the dimension are uppercased on the source side as well (hospital text columns, and the manufacturer name and submitting name). Country and state in the manufacturer dimension are **not** uppercased.
- `max_temp_directory_size` stops DuckDB with an error instead of filling the disk.

```python
import duckdb

con = duckdb.connect("open_payments.duckdb")
con.execute("SET temp_directory = 'duck_tmp'")
con.execute("SET max_temp_directory_size = '20GB'")

def h(exprs):
    parts = ",".join(f"coalesce({e}::VARCHAR,'<NULL>')" for e in exprs)
    return f"md5(concat_ws('|',{parts}))"

def dim_cols(table, skip):
    return [r[0] for r in con.execute(f"DESCRIBE {table}").fetchall()][skip:]

# ---- physician ----
phys_src = ["Covered_Recipient_NPI","Covered_Recipient_Name_Suffix","Covered_Recipient_First_Name",
 "Covered_Recipient_Middle_Name","Covered_Recipient_Last_Name","Recipient_City","Recipient_Country",
 "Recipient_Postal_Code","Recipient_Province","Recipient_State","Recipient_Zip_Code",
 "Recipient_Primary_Business_Street_Address_Line1","Recipient_Primary_Business_Street_Address_Line2",
 "Covered_Recipient_License_State_code1","Covered_Recipient_License_State_code2",
 "Covered_Recipient_License_State_code3","Covered_Recipient_License_State_code4",
 "Covered_Recipient_License_State_code5","Covered_Recipient_Specialty_1","Covered_Recipient_Specialty_2",
 "Covered_Recipient_Type","Covered_Recipient_Primary_Type_1","Covered_Recipient_Primary_Type_2",
 "Covered_Recipient_Primary_Type_3","Covered_Recipient_Primary_Type_4","Covered_Recipient_Primary_Type_5",
 "Covered_Recipient_Primary_Type_6"]
phys_dim = dim_cols("dim_physician", 2)          # skips key + profile_id
assert len(phys_src) == len(phys_dim)
phys_h_src = h([f'p."{c}"' for c in phys_src])
phys_h_dim = h([f"ph.{c}" for c in phys_dim])

# ---- teaching hospital (UPPER on text, same as the dimension) ----
hosp_src = ["Teaching_Hospital_CCN","Teaching_Hospital_Name",
 "Recipient_Primary_Business_Street_Address_Line1","Recipient_Primary_Business_Street_Address_Line2",
 "Recipient_City","Recipient_State","Recipient_Zip_Code","Recipient_Country"]
hosp_dim = dim_cols("dim_teaching_hospital", 2)  # skips key + id
assert len(hosp_src) == len(hosp_dim)
hosp_h_src = h([f'p."{c}"' if c == "Teaching_Hospital_CCN" else f'UPPER(p."{c}")' for c in hosp_src])
hosp_h_dim = h([f"th.{c}" for c in hosp_dim])

# ---- manufacturer (UPPER only on the two name columns) ----
man_src = ["Applicable_Manufacturer_or_Applicable_GPO_Making_Pymnt_Cntry",
 "Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_Name",
 "Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_State",
 "Submitting_Applicable_Manufacturer_or_Applicable_GPO_Name"]
man_dim = ["manufacturer_country","manufacturer_name","manufacturer_state","submitting_manufacturer_gpo_name"]
upper_src = {"Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_Name",
             "Submitting_Applicable_Manufacturer_or_Applicable_GPO_Name"}
man_h_src = h([f'UPPER(p."{c}")' if c in upper_src else f'p."{c}"' for c in man_src])
man_h_dim = h([f"m.{c}" for c in man_dim])

# ---- product (30 columns, 34K-row dimension) ----
bases = ["Name_of_Drug_or_Biological_or_Device_or_Medical_Supply_",
         "Indicate_Drug_or_Biological_or_Device_or_Medical_Supply_",
         "Product_Category_or_Therapeutic_Area_","Associated_Drug_or_Biological_NDC_",
         "Associated_Device_or_Medical_Supply_PDI_","Covered_or_Noncovered_Indicator_"]
prod_src = [f"{b}{i}" for b in bases for i in range(1, 6)]
prod_dim = dim_cols("dim_product", 1)            # skips key
assert len(prod_src) == len(prod_dim)
prod_h_src = h([f'p."{c}"' for c in prod_src])
prod_h_dim = h([f"pr.{c}" for c in prod_dim])

con.execute(f"""
CREATE OR REPLACE TABLE fct_build AS
SELECT
  p."Record_ID"                                   AS record_id,
  ph.physician_key,
  th.teaching_hospital_key,
  m.manufacturer_key,
  pr.product_key,
  CAST(p."Date_of_Payment" AS DATE)               AS payment_date,
  d1.date_key                                     AS payment_date_key,
  CAST(p."Payment_Publication_Date" AS DATE)      AS payment_publication_date,
  d2.date_key                                     AS publication_date_key,
  p."Program_Year"                                AS payment_year,
  p."Related_Product_Indicator"                   AS related_product_indicator,
  p."Number_of_Payments_Included_in_Total_Amount" AS number_of_payments_included_in_total_amount,
  p."Total_Amount_of_Payment_USDollars"           AS total_payment_us_dollars,
  pf.payment_form_key,
  pn.payment_nature_key
FROM payments_src p
LEFT JOIN dim_physician ph
  ON p."Covered_Recipient_Profile_ID" = ph.physician_profile_id
 AND {phys_h_src} = {phys_h_dim}
LEFT JOIN dim_teaching_hospital th
  ON p."Teaching_Hospital_ID" = th.teaching_hospital_id
 AND {hosp_h_src} = {hosp_h_dim}
LEFT JOIN dim_manufacturer m
  ON p."Applicable_Manufacturer_or_Applicable_GPO_Making_Payment_ID" = m.manufacturer_id
 AND {man_h_src} = {man_h_dim}
LEFT JOIN dim_product pr
  ON {prod_h_src} = {prod_h_dim}
LEFT JOIN dim_date d1 ON CAST(p."Date_of_Payment" AS DATE) = d1.date
LEFT JOIN dim_date d2 ON CAST(p."Payment_Publication_Date" AS DATE) = d2.date
LEFT JOIN dim_payment_form pf   ON p."Form_of_Payment_or_Transfer_of_Value" = pf.form_of_payment
LEFT JOIN dim_payment_nature pn ON p."Nature_of_Payment_or_Transfer_of_Value" = pn.nature_of_payment
""")

print(con.execute("""
SELECT
  COUNT(*)                                                                                AS total_rows,
  COUNT(*) FILTER (WHERE physician_key IS NULL)                                           AS no_physician,
  COUNT(*) FILTER (WHERE teaching_hospital_key IS NULL)                                   AS no_hospital,
  COUNT(*) FILTER (WHERE physician_key IS NULL AND teaching_hospital_key IS NULL)         AS neither,
  COUNT(*) FILTER (WHERE physician_key IS NOT NULL AND teaching_hospital_key IS NOT NULL) AS both_keys,
  COUNT(*) FILTER (WHERE manufacturer_key IS NULL)                                        AS no_manufacturer,
  COUNT(*) FILTER (WHERE product_key IS NULL)                                             AS no_product,
  COUNT(*) FILTER (WHERE payment_date_key IS NULL)                                        AS no_date_key,
  COUNT(*) FILTER (WHERE publication_date_key IS NULL)                                    AS no_pub_date_key,
  COUNT(*) FILTER (WHERE payment_form_key IS NULL)                                        AS no_form,
  COUNT(*) FILTER (WHERE payment_nature_key IS NULL)                                      AS no_nature
FROM fct_build
""").fetchall())
con.close()
```

**Expected result (verified):**

| Check | Value |
|---|---|
| total_rows | 16,131,856 |
| no_physician | 35,569 (the teaching hospital rows) |
| no_hospital | 16,096,287 (the physician rows) |
| neither / both_keys | 0 / 0 |
| no_manufacturer, no_product, no_date_key, no_pub_date_key, no_form, no_nature | 0 |

If `total_rows` is higher than 16,131,856, a dimension has duplicate versions that match the same source row (for example, case-only duplicates). If a "no_..." number is above 0, a lookup failed, usually because of case or whitespace differences between the source and the dimension.

---

## 8. Load the fact table into PostgreSQL

### `load_fact.py`

DuckDB writes straight into PostgreSQL, so no CSV file or Docker copy is needed. The DuckDB connection must **not** be `read_only`, otherwise the attached PostgreSQL is also read-only and the insert is refused.

```python
import os
import duckdb

con = duckdb.connect("open_payments.duckdb")   # not read_only: Postgres must be writable
con.execute("INSTALL postgres; LOAD postgres;")

con.execute(f"""
ATTACH 'host=localhost port=5432 dbname=open_payments_dwh
        user={os.environ["PG_USER"]} password={os.environ["PG_PASSWORD"]}'
AS pg (TYPE postgres);
""")

LIMIT = "LIMIT 1000"   # test run. For the full load change to:  LIMIT = ""

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
```

**Steps**

1. Run it with `LIMIT = "LIMIT 1000"` and expect `(1000,)`.
2. Empty the table in PostgreSQL: `TRUNCATE stg.fct_payments RESTART IDENTITY;`
3. Set `LIMIT = ""` and run the full load (10 to 30 minutes, nothing prints until it finishes).
4. The final count must be **16,131,856**.

If the full load fails partway, run the `TRUNCATE` again before retrying.

---

## 9. PostgreSQL: checks, foreign keys, indexes

### Checks

```sql
SELECT
  COUNT(*)                                               AS total_rows,         -- 16,131,856
  COUNT(*) FILTER (WHERE physician_key IS NULL)          AS no_physician,       -- 35,569
  COUNT(*) FILTER (WHERE teaching_hospital_key IS NULL)  AS no_hospital,        -- 16,096,287
  COUNT(*) FILTER (WHERE manufacturer_key IS NULL)       AS no_manufacturer,    -- 0
  COUNT(*) FILTER (WHERE product_key IS NULL)            AS no_product,         -- 0
  COUNT(*) FILTER (WHERE payment_date_key IS NULL)       AS no_date_key,        -- 0
  COUNT(*) FILTER (WHERE publication_date_key IS NULL)   AS no_pub_date_key,    -- 0
  COUNT(*) FILTER (WHERE payment_form_key IS NULL)       AS no_form,            -- 0
  COUNT(*) FILTER (WHERE payment_nature_key IS NULL)     AS no_nature           -- 0
FROM stg.fct_payments;
```

### Foreign keys

Run one at a time, since each checks 16M rows.

```sql
ALTER TABLE stg.fct_payments ADD FOREIGN KEY (physician_key)          REFERENCES stg.dim_physician(physician_key);
ALTER TABLE stg.fct_payments ADD FOREIGN KEY (teaching_hospital_key)  REFERENCES stg.dim_teaching_hospital(teaching_hospital_key);
ALTER TABLE stg.fct_payments ADD FOREIGN KEY (manufacturer_key)       REFERENCES stg.dim_manufacturer(manufacturer_key);
ALTER TABLE stg.fct_payments ADD FOREIGN KEY (product_key)            REFERENCES stg.dim_product(product_key);
ALTER TABLE stg.fct_payments ADD FOREIGN KEY (payment_date_key)       REFERENCES stg.dim_date(date_key);
ALTER TABLE stg.fct_payments ADD FOREIGN KEY (publication_date_key)   REFERENCES stg.dim_date(date_key);
ALTER TABLE stg.fct_payments ADD FOREIGN KEY (payment_form_key)       REFERENCES stg.dim_payment_form(payment_form_key);
ALTER TABLE stg.fct_payments ADD FOREIGN KEY (payment_nature_key)     REFERENCES stg.dim_payment_nature(payment_nature_key);
```

### Indexes (non-unique, including `record_id`)

```sql
CREATE INDEX ON stg.fct_payments (record_id);
CREATE INDEX ON stg.fct_payments (physician_key);
CREATE INDEX ON stg.fct_payments (teaching_hospital_key);
CREATE INDEX ON stg.fct_payments (manufacturer_key);
CREATE INDEX ON stg.fct_payments (product_key);
CREATE INDEX ON stg.fct_payments (payment_date_key);
ANALYZE stg.fct_payments;
```

### Sample query

```sql
SELECT m.manufacturer_name,
       ROUND(SUM(f.total_payment_us_dollars)::numeric, 2) AS total_usd
FROM stg.fct_payments f
JOIN stg.dim_manufacturer m ON m.manufacturer_key = f.manufacturer_key
GROUP BY 1 ORDER BY 2 DESC LIMIT 5;
```

---

## 10. Lessons learned and troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| 42,823 missing recipient keys in the first test | 35,569 teaching hospital rows plus 7,254 physician rows with NULL NPI (a plain `=` never matches NULL) | Separate `dim_physician` and `dim_teaching_hospital`, keep NULL-NPI physicians, compare nullable columns null-safely |
| Joins "stuck" for a long time | `IS NOT DISTINCT FROM` on many columns prevents a fast hash join | Join on one `md5` hash per side |
| Hospital dimension had 3,280 rows for 1,296 IDs | 998 rows differed only by letter case | `UPPER` on the text columns (dimension and join) |
| 13.5M rows with no manufacturer | Manufacturer names are uppercase in the dimension and mixed case in the source | `UPPER` on the two name columns on the source side |
| Fact build filled the disk | `dim_product` held every product about 430 times, so the join multiplied rows | Reload `dim_product` with `SELECT DISTINCT` (34,655 rows) |
| About 1.3M rows had no product key | The first product load excluded products with no name | Load all distinct combinations, no name filter |
| `open_payments.duckdb` grew to 60+ GB | DuckDB does not return space after `CREATE OR REPLACE TABLE` and failed queries | Copy the tables into a fresh file with `compact_db.py`, then swap the files |
| Docker used most of the disk | Docker's virtual disk file does not shrink on its own | Prune build cache and unused images, never delete volumes |
| `INSERT` refused: "attached in read-only mode" | `read_only=True` on the DuckDB connection makes the attached Postgres read-only too | Connect without `read_only` for the load |
| `docker cp` of the CSV was unreliable | Large file, closed-pipe error | Write directly from DuckDB with `load_fact.py` |

### `compact_db.py` (maintenance only)

Run this if `open_payments.duckdb` becomes much larger than the data inside it. It writes a fresh, compact file next to the old one. Check that every line says `OK`, then replace the old file.

```python
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

con.close()
```

```powershell
Remove-Item open_payments.duckdb
Rename-Item compact.duckdb open_payments.duckdb
```

Only delete the old file after every table says `OK`.

---

## 11. Known limitations and next steps

- `total_payment_us_dollars` is `DOUBLE PRECISION`, which can show floating-point noise in sums. For reports that must match to the cent, change it to `NUMERIC(14,2)`.
- `dim_manufacturer` has one row per name/state/country version. To total by company, group by `manufacturer_id`, not by name.
- About 16 source columns (for example `Change_Type`, `Contextual_Information`, `Charity_Indicator`, the `*_of_Travel` columns) are not in the warehouse yet. They remain in `stg.general_payments_2025_clean` and can be added to the fact table or a new dimension.
- `fct_build` can be dropped from the DuckDB file after the load to save space.
