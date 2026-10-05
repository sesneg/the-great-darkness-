USE restaurant_db;

CREATE TABLE IF NOT EXISTS restaurants (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    address VARCHAR(255) NOT NULL,
    opening_time VARCHAR(5) NOT NULL,   -- HH:MM
    closing_time VARCHAR(5) NOT NULL,   -- HH:MM
    is_open BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS menu_items (
    id VARCHAR(36) PRIMARY KEY,
    restaurant_id VARCHAR(36) NOT NULL,
    name VARCHAR(120) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    stock INT NOT NULL DEFAULT 50,
    available BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (restaurant_id) REFERENCES restaurants(id) ON DELETE CASCADE
);

INSERT INTO restaurants (id, name, address, opening_time, closing_time) VALUES
('r1111111-1111-1111-1111-111111111111', 'NUST Bites', '13 Jackson Kaujeua St, Windhoek', '08:00', '22:00')
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO menu_items (id, restaurant_id, name, price, stock) VALUES
('m1111111-1111-1111-1111-111111111111', 'r1111111-1111-1111-1111-111111111111', 'Chicken Burger', 65.00, 40),
('m2222222-2222-2222-2222-222222222222', 'r1111111-1111-1111-1111-111111111111', 'Beef Wrap', 55.00, 40),
('m3333333-3333-3333-3333-333333333333', 'r1111111-1111-1111-1111-111111111111', 'Iced Coffee', 25.00, 100)
ON DUPLICATE KEY UPDATE price = VALUES(price);
