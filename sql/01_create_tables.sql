
CREATE SCHEMA IF NOT EXISTS council_spending;
USE council_spending;

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
) ENGINE = InnoDB;

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
    supplier_flag BOOLEAN,
    recorded_spend INT,
    pending_spend INT,
    paid_spend INT,
    Variance_GBP DECIMAL(14,2),
    Variance_pct DECIMAL(18,6),
    Supplier_Share_Of_Council_Pct DECIMAL(18,6),
    description_column VARCHAR(500),
    CONSTRAINT chk_currency CHECK (currency = 'GBP'),
    CONSTRAINT chk_payment_status
        CHECK (payment_status IN ('paid', 'under review', 'approved', 'pending', 'cancelled'))
) ENGINE = InnoDB;

CREATE TABLE accepted_data_import LIKE accepted_data;

-- Exception details for each audit run.
CREATE TABLE IF NOT EXISTS rejected_data (
    exception_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    audit_run_id BIGINT NOT NULL,
    transaction_id VARCHAR(100),
    transaction_date_raw VARCHAR(100),
    reason_code VARCHAR(100) NOT NULL,
    INDEX (audit_run_id),
    FOREIGN KEY (audit_run_id) REFERENCES load_audit(run_id)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS review_data (
    exception_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    audit_run_id BIGINT NOT NULL,
    transaction_id VARCHAR(100),
    actual_spend_gbp DECIMAL(14,2),
    reason_code VARCHAR(100) NOT NULL,
    INDEX (audit_run_id),
    FOREIGN KEY (audit_run_id) REFERENCES load_audit(run_id)
) ENGINE = InnoDB;

SHOW FULL TABLES FROM council_spending;