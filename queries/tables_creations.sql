 BANK_TRANSACTIONS Table
CREATE TABLE BANK_TRANSACTIONS (
    trans_id    VARCHAR2(30) PRIMARY KEY,
    account_id  VARCHAR2(20) NOT NULL,
    trans_type  VARCHAR2(15) NOT NULL CHECK (trans_type IN ('WITHDRAWAL', 'DEPOSIT')),
    amount      NUMBER(15,2) NOT NULL,
    trans_date  DATE DEFAULT SYSDATE,
    batch_id    VARCHAR2(20),
    status      VARCHAR2(15) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'FLAGGED', 'CLEARED'))
);


2. FDTMS_AUDIT_LOG Table
CREATE TABLE FDTMS_AUDIT_LOG (
    alert_id             NUMBER GENERATED AS IDENTITY PRIMARY KEY,
    trans_id             VARCHAR2(30) NOT NULL,
    amount               NUMBER(15,2) NOT NULL,
    alert_reason         VARCHAR2(50) DEFAULT 'HIGH_VALUE_WITHDRAWAL',
    detected_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processing_halted    CHAR(1) DEFAULT 'Y' CHECK (processing_halted IN ('Y', 'N'))
);

COMMIT;

