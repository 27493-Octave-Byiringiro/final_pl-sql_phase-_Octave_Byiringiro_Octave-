CREATE OR REPLACE FUNCTION FDTMS_PKG.calculate_total_batch_value (
    p_batch_id IN VARCHAR2
) 
RETURN NUMBER
IS
    v_total_value NUMBER := 0;
BEGIN
    SELECT SUM(amount) INTO v_total_value
    FROM BANK_TRANSACTIONS
    WHERE batch_id = p_batch_id;

    RETURN NVL(v_total_value, 0);
END FDTMS_PKG.calculate_total_batch_value;
/

CREATE OR REPLACE FUNCTION FDTMS_PKG.is_batch_status (
    p_batch_id IN VARCHAR2, 
    p_status IN VARCHAR2
) 
RETURN BOOLEAN
IS
    v_current_status FDTMS_BATCH_CONTROL.status%TYPE;
BEGIN
    SELECT status INTO v_current_status
    FROM FDTMS_BATCH_CONTROL
    WHERE batch_id = p_batch_id;

    RETURN v_current_status = p_status;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN FALSE;
END FDTMS_PKG.is_batch_status;
/

CREATE OR REPLACE FUNCTION FDTMS_PKG.get_batch_review_status (
    p_batch_id IN VARCHAR2
) 
RETURN VARCHAR2
IS
    v_review_status FDTMS_BATCH_CONTROL.review_status%TYPE;
BEGIN
    SELECT review_status INTO v_review_status
    FROM FDTMS_BATCH_CONTROL
    WHERE batch_id = p_batch_id;
    
    RETURN v_review_status;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 'BATCH_NOT_FOUND';
END FDTMS_PKG.get_batch_review_status;
/
