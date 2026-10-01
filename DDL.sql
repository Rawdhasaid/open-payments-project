 --CREATE STATEMENTS 
 
 CREATE TABLE stg.dim_manufacturer (
    manufacturer_key SERIAL,
    manufacturer_id BIGINT UNIQUE,
    manufacturer_country VARCHAR(50),
    manufacturer_name VARCHAR(200),
    manufacturer_state VARCHAR(50),
    submitting_manufacturer_gpo_name VARCHAR(200),
    PRIMARY KEY(manufacturer_key)
);

CREATE TABLE STG.dim_payment_form (
    payment_form_key serial,
    form_of_payment VARCHAR(150),
    PRIMARY KEY(payment_form_key)
);

CREATE TABLE STG.dim_payment_nature (
    payment_nature_key serial,
    nature_of_payment VARCHAR(250),
    PRIMARY KEY(payment_nature_key)
);
CREATE TABLE STG.Dim_Date (
    date_key integer ,
    date DATE  unique,
    day_of_month INT,
    day_name VARCHAR(20),
    day_of_week INT,
    week_of_year INT,
    month_number INT,
    month_name VARCHAR(20),
    quarter_number INT,
    year_number INT,
    year_month INT,
    year_quarter INT,
    is_weekend VARCHAR(10),
    is_holiday VARCHAR(10),
    PRIMARY KEY(date_key)
);

CREATE TABLE STG.Dim_Product (
    product_key serial ,
    name_of_drug_or_biological_or_device_or_medical_supply_1 VARCHAR(500),
    name_of_drug_or_biological_or_device_or_medical_supply_2 VARCHAR(500),
    name_of_drug_or_biological_or_device_or_medical_supply_3 VARCHAR(500),
    name_of_drug_or_biological_or_device_or_medical_supply_4 VARCHAR(500),
    name_of_drug_or_biological_or_device_or_medical_supply_5 VARCHAR(500),
    indicate_drug_or_biological_or_device_or_medical_supply_1 VARCHAR(50),
    indicate_drug_or_biological_or_device_or_medical_supply_2 VARCHAR(50),
    indicate_drug_or_biological_or_device_or_medical_supply_3 VARCHAR(50),
    indicate_drug_or_biological_or_device_or_medical_supply_4 VARCHAR(50),
    indicate_drug_or_biological_or_device_or_medical_supply_5 VARCHAR(50),
    product_category_or_therapeutic_area_1 VARCHAR(500),
    product_category_or_therapeutic_area_2 VARCHAR(500),
    product_category_or_therapeutic_area_3 VARCHAR(500),
    product_category_or_therapeutic_area_4 VARCHAR(500),
    product_category_or_therapeutic_area_5 VARCHAR(500),
    associated_drug_or_biological_ndc_1 VARCHAR(50),
    associated_drug_or_biological_ndc_2 VARCHAR(50),
    associated_drug_or_biological_ndc_3 VARCHAR(50),
    associated_drug_or_biological_ndc_4 VARCHAR(50),
    associated_drug_or_biological_ndc_5 VARCHAR(50),
    associated_device_or_medical_supply_pdi_1 VARCHAR(50),
    associated_device_or_medical_supply_pdi_2 VARCHAR(50),
    associated_device_or_medical_supply_pdi_3 VARCHAR(50),
    associated_device_or_medical_supply_pdi_4 VARCHAR(50),
    associated_device_or_medical_supply_pdi_5 VARCHAR(50),
    covered_or_noncovered_indicator_1 VARCHAR(20),
    covered_or_noncovered_indicator_2 VARCHAR(20),
    covered_or_noncovered_indicator_3 VARCHAR(20),
    covered_or_noncovered_indicator_4 VARCHAR(20),
    covered_or_noncovered_indicator_5 VARCHAR(20),
    PRIMARY KEY(product_key)
);

--POSTGRES FACT DDL
CREATE TABLE STG.fct_payments (
    payment_key SERIAL,
    record_id BIGINT UNIQUE,
    physician_key BIGINT REFERENCES stg.Dim_physician(physician_key),
    teaching_hospital_key BIGINT REFERENCES stg.Dim_Teaching_Hospital(teaching_hospital_key),
    manufacturer_key BIGINT REFERENCES stg.dim_manufacturer(manufacturer_key),
    product_key BIGINT REFERENCES stg.Dim_Product(product_key),
    payment_date DATE,
    payment_date_key BIGINT REFERENCES stg.dim_date(date_key),
    payment_publication_date DATE,
    publication_date_key BIGINT REFERENCES stg.dim_date(date_key),
    payment_year BIGINT,
    related_product_indicator VARCHAR(50),
    number_of_payments_included_in_total_amount BIGINT,
    total_payment_us_dollars DOUBLE PRECISION,
    payment_form_key BIGINT REFERENCES stg.dim_payment_form(payment_form_key),
    payment_nature_key BIGINT REFERENCES stg.dim_payment_nature(payment_nature_key),
        PRIMARY KEY( payment_key)
); 

