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

public type RestaurantStats record {|
    string restaurantId;
    int totalOrders;
    decimal totalRevenue;
    int cancelledOrders;
    string lastUpdated;
|};

public type DriverStats record {|
    string driverId;
    int totalDeliveries;
    int activeDeliveries;
    string lastUpdated;
|};
