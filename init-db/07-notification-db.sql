USE notification_db;

CREATE TABLE IF NOT EXISTS notifications (
    id VARCHAR(36) PRIMARY KEY,
    recipient_type VARCHAR(20) NOT NULL, -- CUSTOMER, RESTAURANT, DRIVER
    recipient_id VARCHAR(36) NOT NULL,
    channel VARCHAR(20) NOT NULL DEFAULT 'PUSH', -- EMAIL, SMS, PUSH
    message VARCHAR(500) NOT NULL,
    order_id VARCHAR(36) NOT NULL,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX (recipient_id),
    INDEX (order_id)
);
