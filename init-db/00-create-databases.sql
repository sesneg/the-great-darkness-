CREATE DATABASE IF NOT EXISTS customer_db;
CREATE DATABASE IF NOT EXISTS restaurant_db;
CREATE DATABASE IF NOT EXISTS order_db;
CREATE DATABASE IF NOT EXISTS payment_db;
CREATE DATABASE IF NOT EXISTS delivery_db;
CREATE DATABASE IF NOT EXISTS notification_db;
CREATE DATABASE IF NOT EXISTS admin_db;

CREATE USER IF NOT EXISTS 'fooddelivery'@'%' IDENTIFIED BY 'fooddelivery_pw';
GRANT ALL PRIVILEGES ON customer_db.*     TO 'fooddelivery'@'%';
GRANT ALL PRIVILEGES ON restaurant_db.*   TO 'fooddelivery'@'%';
GRANT ALL PRIVILEGES ON order_db.*        TO 'fooddelivery'@'%';
GRANT ALL PRIVILEGES ON payment_db.*      TO 'fooddelivery'@'%';
GRANT ALL PRIVILEGES ON delivery_db.*     TO 'fooddelivery'@'%';
GRANT ALL PRIVILEGES ON notification_db.* TO 'fooddelivery'@'%';
GRANT ALL PRIVILEGES ON admin_db.*        TO 'fooddelivery'@'%';
FLUSH PRIVILEGES;
