import ballerina/lang.'string as strings;
import ballerina/log;
import ballerina/sql;
import ballerina/time;
import ballerina/uuid;
import ballerinax/kafka;

listener kafka:Listener deliveryEventsListener = new (kafkaBootstrap, {
    groupId: "delivery-service-group",
    topics: ["orders.created", "kitchen.status.updated"],
    autoCommit: true,
    offsetReset: "earliest"
});

service kafka:Service on deliveryEventsListener {

    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach kafka:BytesConsumerRecord rec in records {
            string raw = check strings:fromBytes(rec.value);
            json payload = check raw.fromJsonString();

            if rec.offset.partition.topic == "orders.created" {
                OrderCreatedEvent event = check payload.cloneWithType(OrderCreatedEvent);
                sql:ParameterizedQuery q = `INSERT INTO order_cache (order_id, customer_id, restaurant_id)
                    VALUES (${event.orderId}, ${event.customerId}, ${event.restaurantId})
                    ON DUPLICATE KEY UPDATE customer_id = ${event.customerId}`;
                _ = check dbClient->execute(q);

            } else if rec.offset.partition.topic == "kitchen.status.updated" {
                KitchenStatusUpdatedEvent event = check payload.cloneWithType(KitchenStatusUpdatedEvent);
                if event.status == "READY" {
                    check assignDriverToOrder(event.orderId, event.restaurantId);
                }
            }
        }
    }
}

// Picks the first AVAILABLE driver, marks them BUSY, creates a delivery
// record and publishes `delivery.assigned`.
function assignDriverToOrder(string orderId, string restaurantId) returns error? {
    record {| string customerId; |}|sql:Error cacheRow = dbClient->queryRow(
        `SELECT customer_id as customerId FROM order_cache WHERE order_id = ${orderId}`);
    if cacheRow is sql:Error {
        log:printWarn(string `[delivery-service] no cached customer for order ${orderId}, skipping delivery assignment`);
        return;
    }

    record {| string id; |}|sql:Error driverRow = dbClient->queryRow(
        `SELECT id FROM drivers WHERE status = 'AVAILABLE' LIMIT 1`);
    if driverRow is sql:Error {
        log:printWarn(string `[delivery-service] no available driver for order ${orderId}`);
        return;
    }

    string deliveryId = uuid:createType1AsString();
    _ = check dbClient->execute(`INSERT INTO deliveries (id, order_id, driver_id, restaurant_id, customer_id, status, assigned_at)
        VALUES (${deliveryId}, ${orderId}, ${driverRow.id}, ${restaurantId}, ${cacheRow.customerId}, 'ASSIGNED', NOW())
        ON DUPLICATE KEY UPDATE driver_id = ${driverRow.id}, status = 'ASSIGNED', assigned_at = NOW()`);
    _ = check dbClient->execute(`UPDATE drivers SET status = 'BUSY' WHERE id = ${driverRow.id}`);

    check publishDeliveryAssigned({
        orderId,
        driverId: driverRow.id,
        status: "ASSIGNED",
        timestamp: time:utcToString(time:utcNow())
    });
}
