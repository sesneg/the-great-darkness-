import ballerina/http;
import ballerina/sql;

configurable int servicePort = 8084;

service /payments on new http:Listener(servicePort) {

    resource function get .() returns Payment[]|http:InternalServerError {
        stream<Payment, sql:Error?> resultStream = dbClient->query(
            `SELECT id, order_id as orderId, customer_id as customerId, amount, method, status,
                    CAST(created_at AS CHAR) as createdAt FROM payments ORDER BY created_at DESC`);
        Payment[]|error payments = from Payment p in resultStream select p;
        if payments is error {
            return <http:InternalServerError>{body: {message: "could not fetch payments"}};
        }
        return payments;
    }

    resource function get [string orderId]() returns Payment|http:NotFound|http:InternalServerError {
        Payment|sql:Error result = dbClient->queryRow(
            `SELECT id, order_id as orderId, customer_id as customerId, amount, method, status,
                    CAST(created_at AS CHAR) as createdAt FROM payments WHERE order_id = ${orderId}`);
        if result is sql:NoRowsError {
            return <http:NotFound>{body: {message: "payment not found for order"}};
        }
        if result is sql:Error {
            return <http:InternalServerError>{body: {message: "could not fetch payment"}};
        }
        return result;
    }

    resource function get health() returns json {
        return {status: "UP", 'service: "payment-service"};
    }
}
