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
1. transaction_rec Object Type
CREATE TYPE transaction_rec AS OBJECT (
    trans_id VARCHAR2(30),
    account_id VARCHAR2(20),
    trans_type VARCHAR2(15),
    amount NUMBER(15,2),
    trans_date DATE,
    batch_id VARCHAR2(20)
);
/
2. transaction_tab Nested Table Type
CREATE TYPE transaction_tab IS TABLE OF transaction_rec;
/
Procedure: log_fraud_alert
CREATE OR REPLACE PROCEDURE log_fraud_alert (
    p_trans_id IN VARCHAR2,
    p_amount IN NUMBER
)
IS
     PRAGMA AUTONOMOUS_TRANSACTION; 
BEGIN
     INSERT INTO FDTMS_AUDIT_LOG (trans_id, amount)
    VALUES (p_trans_id, p_amount);

     COMMIT; 

EXCEPTION
    WHEN OTHERS THEN
         ROLLBACK;
         RAISE; 
END log_fraud_alert;
/
CREATE OR REPLACE PROCEDURE process_batch_transactions (
    p_transactions IN transaction_tab,
    p_batch_id     IN VARCHAR2
)
AS
    --------------------------------------------------------------------------------
    -- FDTMS_BATCH_PROCESS: Real-Time High-Value Withdrawal Detection
    -- Purpose: Simulates core banking batch processing, detects high-risk withdrawals
    --          (>= $50,000), and uses GOTO to instantly halt processing and ROLLBACK
    --          all pending transactions in the batch.
    -- Parameters:
    --   p_transactions: Collection (Nested Table) of transactions to process.
    --   p_batch_id: Identifier for the current batch.
    --------------------------------------------------------------------------------
    
    c_fraud_threshold CONSTANT NUMBER := 50000.00;
    v_halt_detected BOOLEAN := FALSE;
    v_flagged_trans_id VARCHAR2(30);
    v_flagged_amount   NUMBER(15,2);

BEGIN
    -- Check for empty collection
    IF p_transactions IS NULL OR p_transactions.COUNT = 0 THEN
        RETURN;
    END IF;

    FOR i IN 1 .. p_transactions.COUNT LOOP
        
        -- 1. Check for withdrawal type
        IF p_transactions(i).trans_type = 'WITHDRAWAL' THEN
            
            -- 2. Real-Time Security Check: High-Value Threshold
            IF p_transactions(i).amount >= c_fraud_threshold THEN
            
                -- Log alert using autonomous transaction (commits independently)
                log_fraud_alert(p_transactions(i).trans_id, p_transactions(i).amount);

                -- Store details before GOTO
                v_flagged_trans_id := p_transactions(i).trans_id;
                v_flagged_amount := p_transactions(i).amount;
                
                -- ** INNOVATION: The Security Circuit Breaker **
                v_halt_detected := TRUE;
                GOTO HALT_POINT; 
            END IF;
            
        END IF;

        -- 3. Normal Processing Logic (Only executed if no fraud is detected)
        -- Update the transaction status (pending commitment)
        UPDATE BANK_TRANSACTIONS
        SET status = 'CLEARED'
        WHERE trans_id = p_transactions(i).trans_id
        AND batch_id = p_batch_id;
        
    END LOOP;
    
    -- Normal successful completion point (If loop finishes without GOTO)
    IF NOT v_halt_detected THEN
        COMMIT; 
    END IF;

    -- << HALT_POINT >> The GOTO target label
    <<HALT_POINT>>
    IF v_halt_detected THEN
        -- 4. Critical Action: ROLLBACK to revert all changes in this transaction context
        ROLLBACK; 
        
        -- 5. Signal the calling system (e.g., core banking application) to stop
        RAISE_APPLICATION_ERROR(-20001, 'FDTMS_HALT: Batch processing aborted due to high-risk withdrawal: ' || v_flagged_trans_id);
    END IF;

END process_batch_transactions;
/

-- Main Procedure: process_batch_transactions