--DUCKDB FACT DDL 

--- duck bd usage create statement 

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

--initial Dim Recipient DDL 

CREATE TABLE STG.Dim_Recipient (
    recipient_key serial,
    recipient_profile_id BIGINT unique,
    recipient_npi BIGINT unique,
    recipient_name_suffix VARCHAR(10),
    recipient_first_name VARCHAR(100),
    recipient_middle_name VARCHAR(100),
    recipient_last_name VARCHAR(100),
    recipient_city VARCHAR(100),
    recipient_country VARCHAR(100),
    recipient_postal_code VARCHAR(50),
    recipient_province VARCHAR(100),
    recipient_state VARCHAR(50),
    recipient_zip_code VARCHAR(50),
    recipient_street_address_line1 VARCHAR(200),
    recipient_street_address_line2 VARCHAR(200),
    recipient_license_state_cd1 VARCHAR(50),
    recipient_license_state_cd2 VARCHAR(50),
    recipient_license_state_cd3 VARCHAR(50),
    recipient_license_state_cd4 VARCHAR(50),
    recipient_license_state_cd5 VARCHAR(50),
    recipient_specialty_1 VARCHAR(150),
    recipient_specialty_2 VARCHAR(150),
    recipient_type VARCHAR(100),
    recipient_primary_type_1 VARCHAR(150),
    recipient_primary_type_2 VARCHAR(150),
    recipient_primary_type_3 VARCHAR(150),
    recipient_primary_type_4 VARCHAR(150),
    recipient_primary_type_5 VARCHAR(150),
    recipient_primary_type_6 VARCHAR(150),
    PRIMARY KEY(recipient_key)
);

-- After having Nulls as an FK and after checking the reason , most are reffering to teaching hospital so dimension names has been modified to be physician and created another dimension which is teaching hosiptal 

 alter table stg.dim_recipient rename to dim_physician;
  alter table stg.dim_physician rename column recipient_key  to physician_key;


ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_profile_id TO physician_profile_id;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_npi TO physician_npi;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_name_suffix TO physician_name_suffix;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_first_name TO physician_first_name;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_middle_name TO physician_middle_name;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_last_name TO physician_last_name;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_city TO physician_city;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_country TO physician_country;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_postal_code TO physician_postal_code;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_province TO physician_province;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_state TO physician_state;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_zip_code TO physician_zip_code;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_street_address_line1 TO physician_street_address_line1;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_street_address_line2 TO physician_street_address_line2;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_license_state_cd1 TO physician_license_state_cd1;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_license_state_cd2 TO physician_license_state_cd2;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_license_state_cd3 TO physician_license_state_cd3;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_license_state_cd4 TO physician_license_state_cd4;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_license_state_cd5 TO physician_license_state_cd5;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_specialty_1 TO physician_specialty_1;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_specialty_2 TO physician_specialty_2;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_type TO physician_type;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_primary_type_1 TO physician_primary_type_1;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_primary_type_2 TO physician_primary_type_2;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_primary_type_3 TO physician_primary_type_3;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_primary_type_4 TO physician_primary_type_4;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_primary_type_5 TO physician_primary_type_5;

ALTER TABLE stg.dim_physician
RENAME COLUMN recipient_primary_type_6 TO physician_primary_type_6;

 create table stg.Dim_Teaching_Hospital(
        Teaching_Hospital_Key Serial,
        Teaching_Hospital_ID Bigint,
        Teaching_Hospital_CCN VARCHAR(6),
        Teaching_Hospital_Name VARCHAR(50),
        Teaching_Hospital_street_address_line1 VARCHAR(200),
		Teaching_Hospital_street_address_line2 VARCHAR(200),
        Teaching_Hospital_city VARCHAR(100),
        Teaching_Hospital_state VARCHAR(50),
		Teaching_Hospital_zip_code VARCHAR(50),
        Teaching_Hospital_country VARCHAR(100),
        Primary key(Teaching_Hospital_Key)
       
        );