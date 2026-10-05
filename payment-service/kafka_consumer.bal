import ballerina/lang.'string as strings;
//import ballerina/log;
import ballerina/sql;
import ballerina/time;
import ballerina/uuid;
import ballerinax/kafka;

listener kafka:Listener orderCreatedListener = new (kafkaBootstrap, {
    groupId: "payment-service-group",
    topics: ["orders.created"],
    autoCommit: true,
    offsetReset: "earliest"
});

// Simulates payment processing for every newly created order.
// A zero or negative total is treated as an invalid order and fails the payment;
// otherwise payment always succeeds (this is a simulation, per the assignment spec).
service kafka:Service on orderCreatedListener {

    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach kafka:BytesConsumerRecord rec in records {
            string raw = check strings:fromBytes(rec.value);
            json payload = check raw.fromJsonString();
            OrderCreatedEvent event = check payload.cloneWithType(OrderCreatedEvent);

            string paymentId = uuid:createType1AsString();
            string ts = time:utcToString(time:utcNow());
            boolean success = event.totalAmount > 0d;
            string status = success ? "SUCCESS" : "FAILED";

            sql:ParameterizedQuery q = `INSERT INTO payments (id, order_id, customer_id, amount, method, status)
                VALUES (${paymentId}, ${event.orderId}, ${event.customerId}, ${event.totalAmount}, 'MOBILE_MONEY', ${status})
                ON DUPLICATE KEY UPDATE status = ${status}`;
            _ = check dbClient->execute(q);

            if success {
                check publishPaymentCompleted({
                    orderId: event.orderId,
                    customerId: event.customerId,
                    amount: event.totalAmount,
                    status: "COMPLETED",
                    timestamp: ts
                });
            } else {
                check publishPaymentFailed({
                    orderId: event.orderId,
                    customerId: event.customerId,
                    amount: event.totalAmount,
                    status: "FAILED",
                    reason: "invalid order total",
                    timestamp: ts
                });
            }
        }
    }
}
