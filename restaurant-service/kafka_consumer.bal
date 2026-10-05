import ballerina/lang.'string as strings;
import ballerina/log;
import ballerina/sql;
import ballerinax/kafka;

listener kafka:Listener orderCreatedListener = new (kafkaBootstrap, {
    groupId: "restaurant-service-group",
    topics: ["orders.created"],
    autoCommit: true,
    offsetReset: "earliest"
});

// When a new order arrives, decrement stock for the ordered menu items and
// simulate the kitchen being notified of the incoming order.
service kafka:Service on orderCreatedListener {

    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach kafka:BytesConsumerRecord rec in records {
            string raw = check strings:fromBytes(rec.value);
            json payload = check raw.fromJsonString();
            OrderCreatedEvent event = check payload.cloneWithType(OrderCreatedEvent);

            log:printInfo(string `[restaurant-service] new order ${event.orderId} received by restaurant ${event.restaurantId}`);

            foreach OrderItem item in event.items {
                sql:ParameterizedQuery q = `UPDATE menu_items SET stock = GREATEST(stock - ${item.quantity}, 0)
                    WHERE id = ${item.itemId} AND restaurant_id = ${event.restaurantId}`;
                _ = check dbClient->execute(q);
            }
        }
    }
}

