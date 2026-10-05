public type Restaurant record {|
    string id;
    string name;
    string address;
    string openingTime;
    string closingTime;
    boolean isOpen;
|};

public type NewRestaurant record {|
    string name;
    string address;
    string openingTime;
    string closingTime;
|};

public type MenuItem record {|
    string id;
    string restaurantId;
    string name;
    decimal price;
    int stock;
    boolean available;
|};

public type NewMenuItem record {|
    string name;
    decimal price;
    int stock;
|};

public type OrderItem record {|
    string itemId;
    string name;
    int quantity;
    decimal price;
|};

// ---- Kafka event shapes ----

public type OrderCreatedEvent record {|
    string orderId;
    string customerId;
    string restaurantId;
    OrderItem[] items;
    decimal totalAmount;
    string status;
    string timestamp;
|};

public type KitchenStatusUpdatedEvent record {|
    string orderId;
    string restaurantId;
    string status; // PREPARING | READY
    string timestamp;
|};

public type StatusUpdateRequest record {|
    string status; // PREPARING | READY
|};
