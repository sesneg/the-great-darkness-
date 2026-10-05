import ballerina/lang.'string as strings;
import ballerina/log;
import ballerina/time;
import ballerinax/kafka;

listener kafka:Listener orderLifecycleListener = new (kafkaBootstrap, {
    groupId: "order-service-group",
    topics: ["payments.completed", "payments.failed", "kitchen.status.updated", "delivery.assigned", "delivery.completed"],
    autoCommit: true,
    offsetReset: "earliest"
});

// Central state-machine driver: every upstream service communicates a change
// in the order's real-world state purely via Kafka events; this service is
// the single writer of `orders.status`.
service kafka:Service on orderLifecycleListener {

    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach kafka:BytesConsumerRecord rec in records {
            string raw = check strings:fromBytes(rec.value);
            json payload = check raw.fromJsonString();

            string? orderId = ();
            string? nextStatus = ();

            match rec.offset.partition.topic {
                "payments.completed" => {
                    PaymentCompletedEvent event = check payload.cloneWithType(PaymentCompletedEvent);
                    orderId = event.orderId;
                    nextStatus = "CONFIRMED";
                }
                "payments.failed" => {
                    PaymentFailedEvent event = check payload.cloneWithType(PaymentFailedEvent);
                    orderId = event.orderId;
                    nextStatus = "CANCELLED";
                }
                "kitchen.status.updated" => {
                    KitchenStatusUpdatedEvent event = check payload.cloneWithType(KitchenStatusUpdatedEvent);
                    orderId = event.orderId;
                    nextStatus = event.status; // PREPARING | READY
                }
                "delivery.assigned" => {
                    DeliveryAssignedEvent event = check payload.cloneWithType(DeliveryAssignedEvent);
                    orderId = event.orderId;
                    nextStatus = "OUT_FOR_DELIVERY";
                }
                "delivery.completed" => {
                    DeliveryCompletedEvent event = check payload.cloneWithType(DeliveryCompletedEvent);
                    orderId = event.orderId;
                    nextStatus = "DELIVERED";
                }
            }

            if orderId is string && nextStatus is string {
                Order|error? updated = transitionOrder(orderId, nextStatus);
                if updated is error {
                    log:printError(string `[order-service] failed to transition order ${orderId}`, 'error = updated);
                } else if updated is Order {
                    check publishOrderStatusUpdated({
                        orderId: updated.id,
                        customerId: updated.customerId,
                        restaurantId: updated.restaurantId,
                        totalAmount: updated.totalAmount,
                        status: updated.status,
                        timestamp: time:utcToString(time:utcNow())
                    });
                }
            }
        }
    }
}
