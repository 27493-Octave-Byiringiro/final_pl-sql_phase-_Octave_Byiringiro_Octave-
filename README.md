

# 🛡️ FDTMS – Oracle PL/SQL Circuit Breaker

**Project Title:** Fraud Detection & Transaction Monitoring System (FDTMS): Real-Time High-Value Withdrawal Detection and Automated Processing Halt Using Oracle PL/SQL

| Detail | Value |
| :--- | :--- |
| **Student** | Byiringiro Octave |
| **Student ID** | 27493 |
| **Project Goal** | Final phase – Problem Project Implementation |
## Problem Definition

Commercial banks in East Africa and worldwide lose hundreds of millions annually due to
unauthorized high-value withdrawals executed during automated nightly batch processing. Current
core banking systems process thousands of transactions blindly without real-time risk checks.
A single withdrawal of $50,000 or more, if fraudulent or mistaken, can cause irreversible financial
and reputational damage before human review occurs the next day.
There is no mechanism in most legacy batch systems to immediately halt processing upon detecting
a high-risk transaction.

## Overview: Zero-Latency Security

The FDTMS project implements a mission-critical backend solution to enforce **zero-latency security** during high-volume transaction batch processing. It uses advanced Oracle PL/SQL features to create a **database-level Circuit Breaker** that instantly halts the entire batch process upon detecting a high-value withdrawal ($\ge \$50,000$), preventing data corruption and guaranteeing auditability.

##  Features: Core Security Guarantees

  * **Instant Halt (`GOTO` Logic):** Processing stops immediately upon detection, bypassing all remaining loop iterations to prevent execution of fraudulent or subsequent transactions.
  * **Guaranteed Rollback:** A forced **`ROLLBACK`** command ensures any transactions processed just before the halt are reverted to their initial **`PENDING`** state, preserving data safety.
  * **Unbreakable Audit Log:** Uses **`PRAGMA AUTONOMOUS_TRANSACTION`** to permanently commit the security event to the audit log, independent of the main transaction's rollback status.
  * **Operational Control:** An autonomous procedure updates the `FDTMS_BATCH_CONTROL` table to **`HALTED`**, serving as the master switch for human review and resumption.
  * **Resilience:** Allows for safe, controlled resumption of the batch process after the flagged transaction is manually cleared by an analyst.

## ⚙️ Technology Stack

| Component | Technology | Role |
| :--- | :--- | :--- |
| **Backend Logic** | Oracle PL/SQL (Procedures and Types) | Primary implementation language for core logic and autonomous functions. |
| **Database** | Oracle Database (23c Free recommended) | Stores all transactional and control tables. |
| **Core Mechanism** | `PRAGMA AUTONOMOUS_TRANSACTION`, `GOTO`, `RAISE_APPLICATION_ERROR` | The PL/SQL features implementing the Circuit Breaker. |
| **Tools** | SQL\*Plus / SQL Developer | Environment used for script execution and development. |

## Prerequisites

  * **Oracle Database Instance:** Access to an Oracle Database instance.
  * **SQL Client:** Any client capable of executing PL/SQL (e.g., SQL\*Plus, SQL Developer).
  * **Permissions:** System Administrator access is required for initial setup.

-----

##  Setup: Step-by-Step Installation

Execute these steps in order using your SQL client.

### Step 1: PDB and User Configuration (Phase IV)

This section creates the PDB, tablespaces, and the project user. **NOTE: `Your_SYS_Password` must be replaced with the actual password for your `SYS` account.**

#### A. Create and Open the PDB (Run in **CDB** as `SYS AS SYSDBA`)

```sql
CONNECT SYS/Your_SYS_Password AS SYSDBA;

 DROP PLUGGABLE DATABASE all_27493_octave_fdtms_db INCLUDING DATAFILES;

 CREATE PLUGGABLE DATABASE all_27493_octave_fdtms_db
ADMIN USER fdtms_admin IDENTIFIED BY octave
CREATE_FILE_DEST = 'C:\APP\BOCTAVE\PRODUCT\23AI\ORADATA\FREE\';

 ALTER PLUGGABLE DATABASE all_27493_octave_fdtms_db OPEN READ WRITE;
```

#### B. Tablespace and Project Owner Setup (Run in **PDB** as `SYS AS SYSDBA`)

```sql
 CONNECT SYS/Your_SYS_Password@//localhost/all_27493_octave_fdtms_db AS SYSDBA;

 CREATE TABLESPACE FDTMS_DATA
DATAFILE 'fdtms_data01.dbf' SIZE 100M AUTOEXTEND ON NEXT 10M MAXSIZE UNLIMITED;

CREATE TABLESPACE FDTMS_INDEX
DATAFILE 'fdtms_index01.dbf' SIZE 50M AUTOEXTEND ON NEXT 5M MAXSIZE 500M;

 CREATE USER FDTMS_TEMP_OCTAVE IDENTIFIED BY octave
DEFAULT TABLESPACE FDTMS_DATA
QUOTA UNLIMITED ON FDTMS_DATA;

 GRANT CONNECT, RESOURCE, CREATE SESSION, CREATE TYPE, CREATE PROCEDURE, PDB_DBA, RESTRICTED SESSION
TO FDTMS_TEMP_OCTAVE;

DISCONNECT;
```

