CREATE SCHEMA IF NOT EXISTS council_spending;
use council_spending;

CREATE TABLE load_audit (
    run_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    source_filename VARCHAR(255),
    started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    ended_at DATETIME,
    input_count INT,
    accepted_count INT,
    rejected_count INT,
    review_count INT,
    staged_count INT,
    final_count INT,
    status VARCHAR(30),
    error_message TEXT
);

SHOW TABLES;
DESCRIBE load_audit;
SELECT * FROM load_audit;

CREATE TABLE accepted_data (
    transaction_id VARCHAR(100) PRIMARY KEY,
    transaction_date DATE NOT NULL,
    council_name VARCHAR(255) NOT NULL,
    department VARCHAR(255) NOT NULL,
    spend_category VARCHAR(255),
    supplier_name VARCHAR(500),

    actual_spend_gbp DECIMAL(14,2),
    budget_amount_gbp DECIMAL(14,2),

    spend_type VARCHAR(100),
    payment_status VARCHAR(500),
    procurement_method VARCHAR(255),
    funding_source VARCHAR(255),
    currency VARCHAR(10),
    supplier_flag bool,
    recorded_spend INT,
    pending_spend INT,
    paid_spend INT,
    Variance_GBP DECIMAL(14,2),
    Variance_pct DECIMAL(18,6),
    Supplier_Share_Of_Council_Pct DECIMAL(18,6)
);
alter table accepted_data
add column description_column varchar(500);

alter table accepted_data
modify column supplier_flag bool;

select* from accepted_data;

alter table accepted_data
add constraint chk_currency 
check (currency in ('GBP'));

alter table accepted_data
add constraint chk_payment_status 
check ( payment_status in ('paid','under review','approved','pending','cancelled'));


select count(*) as count_column from information_schema.columns 
where table_schema = 'council_spending' and table_name='accepted_data';

CREATE TABLE council_spending.accepted_data_import
LIKE council_spending.accepted_data;

