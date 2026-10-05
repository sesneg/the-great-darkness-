import ballerina/lang.'string as strings;
//import ballerina/log;
//import ballerina/sql;
import ballerinax/kafka;

configurable string kafkaBootstrap = "localhost:9092";

listener kafka:Listener adminEventsListener = new (kafkaBootstrap, {
    groupId: "admin-service-group",
    topics: ["orders.created", "orders.status.updated", "delivery.assigned", "delivery.completed"],
    autoCommit: true,
    offsetReset: "earliest"
});

// The Admin Service is a pure event-sourced read model: it never calls other
// services synchronously, it only rebuilds reporting tables from the Kafka
// event stream, which is a common pattern (CQRS) in distributed systems.
service kafka:Service on adminEventsListener {

    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach kafka:BytesConsumerRecord rec in records {
            string raw = check strings:fromBytes(rec.value);
            json payload = check raw.fromJsonString();

            _ = check dbClient->execute(`INSERT INTO event_log (topic, payload) VALUES (${rec.offset.partition.topic}, ${raw})`);

            match rec.offset.partition.topic {
                "orders.created" => {
                    OrderCreatedEvent event = check payload.cloneWithType(OrderCreatedEvent);
                    _ = check dbClient->execute(`
                        INSERT INTO restaurant_stats (restaurant_id, total_orders, total_revenue)
                        VALUES (${event.restaurantId}, 1, ${event.totalAmount})
                        ON DUPLICATE KEY UPDATE total_orders = total_orders + 1, total_revenue = total_revenue + ${event.totalAmount}`);
                }
                "orders.status.updated" => {
                    OrderStatusUpdatedEvent event = check payload.cloneWithType(OrderStatusUpdatedEvent);
                    if event.status == "CANCELLED" {
                        _ = check dbClient->execute(`
                            INSERT INTO restaurant_stats (restaurant_id, cancelled_orders)
                            VALUES (${event.restaurantId}, 1)
                            ON DUPLICATE KEY UPDATE cancelled_orders = cancelled_orders + 1`);
                    }
                }
                "delivery.assigned" => {
                    DeliveryAssignedEvent event = check payload.cloneWithType(DeliveryAssignedEvent);
                    _ = check dbClient->execute(`
                        INSERT INTO driver_stats (driver_id, active_deliveries)
                        VALUES (${event.driverId}, 1)
                        ON DUPLICATE KEY UPDATE active_deliveries = active_deliveries + 1`);
                }
                "delivery.completed" => {
                    DeliveryCompletedEvent event = check payload.cloneWithType(DeliveryCompletedEvent);
                    _ = check dbClient->execute(`
                        INSERT INTO driver_stats (driver_id, total_deliveries, active_deliveries)
                        VALUES (${event.driverId}, 1, 0)
                        ON DUPLICATE KEY UPDATE total_deliveries = total_deliveries + 1,
                            active_deliveries = GREATEST(active_deliveries - 1, 0)`);
                }
            }
        }
    }
}

