import ballerina/log;
import ballerina/sql;
import ballerina/uuid;

// Simulates dispatching a multi-channel alert (in a real system this would
// call an email/SMS/push gateway); here it is logged and persisted so it can
// be inspected via the REST API.
function dispatchNotification(string recipientType, string recipientId, string channel, string message, string orderId) returns error? {
    string id = uuid:createType1AsString();
    sql:ParameterizedQuery q = `INSERT INTO notifications (id, recipient_type, recipient_id, channel, message, order_id)
        VALUES (${id}, ${recipientType}, ${recipientId}, ${channel}, ${message}, ${orderId})`;
    _ = check dbClient->execute(q);
    log:printInfo(string `[notification-service] ${channel} -> ${recipientType} ${recipientId}: ${message}`);
}
