// Domain and event types for the Customer Service.

public type Customer record {|
    string id;
    string name;
    string email;
    string phone;
    string address;
|};

public type NewCustomer record {|
    string name;
    string email;
    string phone;
    string address;
|};

// ---- Inbound Kafka event shapes (published by Order Service) ----

public type OrderCreatedEvent record {|
    string orderId;
    string customerId;
    string restaurantId;
    decimal totalAmount;
    string status;
    string timestamp;
    json...; // tolerate extra fields (e.g. `items`) present on the wire but unused here
|};

public type OrderStatusUpdatedEvent record {|
    string orderId;
    string customerId;
    string restaurantId;
    decimal totalAmount;
    string status;
    string timestamp;
    json...;
|};

public type OrderHistoryItem record {|
    string orderId;
    string customerId;
    string restaurantId;
    decimal totalAmount;
    string status;
    string updatedAt;
|};
