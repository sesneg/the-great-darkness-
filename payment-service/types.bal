public type OrderItem record {|
    string itemId;
    string name;
    int quantity;
    decimal price;
|};

public type OrderCreatedEvent record {|
    string orderId;
    string customerId;
    string restaurantId;
    OrderItem[] items;
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

public type Payment record {|
    string id;
    string orderId;
    string customerId;
    decimal amount;
    string method;
    string status;
    string createdAt;
|};
