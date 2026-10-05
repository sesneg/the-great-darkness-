import ballerina/lang.'string as strings;
//import ballerina/log;
import ballerinax/kafka;

configurable string kafkaBootstrap = "localhost:9092";

listener kafka:Listener notificationListener = new (kafkaBootstrap, {
    groupId: "notification-service-group",
    topics: ["orders.created", "orders.status.updated", "payments.completed", "payments.failed",
             "delivery.assigned", "delivery.completed"],
    autoCommit: true,
    offsetReset: "earliest"
});

service kafka:Service on notificationListener {

    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach kafka:BytesConsumerRecord rec in records {
            string raw = check strings:fromBytes(rec.value);
            json payload = check raw.fromJsonString();

            match rec.offset.partition.topic {
                "orders.created" => {
                    OrderCreatedEvent event = check payload.cloneWithType(OrderCreatedEvent);
                    check dispatchNotification("CUSTOMER", event.customerId, "PUSH",
                        string `Your order ${event.orderId} has been placed. Total: N$${event.totalAmount}`, event.orderId);
                    check dispatchNotification("RESTAURANT", event.restaurantId, "PUSH",
                        string `New order ${event.orderId} received.`, event.orderId);
                }
                "orders.status.updated" => {
                    OrderStatusUpdatedEvent event = check payload.cloneWithType(OrderStatusUpdatedEvent);
                    check dispatchNotification("CUSTOMER", event.customerId, "PUSH",
                        string `Order ${event.orderId} is now ${event.status}.`, event.orderId);
                    if event.status == "PREPARING" || event.status == "READY" {
                        check dispatchNotification("RESTAURANT", event.restaurantId, "PUSH",
                            string `Order ${event.orderId} marked ${event.status}.`, event.orderId);
                    }
                }
                "payments.completed" => {
                    PaymentCompletedEvent event = check payload.cloneWithType(PaymentCompletedEvent);
                    check dispatchNotification("CUSTOMER", event.customerId, "EMAIL",
                        string `Payment of N$${event.amount} for order ${event.orderId} was successful.`, event.orderId);
                }
                "payments.failed" => {
                    PaymentFailedEvent event = check payload.cloneWithType(PaymentFailedEvent);
                    check dispatchNotification("CUSTOMER", event.customerId, "EMAIL",
                        string `Payment for order ${event.orderId} failed: ${event.reason}.`, event.orderId);
                }
                "delivery.assigned" => {
                    DeliveryAssignedEvent event = check payload.cloneWithType(DeliveryAssignedEvent);
                    check dispatchNotification("DRIVER", event.driverId, "PUSH",
                        string `You have been assigned delivery for order ${event.orderId}.`, event.orderId);
                }
                "delivery.completed" => {
                    DeliveryCompletedEvent event = check payload.cloneWithType(DeliveryCompletedEvent);
                    check dispatchNotification("DRIVER", event.driverId, "PUSH",
                        string `Delivery for order ${event.orderId} marked complete. Thank you!`, event.orderId);
                }
            }
        }
    }
}
