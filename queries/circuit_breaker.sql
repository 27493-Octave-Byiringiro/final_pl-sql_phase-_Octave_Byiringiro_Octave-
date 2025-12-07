CREATE OR REPLACE PACKAGE BODY FDTMS_PKG
AS
    PROCEDURE process_batch_transactions (
        p_transactions IN transaction_tab, 
        p_batch_id IN VARCHAR2
    )
    AS
        v_halt_detected BOOLEAN := FALSE;
        v_flagged_trans_id VARCHAR2(30);
        v_processed_count PLS_INTEGER := 0;
    BEGIN
        IF NOT FDTMS_PKG.is_batch_status(p_batch_id, 'RUNNING') THEN
            RAISE e_batch_locked;
        END IF;

        FOR i IN 1 .. p_transactions.COUNT LOOP
            
            IF p_transactions(i).trans_type = 'WITHDRAWAL' AND p_transactions(i).amount >= c_fraud_threshold THEN
            
                FDTMS_PKG.log_fraud_alert(p_transactions(i).trans_id, p_transactions(i).amount);
                FDTMS_PKG.update_batch_status(p_batch_id, 'HALTED', 'FDTMS High-Value Alert', p_transactions(i).trans_id);

                v_flagged_trans_id := p_transactions(i).trans_id;
                v_halt_detected := TRUE;
                
                GOTO HALT_POINT; 
            END IF;

            UPDATE BANK_TRANSACTIONS SET status = 'CLEARED'
            WHERE trans_id = p_transactions(i).trans_id AND batch_id = p_batch_id AND status = 'PENDING';
            v_processed_count := v_processed_count + 1;
            
        END LOOP;
        
        IF NOT v_halt_detected THEN
            FDTMS_PKG.update_batch_status(p_batch_id, 'COMPLETED');
            COMMIT; 
        END IF;

        <<HALT_POINT>>
        IF v_halt_detected THEN
            ROLLBACK; 
            RAISE_APPLICATION_ERROR(-20001, 'FDTMS_HALT: Batch aborted due to high-risk withdrawal: ' || v_flagged_trans_id);
        END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL;
        WHEN e_batch_locked THEN
            NULL;
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END process_batch_transactions;

    -- Implementations of Autonomous Procedures (must be defined in the body)
    PROCEDURE log_fraud_alert (p_trans_id IN VARCHAR2, p_amount IN NUMBER) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO FDTMS_AUDIT_LOG (trans_id, amount) VALUES (p_trans_id, p_amount);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN ROLLBACK; RAISE;
    END log_fraud_alert;

    PROCEDURE update_batch_status (p_batch_id IN VARCHAR2, p_new_status IN VARCHAR2, p_reason IN VARCHAR2 DEFAULT NULL, p_trans_id IN VARCHAR2 DEFAULT NULL) IS
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

    -- Implementations of Functions (must be defined in the body)
    FUNCTION calculate_total_batch_value (p_batch_id IN VARCHAR2) RETURN NUMBER IS
        v_total_value NUMBER := 0;
    BEGIN
        SELECT SUM(amount) INTO v_total_value FROM BANK_TRANSACTIONS WHERE batch_id = p_batch_id;
        RETURN NVL(v_total_value, 0);
    END calculate_total_batch_value;

    FUNCTION is_batch_status (p_batch_id IN VARCHAR2, p_status IN VARCHAR2) RETURN BOOLEAN IS
        v_current_status FDTMS_BATCH_CONTROL.status%TYPE;
    BEGIN
        SELECT status INTO v_current_status FROM FDTMS_BATCH_CONTROL WHERE batch_id = p_batch_id;
        RETURN v_current_status = p_status;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN FALSE;
    END is_batch_status;

    FUNCTION get_batch_review_status (p_batch_id IN VARCHAR2) RETURN VARCHAR2 IS
        v_review_status FDTMS_BATCH_CONTROL.review_status%TYPE;
    BEGIN
        SELECT review_status INTO v_review_status FROM FDTMS_BATCH_CONTROL WHERE batch_id = p_batch_id;
        RETURN v_review_status;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN 'BATCH_NOT_FOUND';
    END get_batch_review_status;

END FDTMS_PKG;
/
