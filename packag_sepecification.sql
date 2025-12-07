CREATE OR REPLACE PACKAGE FDTMS_PKG
AS
    e_batch_locked EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_batch_locked, -20002);
    
    e_transaction_not_found EXCEPTION;

    c_fraud_threshold CONSTANT NUMBER := 50000.00;

    PROCEDURE process_batch_transactions (
        p_transactions IN transaction_tab, 
        p_batch_id IN VARCHAR2
    );

    PROCEDURE log_fraud_alert (
        p_trans_id IN VARCHAR2, 
        p_amount IN NUMBER
    );
    
    PROCEDURE update_batch_status (
        p_batch_id IN VARCHAR2, 
        p_new_status IN VARCHAR2,
        p_reason IN VARCHAR2 DEFAULT NULL, 
        p_trans_id IN VARCHAR2 DEFAULT NULL
    );
    
    FUNCTION is_batch_status (
        p_batch_id IN VARCHAR2, 
        p_status IN VARCHAR2
    ) RETURN BOOLEAN;
    
    FUNCTION calculate_total_batch_value (
        p_batch_id IN VARCHAR2
    ) RETURN NUMBER;
    
    FUNCTION get_batch_review_status (
        p_batch_id IN VARCHAR2
    ) RETURN VARCHAR2;
    
END FDTMS_PKG;
/