#### C. Connect as the Project Owner

```sql
CONNECT FDTMS_TEMP_OCTAVE/octave@//localhost/all_27493_octave_fdtms_db
```

### Step 2: Create Tables and Types (Phase V)

Run these scripts as the connected project user (`FDTMS_TEMP_OCTAVE`).

```sql
 CREATE TABLE BANK_TRANSACTIONS (
    trans_id    VARCHAR2(30) PRIMARY KEY,
    account_id  VARCHAR2(20) NOT NULL,
    trans_type  VARCHAR2(15) NOT NULL CHECK (trans_type IN ('WITHDRAWAL', 'DEPOSIT')),
    amount      NUMBER(15,2) NOT NULL,
    trans_date  DATE DEFAULT SYSDATE,
    batch_id    VARCHAR2(20),
    status      VARCHAR2(15) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'FLAGGED', 'CLEARED'))
);

 CREATE TABLE FDTMS_AUDIT_LOG (
    alert_id             NUMBER GENERATED AS IDENTITY PRIMARY KEY,
    trans_id             VARCHAR2(30) NOT NULL,
    amount               NUMBER(15,2) NOT NULL,
    alert_reason         VARCHAR2(50) DEFAULT 'HIGH_VALUE_WITHDRAWAL',
    detected_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processing_halted    CHAR(1) DEFAULT 'Y' CHECK (processing_halted IN ('Y', 'N'))
);

 CREATE TABLE FDTMS_BATCH_CONTROL ( 
    batch_id VARCHAR2(20) PRIMARY KEY, 
    status VARCHAR2(15) NOT NULL CHECK (status IN ('RUNNING', 'HALTED', 'COMPLETED')), 
    halt_reason VARCHAR2(100), 
    halt_transaction_id VARCHAR2(30), 
    halt_timestamp TIMESTAMP, 
    review_status VARCHAR2(15) DEFAULT 'PENDING' 
);
COMMIT;

 CREATE TYPE transaction_rec AS OBJECT (
    trans_id VARCHAR2(30), account_id VARCHAR2(20), trans_type VARCHAR2(15), 
    amount NUMBER(15,2), trans_date DATE, batch_id VARCHAR2(20)
);
/
CREATE TYPE transaction_tab IS TABLE OF transaction_rec;
/
```

### Step 3: Create Autonomous Procedures (Phase VI)

Run these scripts as the connected project user (`FDTMS_TEMP_OCTAVE`).

```sql
 CREATE OR REPLACE PROCEDURE log_fraud_alert (
    p_trans_id IN VARCHAR2, p_amount IN NUMBER
)
IS
    PRAGMA AUTONOMOUS_TRANSACTION; 
BEGIN
    INSERT INTO FDTMS_AUDIT_LOG (trans_id, amount) VALUES (p_trans_id, p_amount);
    COMMIT; 
EXCEPTION
    WHEN OTHERS THEN ROLLBACK; RAISE; 
END log_fraud_alert;
/

 CREATE OR REPLACE PROCEDURE update_batch_status (
    p_batch_id    IN VARCHAR2, p_new_status  IN VARCHAR2,
    p_reason      IN VARCHAR2 DEFAULT NULL, p_trans_id    IN VARCHAR2 DEFAULT NULL
)
IS
    PRAGMA AUTONOMOUS_TRANSACTION; 
BEGIN
    UPDATE FDTMS_BATCH_CONTROL
    SET status = p_new_status, halt_reason = p_reason, halt_transaction_id = p_trans_id,
        halt_timestamp = CASE WHEN p_new_status = 'HALTED' THEN CURRENT_TIMESTAMP ELSE NULL END,
        review_status = CASE WHEN p_new_status = 'HALTED' THEN 'PENDING' ELSE 'N/A' END
    WHERE batch_id = p_batch_id;

    IF SQL%ROWCOUNT = 0 THEN
        INSERT INTO FDTMS_BATCH_CONTROL (batch_id, status) VALUES (p_batch_id, p_new_status);
    END IF;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN ROLLBACK; RAISE;
END update_batch_status;
/
```

### Step 4: Create Main Logic Procedure (The Circuit Breaker - Phase VI)

