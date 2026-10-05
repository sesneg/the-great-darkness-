//import ballerina/lang.'string as strings;
import ballerina/log;
import ballerinax/kafka;

configurable string kafkaBootstrap = "localhost:9092";

final kafka:Producer kafkaProducer = check new (kafkaBootstrap, {
    clientId: "restaurant-service-producer",
    acks: "all",
    retryCount: 3
});

function publishKitchenStatusUpdated(KitchenStatusUpdatedEvent event) returns error? {
    byte[] payload = (check event.cloneWithType(json)).toJsonString().toBytes();
    check kafkaProducer->send({topic: "kitchen.status.updated", value: payload, key: event.orderId.toBytes()});
    log:printInfo(string `[restaurant-service] published kitchen.status.updated for order ${event.orderId} -> ${event.status}`);
}
