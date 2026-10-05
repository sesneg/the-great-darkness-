import ballerina/http;
import ballerina/log;
import ballerina/sql;
import ballerina/uuid;

configurable int servicePort = 8081;

service /customers on new http:Listener(servicePort) {

    // Create a new customer account.
    resource function post .(@http:Payload NewCustomer newCustomer) returns Customer|http:InternalServerError|http:BadRequest {
        if newCustomer.name.trim().length() == 0 || newCustomer.email.trim().length() == 0 {
            return <http:BadRequest>{body: {message: "name and email are required"}};
        }
        string id = uuid:createType1AsString();
        sql:ParameterizedQuery q = `INSERT INTO customers (id, name, email, phone, address)
            VALUES (${id}, ${newCustomer.name}, ${newCustomer.email}, ${newCustomer.phone}, ${newCustomer.address})`;
        sql:ExecutionResult|sql:Error result = dbClient->execute(q);
        if result is sql:Error {
            log:printError("failed to create customer", 'error = result);
            return <http:InternalServerError>{body: {message: "could not create customer"}};
        }
        return {id, name: newCustomer.name, email: newCustomer.email, phone: newCustomer.phone, address: newCustomer.address};
    }

    // List all customers.
    resource function get .() returns Customer[]|http:InternalServerError {
        stream<Customer, sql:Error?> resultStream = dbClient->query(`SELECT id, name, email, phone, address FROM customers`);
        Customer[]|error customers = from Customer c in resultStream select c;
        if customers is error {
            return <http:InternalServerError>{body: {message: "could not fetch customers"}};
        }
        return customers;
    }

    // Fetch a single customer by id.
    resource function get [string customerId]() returns Customer|http:NotFound|http:InternalServerError {
        Customer|sql:Error result = dbClient->queryRow(
            `SELECT id, name, email, phone, address FROM customers WHERE id = ${customerId}`);
        if result is sql:NoRowsError {
            return <http:NotFound>{body: {message: "customer not found"}};
        }
        if result is sql:Error {
            return <http:InternalServerError>{body: {message: "could not fetch customer"}};
        }
        return result;
    }

    // Update a customer's delivery address / contact details.
    resource function put [string customerId](@http:Payload NewCustomer updated) returns Customer|http:NotFound|http:InternalServerError {
        sql:ParameterizedQuery q = `UPDATE customers SET name = ${updated.name}, phone = ${updated.phone}, address = ${updated.address} WHERE id = ${customerId}`;
        sql:ExecutionResult|sql:Error result = dbClient->execute(q);
        if result is sql:Error {
            return <http:InternalServerError>{body: {message: "could not update customer"}};
        }
        if result.affectedRowCount == 0 {
            return <http:NotFound>{body: {message: "customer not found"}};
        }
        return {id: customerId, name: updated.name, email: updated.email, phone: updated.phone, address: updated.address};
    }

    // Historical order data, built from Kafka order-lifecycle events.
    resource function get [string customerId]/orders() returns OrderHistoryItem[]|http:InternalServerError {
        stream<OrderHistoryItem, sql:Error?> resultStream = dbClient->query(
            `SELECT order_id as orderId, customer_id as customerId, restaurant_id as restaurantId,
                    total_amount as totalAmount, status, CAST(updated_at AS CHAR) as updatedAt
             FROM customer_order_history WHERE customer_id = ${customerId} ORDER BY updated_at DESC`);
        OrderHistoryItem[]|error history = from OrderHistoryItem h in resultStream select h;
        if history is error {
            return <http:InternalServerError>{body: {message: "could not fetch order history"}};
        }
        return history;
    }

    resource function get health() returns json {
        return {status: "UP", 'service: "customer-service"};
    }
}
