import ballerina/log;
import ballerinax/kafka;

configurable string kafkaBootstrap = "localhost:9092";

final kafka:Producer kafkaProducer = check new (kafkaBootstrap, {
    clientId: "order-service-producer",
    acks: "all",
    retryCount: 3
});

function publishOrderCreated(OrderCreatedEvent event) returns error? {
    byte[] payload = (check event.cloneWithType(json)).toJsonString().toBytes();
    check kafkaProducer->send({topic: "orders.created", value: payload, key: event.orderId.toBytes()});
    log:printInfo(string `[order-service] published orders.created for ${event.orderId}`);
}

function publishOrderStatusUpdated(OrderStatusUpdatedEvent event) returns error? {
    byte[] payload = (check event.cloneWithType(json)).toJsonString().toBytes();
    check kafkaProducer->send({topic: "orders.status.updated", value: payload, key: event.orderId.toBytes()});
    log:printInfo(string `[order-service] published orders.status.updated for ${event.orderId} -> ${event.status}`);
}
