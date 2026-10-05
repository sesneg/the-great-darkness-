USE customer_db;

CREATE TABLE IF NOT EXISTS customers (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    phone VARCHAR(30) NOT NULL,
    address VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Denormalised order-history projection, built from Kafka events
CREATE TABLE IF NOT EXISTS customer_order_history (
    order_id VARCHAR(36) PRIMARY KEY,
    customer_id VARCHAR(36) NOT NULL,
    restaurant_id VARCHAR(36) NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(30) NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX (customer_id)
);

INSERT INTO customers (id, name, email, phone, address) VALUES
('c1111111-1111-1111-1111-111111111111', 'Katrin Kanzi', 'katrin@example.com', '+264811234567', '12 Independence Ave, Windhoek')
ON DUPLICATE KEY UPDATE name = VALUES(name);
