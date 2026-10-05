USE delivery_db;

CREATE TABLE IF NOT EXISTS drivers (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    phone VARCHAR(30) NOT NULL,
    vehicle VARCHAR(60) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE', -- AVAILABLE, BUSY, OFFLINE
    current_lat DECIMAL(9,6) DEFAULT 0,
    current_lng DECIMAL(9,6) DEFAULT 0
);

-- Local read-model cache of order -> customer, populated from `orders.created`,
-- so the Delivery Service does not need a synchronous call to the Order Service
-- when a `kitchen.status.updated` (READY) event arrives.
CREATE TABLE IF NOT EXISTS order_cache (
    order_id VARCHAR(36) PRIMARY KEY,
    customer_id VARCHAR(36) NOT NULL,
    restaurant_id VARCHAR(36) NOT NULL
);

CREATE TABLE IF NOT EXISTS deliveries (
    id VARCHAR(36) PRIMARY KEY,
    order_id VARCHAR(36) NOT NULL UNIQUE,
    driver_id VARCHAR(36),
    restaurant_id VARCHAR(36) NOT NULL,
    customer_id VARCHAR(36) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, ASSIGNED, PICKED_UP, DELIVERED
    assigned_at TIMESTAMP NULL,
    delivered_at TIMESTAMP NULL,
    FOREIGN KEY (driver_id) REFERENCES drivers(id)
);

INSERT INTO drivers (id, name, phone, vehicle, status) VALUES
('d1111111-1111-1111-1111-111111111111', 'Johannes Amutenya', '+264817654321', 'Motorbike', 'AVAILABLE'),
('d2222222-2222-2222-2222-222222222222', 'Maria Shipanga', '+264816543210', 'Scooter', 'AVAILABLE')
ON DUPLICATE KEY UPDATE name = VALUES(name);
