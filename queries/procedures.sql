CREATE OR REPLACE PROCEDURE FDTMS_PKG.log_fraud_alert (
    p_trans_id IN VARCHAR2, 
    p_amount IN NUMBER
)
IS
    PRAGMA AUTONOMOUS_TRANSACTION; 
BEGIN
    INSERT INTO FDTMS_AUDIT_LOG (trans_id, amount) VALUES (p_trans_id, p_amount);
    COMMIT; 
EXCEPTION
    WHEN OTHERS THEN ROLLBACK; RAISE; 
END FDTMS_PKG.log_fraud_alert;
/

CREATE OR REPLACE PROCEDURE FDTMS_PKG.update_batch_status (
    p_batch_id IN VARCHAR2, 
    p_new_status IN VARCHAR2,
    p_reason IN VARCHAR2 DEFAULT NULL, 
    p_trans_id IN VARCHAR2 DEFAULT NULL
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
END FDTMS_PKG.update_batch_status;
/
