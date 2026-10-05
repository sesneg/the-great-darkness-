import ballerina/lang.'string as strings;
import ballerina/log;
import ballerina/sql;
import ballerinax/kafka;

configurable string kafkaBootstrap = "localhost:9092";

// Consumes order lifecycle events so the Customer Service can maintain a
// local, denormalised view of each customer's order history without
// synchronously calling the Order Service.
listener kafka:Listener orderEventsListener = new (kafkaBootstrap, {
    groupId: "customer-service-group",
    topics: ["orders.created", "orders.status.updated"],
    autoCommit: true,
    offsetReset: "earliest"
});

service kafka:Service on orderEventsListener {

    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach kafka:BytesConsumerRecord rec in records {
            string topic = rec.offset.partition.topic;
            string raw = check strings:fromBytes(rec.value);
            json payload = check raw.fromJsonString();

            if topic == "orders.created" {
                OrderCreatedEvent event = check payload.cloneWithType(OrderCreatedEvent);
                check upsertHistory(event.orderId, event.customerId, event.restaurantId, event.totalAmount, event.status);
                log:printInfo(string `[customer-service] recorded new order ${event.orderId} for customer ${event.customerId}`);
            } else if topic == "orders.status.updated" {
                OrderStatusUpdatedEvent event = check payload.cloneWithType(OrderStatusUpdatedEvent);
                check upsertHistory(event.orderId, event.customerId, event.restaurantId, event.totalAmount, event.status);
                log:printInfo(string `[customer-service] order ${event.orderId} status -> ${event.status}`);
            }
        }
    }
}

function upsertHistory(string orderId, string customerId, string restaurantId, decimal totalAmount, string status) returns error? {
    sql:ParameterizedQuery q = `
        INSERT INTO customer_order_history (order_id, customer_id, restaurant_id, total_amount, status)
        VALUES (${orderId}, ${customerId}, ${restaurantId}, ${totalAmount}, ${status})
        ON DUPLICATE KEY UPDATE status = ${status}, total_amount = ${totalAmount}`;
    _ = check dbClient->execute(q);
}
