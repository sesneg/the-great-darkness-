import ballerina/http;
import ballerina/sql;

configurable int servicePort = 8086;

service /notifications on new http:Listener(servicePort) {

    resource function get .(string? recipientId, string? orderId) returns Notification[]|http:InternalServerError {
        stream<Notification, sql:Error?> resultStream;
        if recipientId is string {
            resultStream = dbClient->query(
                `SELECT id, recipient_type as recipientType, recipient_id as recipientId, channel, message, order_id as orderId,
                        CAST(sent_at AS CHAR) as sentAt FROM notifications WHERE recipient_id = ${recipientId} ORDER BY sent_at DESC`);
        } else if orderId is string {
            resultStream = dbClient->query(
                `SELECT id, recipient_type as recipientType, recipient_id as recipientId, channel, message, order_id as orderId,
                        CAST(sent_at AS CHAR) as sentAt FROM notifications WHERE order_id = ${orderId} ORDER BY sent_at DESC`);
        } else {
            resultStream = dbClient->query(
                `SELECT id, recipient_type as recipientType, recipient_id as recipientId, channel, message, order_id as orderId,
                        CAST(sent_at AS CHAR) as sentAt FROM notifications ORDER BY sent_at DESC LIMIT 200`);
        }
        Notification[]|error notifications = from Notification n in resultStream select n;
        if notifications is error {
            return <http:InternalServerError>{body: {message: "could not fetch notifications"}};
        }
        return notifications;
    }

    resource function get health() returns json {
        return {status: "UP", 'service: "notification-service"};
    }
}
