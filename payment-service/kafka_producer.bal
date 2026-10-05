import ballerina/log;
import ballerinax/kafka;

configurable string kafkaBootstrap = "localhost:9092";

final kafka:Producer kafkaProducer = check new (kafkaBootstrap, {
    clientId: "payment-service-producer",
    acks: "all",
    retryCount: 3
});

function publishPaymentCompleted(PaymentCompletedEvent event) returns error? {
    byte[] payload = (check event.cloneWithType(json)).toJsonString().toBytes();
    check kafkaProducer->send({topic: "payments.completed", value: payload, key: event.orderId.toBytes()});
    log:printInfo(string `[payment-service] published payments.completed for order ${event.orderId}`);
}

function publishPaymentFailed(PaymentFailedEvent event) returns error? {
    byte[] payload = (check event.cloneWithType(json)).toJsonString().toBytes();
    check kafkaProducer->send({topic: "payments.failed", value: payload, key: event.orderId.toBytes()});
    log:printInfo(string `[payment-service] published payments.failed for order ${event.orderId}: ${event.reason}`);
}
