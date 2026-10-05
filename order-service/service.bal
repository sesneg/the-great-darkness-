import ballerina/http;
import ballerina/log;
import ballerina/sql;
import ballerina/time;
import ballerina/uuid;

configurable int servicePort = 8083;

service /orders on new http:Listener(servicePort) {

    // Creates a new order (state = CREATED) and publishes `orders.created`.
    // Downstream: Restaurant Service (inventory) and Payment Service (charge) react to this event.
    resource function post .(@http:Payload NewOrder newOrder) returns Order|http:BadRequest|http:InternalServerError {
        if newOrder.items.length() == 0 {
            return <http:BadRequest>{body: {message: "an order must contain at least one item"}};
        }

        decimal total = 0;
        foreach OrderItem item in newOrder.items {
            total += item.price * <decimal>item.quantity;
        }

        string id = uuid:createType1AsString();
        json itemsJson = newOrder.items.toJson();

        sql:ParameterizedQuery insertQ = `INSERT INTO orders (id, customer_id, restaurant_id, items_json, total_amount, status)
            VALUES (${id}, ${newOrder.customerId}, ${newOrder.restaurantId}, ${itemsJson.toJsonString()}, ${total}, 'CREATED')`;
        sql:ExecutionResult|sql:Error insertResult = dbClient->execute(insertQ);
        if insertResult is sql:Error {
            log:printError("failed to create order", 'error = insertResult);
            return <http:InternalServerError>{body: {message: "could not create order"}};
        }

        string ts = time:utcToString(time:utcNow());
        error? publishResult = publishOrderCreated({
            orderId: id,
            customerId: newOrder.customerId,
            restaurantId: newOrder.restaurantId,
            items: newOrder.items,
            totalAmount: total,
            status: "CREATED",
            timestamp: ts
        });
        if publishResult is error {
            log:printError("order persisted but failed to publish orders.created", 'error = publishResult);
        }

        return {
            id,
            customerId: newOrder.customerId,
            restaurantId: newOrder.restaurantId,
            items: newOrder.items,
            totalAmount: total,
            status: "CREATED",
            createdAt: ts,
            updatedAt: ts
        };
    }

    resource function get .(string? status, string? customerId) returns Order[]|http:InternalServerError {
        stream<OrderRow, sql:Error?> resultStream;
        if status is string {
            resultStream = dbClient->query(
                `SELECT id, customer_id as customerId, restaurant_id as restaurantId,
                        CAST(items_json AS CHAR) as itemsJson, total_amount as totalAmount, status,
                        CAST(created_at AS CHAR) as createdAt, CAST(updated_at AS CHAR) as updatedAt
                 FROM orders WHERE status = ${status} ORDER BY created_at DESC`);
        } else if customerId is string {
            resultStream = dbClient->query(
                `SELECT id, customer_id as customerId, restaurant_id as restaurantId,
                        CAST(items_json AS CHAR) as itemsJson, total_amount as totalAmount, status,
                        CAST(created_at AS CHAR) as createdAt, CAST(updated_at AS CHAR) as updatedAt
                 FROM orders WHERE customer_id = ${customerId} ORDER BY created_at DESC`);
        } else {
            resultStream = dbClient->query(
                `SELECT id, customer_id as customerId, restaurant_id as restaurantId,
                        CAST(items_json AS CHAR) as itemsJson, total_amount as totalAmount, status,
                        CAST(created_at AS CHAR) as createdAt, CAST(updated_at AS CHAR) as updatedAt
                 FROM orders ORDER BY created_at DESC`);
        }

        Order[] orders = [];
        error? e = resultStream.forEach(function(OrderRow row) {
            Order|error o = rowToOrder(row);
            if o is Order {
                orders.push(o);
            }
        });
        if e is error {
            return <http:InternalServerError>{body: {message: "could not fetch orders"}};
        }
        return orders;
    }

    resource function get [string orderId]() returns Order|http:NotFound|http:InternalServerError {
        Order|sql:Error|error result = getOrderById(orderId);
        if result is sql:NoRowsError {
            return <http:NotFound>{body: {message: "order not found"}};
        }
        if result is error {
            return <http:InternalServerError>{body: {message: "could not fetch order"}};
        }
        return result;
    }

    // Customer-initiated cancellation. Only allowed before the order is out for delivery.
    resource function put [string orderId]/cancel() returns http:Ok|http:Conflict|http:NotFound|http:InternalServerError {
        Order|error? updated = transitionOrder(orderId, "CANCELLED");
        if updated is error {
            return <http:InternalServerError>{body: {message: "could not cancel order"}};
        }
        if updated is () {
            return <http:Conflict>{body: {message: "order cannot be cancelled in its current state, or does not exist"}};
        }
        error? publishResult = publishOrderStatusUpdated({
            orderId: updated.id,
            customerId: updated.customerId,
            restaurantId: updated.restaurantId,
            totalAmount: updated.totalAmount,
            status: updated.status,
            timestamp: time:utcToString(time:utcNow())
        });
        if publishResult is error {
            log:printError("cancelled order but failed to publish status event", 'error = publishResult);
        }
        return <http:Ok>{body: {message: "order cancelled", orderId}};
    }

    resource function get health() returns json {
        return {status: "UP", 'service: "order-service"};
    }
}
