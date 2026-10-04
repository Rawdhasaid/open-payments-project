-- Payment Fact 
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
-- product Dimension 
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
-- Date Dimension 
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
-- Manufacturer Dimension
 CREATE TABLE stg.dim_manufacturer (
    manufacturer_key SERIAL,
    manufacturer_id BIGINT UNIQUE,
    manufacturer_country VARCHAR(50),
    manufacturer_name VARCHAR(200),
    manufacturer_state VARCHAR(50),
    submitting_manufacturer_gpo_name VARCHAR(200),
    PRIMARY KEY(manufacturer_key)
);

-- Payment Form Dimension 
CREATE TABLE STG.dim_payment_form (
    payment_form_key serial,
    form_of_payment VARCHAR(150),
    PRIMARY KEY(payment_form_key)
);
-- Payment nature Dimension 
CREATE TABLE STG.dim_payment_nature (
    payment_nature_key serial,
    nature_of_payment VARCHAR(250),
    PRIMARY KEY(payment_nature_key)
);

-- Physician Dimension
CREATE TABLE STG.Dim_physician (
    physician_key serial,
    physician_profile_id BIGINT unique,
    physician_npi BIGINT unique,
    physician_name_suffix VARCHAR(50),
    physician_first_name VARCHAR(100),
    physician_middle_name VARCHAR(100),
    physician_last_name VARCHAR(100),
    physician_city VARCHAR(100),
    physician_country VARCHAR(100),
    physician_postal_code VARCHAR(50),
    physician_province VARCHAR(100),
    physician_state VARCHAR(50),
    physician_zip_code VARCHAR(50),
    physician_street_address_line1 VARCHAR(200),
    physician_street_address_line2 VARCHAR(200),
    physician_license_state_cd1 VARCHAR(50),
    physician_license_state_cd2 VARCHAR(50),
    physician_license_state_cd3 VARCHAR(50),
    physician_license_state_cd4 VARCHAR(50),
    physician_license_state_cd5 VARCHAR(50),
    physician_specialty_1 VARCHAR(150),
    physician_specialty_2 VARCHAR(150),
    physician_type VARCHAR(100),
    physician_primary_type_1 VARCHAR(150),
    physician_primary_type_2 VARCHAR(150),
    physician_primary_type_3 VARCHAR(150),
    physician_primary_type_4 VARCHAR(150),
    physician_primary_type_5 VARCHAR(150),
    physician_primary_type_6 VARCHAR(150),
    PRIMARY KEY(physician_key)
);
-- Teaching Hospital Dimension 
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
