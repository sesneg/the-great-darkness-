public type Driver record {|
    string id;
    string name;
    string phone;
    string vehicle;
    string status;
    decimal currentLat;
    decimal currentLng;
|};

public type NewDriver record {|
    string name;
    string phone;
    string vehicle;
|};

public type LocationUpdate record {|
    decimal lat;
    decimal lng;
|};

public type Delivery record {|
    string id;
    string orderId;
    string? driverId;
    string restaurantId;
    string customerId;
    string status;
    string? assignedAt;
    string? deliveredAt;
|};

public type DeliveryStatusUpdate record {|
    string status; // PICKED_UP | DELIVERED
|};

// ---- Kafka event shapes ----

public type KitchenStatusUpdatedEvent record {|
    string orderId;
    string restaurantId;
    string status;
    string timestamp;
|};

public type OrderCreatedEvent record {|
    string orderId;
    string customerId;
    string restaurantId;
    decimal totalAmount;
    string status;
    string timestamp;
    json...;
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
