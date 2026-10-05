import ballerina/sql;

// Valid forward transitions for the order lifecycle state machine:
// CREATED -> CONFIRMED -> PREPARING -> READY -> OUT_FOR_DELIVERY -> DELIVERED
// Any state before OUT_FOR_DELIVERY can also transition to CANCELLED.
final map<string[]> ALLOWED_TRANSITIONS = {
    "CREATED": ["CONFIRMED", "CANCELLED"],
    "CONFIRMED": ["PREPARING", "CANCELLED"],
    "PREPARING": ["READY", "CANCELLED"],
    "READY": ["OUT_FOR_DELIVERY", "CANCELLED"],
    "OUT_FOR_DELIVERY": ["DELIVERED"],
    "DELIVERED": [],
    "CANCELLED": []
};

function isTransitionAllowed(string fromStatus, string toStatus) returns boolean {
    string[]? allowed = ALLOWED_TRANSITIONS[fromStatus];
    if allowed is () {
        return false;
    }
    return allowed.indexOf(toStatus) is int;
}

function rowToOrder(OrderRow row) returns Order|error {
    json itemsJson = check row.itemsJson.fromJsonString();
    OrderItem[] items = check itemsJson.cloneWithType();
    return {
        id: row.id,
        customerId: row.customerId,
        restaurantId: row.restaurantId,
        items,
        totalAmount: row.totalAmount,
        status: row.status,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt
    };
}

function getOrderById(string orderId) returns Order|sql:Error|error {
    OrderRow row = check dbClient->queryRow(
        `SELECT id, customer_id as customerId, restaurant_id as restaurantId,
                CAST(items_json AS CHAR) as itemsJson, total_amount as totalAmount, status,
                CAST(created_at AS CHAR) as createdAt, CAST(updated_at AS CHAR) as updatedAt
         FROM orders WHERE id = ${orderId}`);
    return rowToOrder(row);
}

// Applies a validated state transition, persists it, and returns the fresh
// order row so the caller can publish the resulting `orders.status.updated` event.
function transitionOrder(string orderId, string newStatus) returns Order|error? {
    Order|sql:Error|error current = getOrderById(orderId);
    if current is sql:NoRowsError {
        return ();
    }
    if current is error {
        return current;
    }
    if !isTransitionAllowed(current.status, newStatus) {
        // Silently ignore out-of-order / duplicate events instead of failing the consumer.
        return ();
    }
    _ = check dbClient->execute(`UPDATE orders SET status = ${newStatus} WHERE id = ${orderId}`);
    current.status = newStatus;
    return current;
}