```sql
CREATE OR REPLACE PROCEDURE process_batch_transactions (
    p_transactions IN transaction_tab, p_batch_id IN VARCHAR2
)
AS
    c_fraud_threshold CONSTANT NUMBER := 50000.00;
    v_halt_detected BOOLEAN := FALSE;
    v_flagged_trans_id VARCHAR2(30);
BEGIN
    IF p_transactions IS NULL OR p_transactions.COUNT = 0 THEN RETURN; END IF;

    FOR i IN 1 .. p_transactions.COUNT LOOP
        
        IF p_transactions(i).trans_type = 'WITHDRAWAL' AND p_transactions(i).amount >= c_fraud_threshold THEN
        
             log_fraud_alert(p_transactions(i).trans_id, p_transactions(i).amount);
            update_batch_status(p_batch_id, 'HALTED', 'FDTMS High-Value Alert', p_transactions(i).trans_id);

            v_flagged_trans_id := p_transactions(i).trans_id;
            v_halt_detected := TRUE;
            
             GOTO HALT_POINT; 
        END IF;

         UPDATE BANK_TRANSACTIONS SET status = 'CLEARED'
        WHERE trans_id = p_transactions(i).trans_id AND batch_id = p_batch_id AND status = 'PENDING';
        
    END LOOP;
    
     IF NOT v_halt_detected THEN
        update_batch_status(p_batch_id, 'COMPLETED');
        COMMIT; 
    END IF;

     <<HALT_POINT>>
    IF v_halt_detected THEN
         ROLLBACK; 
        
         RAISE_APPLICATION_ERROR(-20001, 'FDTMS_HALT: Batch processing aborted due to high-risk withdrawal: ' || v_flagged_trans_id);
    END IF;

END process_batch_transactions;
/
```

-----

## 🔬 Testing: Full End-to-End Validation (Batch B004)

### Phase 1: Data Setup

```sql
 DELETE FROM BANK_TRANSACTIONS WHERE batch_id = 'B004';
DELETE FROM FDTMS_BATCH_CONTROL WHERE batch_id = 'B004';
DELETE FROM FDTMS_AUDIT_LOG WHERE trans_id = 'T016';
COMMIT;

 INSERT INTO BANK_TRANSACTIONS (trans_id, account_id, trans_type, amount, batch_id, status) VALUES ('T015', 'ACCT4001', 'DEPOSIT', 10000.00, 'B004', 'PENDING');
INSERT INTO BANK_TRANSACTIONS (trans_id, account_id, trans_type, amount, batch_id, status) VALUES ('T016', 'ACCT4002', 'WITHDRAWAL', 60000.00, 'B004', 'PENDING'); 
INSERT INTO BANK_TRANSACTIONS (trans_id, account_id, trans_type, amount, batch_id, status) VALUES ('T017', 'ACCT4003', 'WITHDRAWAL', 5000.00, 'B004', 'PENDING');
INSERT INTO BANK_TRANSACTIONS (trans_id, account_id, trans_type, amount, batch_id, status) VALUES ('T018', 'ACCT4004', 'DEPOSIT', 25000.00, 'B004', 'PENDING');
COMMIT;

EXEC update_batch_status(p_batch_id => 'B004', p_new_status => 'RUNNING');
COMMIT;
```

### Phase 2: Run 1 - Execution and Verification (The Halt Test)

```sql
 SET SERVEROUTPUT ON;
DECLARE
    v_transaction_batch transaction_tab := transaction_tab();
BEGIN
    SELECT transaction_rec(trans_id, account_id, trans_type, amount, trans_date, batch_id)
    BULK COLLECT INTO v_transaction_batch
    FROM BANK_TRANSACTIONS WHERE batch_id = 'B004' ORDER BY trans_id;
    process_batch_transactions(v_transaction_batch, 'B004');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Execution finished with status: ' || SQLERRM);
END;
/
 
-- 3. VERIFICATION (Check Security Guarantees)
-- Operational Control Check (EXPECTED: HALTED, T016)
SELECT batch_id, status, halt_transaction_id FROM FDTMS_BATCH_CONTROL WHERE batch_id = 'B004';
-- Data Safety (Rollback Check) (EXPECTED: All PENDING)
SELECT trans_id, status FROM BANK_TRANSACTIONS WHERE batch_id = 'B004';
-- Audit Integrity Check (EXPECTED: T016 logged with processing_halted = Y)
SELECT trans_id, amount, processing_halted FROM FDTMS_AUDIT_LOG WHERE trans_id = 'T016';
```

### Phase 3: Run 2 - Manual Clearance and Resumption

```sql
-- 4. MANUAL INTERVENTION
-- Analyst clears the fraud (T016) and resets the switch.
UPDATE BANK_TRANSACTIONS SET status = 'CLEARED' WHERE trans_id = 'T016';
EXEC update_batch_status(p_batch_id => 'B004', p_new_status => 'RUNNING');
COMMIT;

-- 5. EXECUTE RESUME (Run 2)
SET SERVEROUTPUT ON;
DECLARE
    v_transaction_batch transaction_tab := transaction_tab();
BEGIN
    SELECT transaction_rec(trans_id, account_id, trans_type, amount, trans_date, batch_id)
    BULK COLLECT INTO v_transaction_batch
    FROM BANK_TRANSACTIONS WHERE batch_id = 'B004' ORDER BY trans_id;
    process_batch_transactions(v_transaction_batch, 'B004');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Execution finished with status: ' || SQLERRM);
END;
/
-- EXPECTED OUTPUT: PL/SQL procedure successfully completed.

-- 6. FINAL VALIDATION (Check Resilience)
-- Final State Check (EXPECTED: COMPLETED)
SELECT batch_id, status FROM FDTMS_BATCH_CONTROL WHERE batch_id = 'B004';
-- Final Data Status Check (EXPECTED: All CLEARED)
SELECT trans_id, status FROM BANK_TRANSACTIONS WHERE batch_id = 'B004';
```
