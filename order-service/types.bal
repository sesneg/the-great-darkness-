public type OrderItem record {|
    string itemId;
    string name;
    int quantity;
    decimal price;
|};

public type NewOrder record {|
    string customerId;
    string restaurantId;
    OrderItem[] items;
|};

public type Order record {|
    string id;
    string customerId;
    string restaurantId;
    OrderItem[] items;
    decimal totalAmount;
    string status;
    string createdAt;
    string updatedAt;
|};

// Row shape as read directly from MySQL (items stored as JSON text).
type OrderRow record {|
    string id;
    string customerId;
    string restaurantId;
    string itemsJson;
    decimal totalAmount;
    string status;
    string createdAt;
    string updatedAt;
|};

// ---- Outbound events ----

public type OrderCreatedEvent record {|
    string orderId;
    string customerId;
    string restaurantId;
    OrderItem[] items;
    decimal totalAmount;
    string status;
    string timestamp;
|};

public type OrderStatusUpdatedEvent record {|
    string orderId;
    string customerId;
    string restaurantId;
    decimal totalAmount;
    string status;
    string timestamp;
|};

// ---- Inbound events (from other services) ----

public type PaymentCompletedEvent record {|
    string orderId;
    string customerId;
    decimal amount;
    string status;
    string timestamp;
|};

public type PaymentFailedEvent record {|
    string orderId;
    string customerId;
    decimal amount;
    string status;
    string reason;
    string timestamp;
|};

public type KitchenStatusUpdatedEvent record {|
    string orderId;
    string restaurantId;
    string status;
    string timestamp;
|};

public type DeliveryAssignedEvent record {|
    string orderId;
    string driverId;
    string status;
    string timestamp;
|};

public type DeliveryCompletedEvent record {|
    string orderId;
    string driverId;
    string status;
    string timestamp;
|};
