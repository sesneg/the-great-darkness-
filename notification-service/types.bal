public type OrderCreatedEvent record {|
    string orderId;
    string customerId;
    string restaurantId;
    decimal totalAmount;
    string status;
    string timestamp;
    json...;
|};

public type OrderStatusUpdatedEvent record {|
    string orderId;
    string customerId;
    string restaurantId;
    decimal totalAmount;
    string status;
    string timestamp;
|};

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

public type Notification record {|
    string id;
    string recipientType;
    string recipientId;
    string channel;
    string message;
    string orderId;
    string sentAt;
|};
