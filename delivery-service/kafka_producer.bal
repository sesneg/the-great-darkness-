import ballerina/log;
import ballerinax/kafka;

configurable string kafkaBootstrap = "localhost:9092";

final kafka:Producer kafkaProducer = check new (kafkaBootstrap, {
    clientId: "delivery-service-producer",
    acks: "all",
    retryCount: 3
});

function publishDeliveryAssigned(DeliveryAssignedEvent event) returns error? {
    byte[] payload = (check event.cloneWithType(json)).toJsonString().toBytes();
    check kafkaProducer->send({topic: "delivery.assigned", value: payload, key: event.orderId.toBytes()});
    log:printInfo(string `[delivery-service] published delivery.assigned for order ${event.orderId} -> driver ${event.driverId}`);
}

function publishDeliveryCompleted(DeliveryCompletedEvent event) returns error? {
    byte[] payload = (check event.cloneWithType(json)).toJsonString().toBytes();
    check kafkaProducer->send({topic: "delivery.completed", value: payload, key: event.orderId.toBytes()});
    log:printInfo(string `[delivery-service] published delivery.completed for order ${event.orderId}`);
}
