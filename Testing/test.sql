-- 🧪 Testing Time: Setup and Execution
-- Step 1: Insert Test Data
-- Step 2: Prepare the Input Collection
-- Verification 4.1: FDTMS_BATCH_CONTROL Check (Must be HALTED)
SELECT batch_id, status, halt_transaction_id, review_status
FROM FDTMS_BATCH_CONTROL
WHERE batch_id = 'B004';
-- REQUIREMENT III: Operational Control. EXPECTED: STATUS = HALTED, halt_transaction_id = T016

-- Verification 4.2: ROLLBACK Check (Data Safety)
SELECT trans_id, status
FROM BANK_TRANSACTIONS
WHERE batch_id = 'B004';
-- REQUIREMENT IV: Data Safety. EXPECTED: All 4 transactions must show STATUS = PENDING (T015 was rolled back).

-- Verification 4.3: AUDIT LOG Check (Audit Integrity)
SELECT trans_id, amount, processing_halted
FROM FDTMS_AUDIT_LOG
WHERE trans_id = 'T016';
-- REQUIREMENT II: Audit Integrity. EXPECTED: One row for T016, processing_halted = Y.

-- Manual Clearance and Resumption
-- Analyst clears the fraud (T016)
UPDATE BANK_TRANSACTIONS
SET status = 'CLEARED'
WHERE trans_id = 'T016';

-- Analyst resets the control switch
EXEC update_batch_status(p_batch_id => 'B004', p_new_status => 'RUNNING');

COMMIT;
--Execute Resume (Run 2)--
SET SERVEROUTPUT ON;

DECLARE
    v_transaction_batch transaction_tab := transaction_tab();
BEGIN
    SELECT transaction_rec(trans_id, account_id, trans_type, amount, trans_date, batch_id)
    BULK COLLECT INTO v_transaction_batch
    FROM BANK_TRANSACTIONS
    WHERE batch_id = 'B004'
    ORDER BY trans_id;

    process_batch_transactions(v_transaction_batch, 'B004');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Execution finished with status: ' || SQLERRM);
END;
/
--Final Validation--
-- Final Validation 7.1: Final State Check
SELECT batch_id, status FROM FDTMS_BATCH_CONTROL WHERE batch_id = 'B004';

-- Final Validation 7.2: Final Data Status Check
SELECT trans_id, status FROM BANK_TRANSACTIONS WHERE batch_id = 'B004';

