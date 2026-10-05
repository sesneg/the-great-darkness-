import ballerina/http;
import ballerina/sql;
import ballerina/time;
import ballerina/uuid;

configurable int servicePort = 8085;

service /delivery on new http:Listener(servicePort) {

    // ---- Drivers ----

    resource function post drivers(@http:Payload NewDriver d) returns Driver|http:InternalServerError {
        string id = uuid:createType1AsString();
        sql:ExecutionResult|sql:Error result = dbClient->execute(
            `INSERT INTO drivers (id, name, phone, vehicle, status) VALUES (${id}, ${d.name}, ${d.phone}, ${d.vehicle}, 'AVAILABLE')`);
        if result is sql:Error {
            return <http:InternalServerError>{body: {message: "could not register driver"}};
        }
        return {id, name: d.name, phone: d.phone, vehicle: d.vehicle, status: "AVAILABLE", currentLat: 0d, currentLng: 0d};
    }

    resource function get drivers() returns Driver[]|http:InternalServerError {
        stream<Driver, sql:Error?> resultStream = dbClient->query(
            `SELECT id, name, phone, vehicle, status, current_lat as currentLat, current_lng as currentLng FROM drivers`);
        Driver[]|error drivers = from Driver dv in resultStream select dv;
        if drivers is error {
            return <http:InternalServerError>{body: {message: "could not fetch drivers"}};
        }
        return drivers;
    }

    // Bonus: Driver Location Simulation - drivers (or a simulator script) push coordinate updates here.
    resource function put drivers/[string driverId]/location(@http:Payload LocationUpdate loc)
            returns http:Ok|http:NotFound|http:InternalServerError {
        sql:ExecutionResult|sql:Error result = dbClient->execute(
            `UPDATE drivers SET current_lat = ${loc.lat}, current_lng = ${loc.lng} WHERE id = ${driverId}`);
        if result is sql:Error {
            return <http:InternalServerError>{body: {message: "could not update location"}};
        }
        if result.affectedRowCount == 0 {
            return <http:NotFound>{body: {message: "driver not found"}};
        }
        return <http:Ok>{body: {message: "location updated"}};
    }

    // ---- Deliveries ----

    resource function get deliveries() returns Delivery[]|http:InternalServerError {
        stream<Delivery, sql:Error?> resultStream = dbClient->query(
            `SELECT id, order_id as orderId, driver_id as driverId, restaurant_id as restaurantId, customer_id as customerId,
                    status, CAST(assigned_at AS CHAR) as assignedAt, CAST(delivered_at AS CHAR) as deliveredAt
             FROM deliveries ORDER BY assigned_at DESC`);
        Delivery[]|error deliveries = from Delivery d in resultStream select d;
        if deliveries is error {
            return <http:InternalServerError>{body: {message: "could not fetch deliveries"}};
        }
        return deliveries;
    }

    resource function get deliveries/[string orderId]() returns Delivery|http:NotFound|http:InternalServerError {
        Delivery|sql:Error result = dbClient->queryRow(
            `SELECT id, order_id as orderId, driver_id as driverId, restaurant_id as restaurantId, customer_id as customerId,
                    status, CAST(assigned_at AS CHAR) as assignedAt, CAST(delivered_at AS CHAR) as deliveredAt
             FROM deliveries WHERE order_id = ${orderId}`);
        if result is sql:NoRowsError {
            return <http:NotFound>{body: {message: "delivery not found for order"}};
        }
        if result is sql:Error {
            return <http:InternalServerError>{body: {message: "could not fetch delivery"}};
        }
        return result;
    }

    // Driver updates delivery progress. On DELIVERED: frees the driver and
    // publishes `delivery.completed`, which the Order Service consumes to
    // move the order into its terminal DELIVERED state.
    resource function put deliveries/[string orderId]/status(@http:Payload DeliveryStatusUpdate upd)
            returns http:Ok|http:BadRequest|http:NotFound|http:InternalServerError {
        if upd.status != "PICKED_UP" && upd.status != "DELIVERED" {
            return <http:BadRequest>{body: {message: "status must be PICKED_UP or DELIVERED"}};
        }

        record {| string id; string? driverId; |}|sql:Error deliveryRow = dbClient->queryRow(
            `SELECT id, driver_id as driverId FROM deliveries WHERE order_id = ${orderId}`);
        if deliveryRow is sql:NoRowsError {
            return <http:NotFound>{body: {message: "delivery not found for order"}};
        }
        if deliveryRow is sql:Error {
            return <http:InternalServerError>{body: {message: "could not fetch delivery"}};
        }

        if upd.status == "DELIVERED" {
            sql:ExecutionResult|sql:Error updateResult = dbClient->execute(
                `UPDATE deliveries SET status = 'DELIVERED', delivered_at = NOW() WHERE order_id = ${orderId}`);
            if updateResult is sql:Error {
                return <http:InternalServerError>{body: {message: "could not update delivery status"}};
            }
            string? driverId = deliveryRow.driverId;
            if driverId is string {
                sql:ExecutionResult|sql:Error driverResult = dbClient->execute(
                    `UPDATE drivers SET status = 'AVAILABLE' WHERE id = ${driverId}`);
                if driverResult is sql:Error {
                    return <http:InternalServerError>{body: {message: "could not free driver"}};
                }
                error? publishResult = publishDeliveryCompleted({
                    orderId,
                    driverId,
                    status: "DELIVERED",
                    timestamp: time:utcToString(time:utcNow())
                });
                if publishResult is error {
                    return <http:InternalServerError>{body: {message: "delivery marked complete but event publish failed"}};
                }
            }
        } else {
            sql:ExecutionResult|sql:Error pickedUpResult = dbClient->execute(
                `UPDATE deliveries SET status = 'PICKED_UP' WHERE order_id = ${orderId}`);
            if pickedUpResult is sql:Error {
                return <http:InternalServerError>{body: {message: "could not update delivery status"}};
            }
        }

        return <http:Ok>{body: {message: "delivery status updated", orderId, status: upd.status}};
    }

    resource function get health() returns json {
        return {status: "UP", 'service: "delivery-service"};
    }
}
