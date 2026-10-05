import ballerina/http;
import ballerina/sql;
import ballerina/time;
import ballerina/uuid;

configurable int servicePort = 8082;

service /restaurants on new http:Listener(servicePort) {

    resource function post .(@http:Payload NewRestaurant r) returns Restaurant|http:InternalServerError {
        string id = uuid:createType1AsString();
        sql:ParameterizedQuery q = `INSERT INTO restaurants (id, name, address, opening_time, closing_time)
            VALUES (${id}, ${r.name}, ${r.address}, ${r.openingTime}, ${r.closingTime})`;
        sql:ExecutionResult|sql:Error result = dbClient->execute(q);
        if result is sql:Error {
            return <http:InternalServerError>{body: {message: "could not create restaurant"}};
        }
        return {id, name: r.name, address: r.address, openingTime: r.openingTime, closingTime: r.closingTime, isOpen: true};
    }

    resource function get .() returns Restaurant[]|http:InternalServerError {
        stream<Restaurant, sql:Error?> resultStream = dbClient->query(
            `SELECT id, name, address, opening_time as openingTime, closing_time as closingTime, is_open as isOpen FROM restaurants`);
        Restaurant[]|error restaurants = from Restaurant r in resultStream select r;
        if restaurants is error {
            return <http:InternalServerError>{body: {message: "could not fetch restaurants"}};
        }
        return restaurants;
    }

    resource function get [string restaurantId]() returns Restaurant|http:NotFound|http:InternalServerError {
        Restaurant|sql:Error result = dbClient->queryRow(
            `SELECT id, name, address, opening_time as openingTime, closing_time as closingTime, is_open as isOpen
             FROM restaurants WHERE id = ${restaurantId}`);
        if result is sql:NoRowsError {
            return <http:NotFound>{body: {message: "restaurant not found"}};
        }
        if result is sql:Error {
            return <http:InternalServerError>{body: {message: "could not fetch restaurant"}};
        }
        return result;
    }

  resource function put [string restaurantId]/toggle() returns Restaurant|http:NotFound|http:InternalServerError {
    sql:ExecutionResult|sql:Error updateResult = dbClient->execute(`UPDATE restaurants SET is_open = NOT is_open WHERE id = ${restaurantId}`);
    if updateResult is sql:Error {
        return <http:InternalServerError>{body: {message: "could not toggle restaurant"}};
    }
    Restaurant|sql:Error result = dbClient->queryRow(
        `SELECT id, name, address, opening_time as openingTime, closing_time as closingTime, is_open as isOpen
         FROM restaurants WHERE id = ${restaurantId}`);
    if result is sql:NoRowsError {
        return <http:NotFound>{body: {message: "restaurant not found"}};
    }
    if result is sql:Error {
        return <http:InternalServerError>{body: {message: "could not fetch restaurant"}};
    }
    return result;
}

 

    resource function get health() returns json {
        return {status: "UP", 'service: "restaurant-service"};
    }
}
   // ---- Menu management ----

    resource function post [string restaurantId]/menu(@http:Payload NewMenuItem item) returns MenuItem|http:InternalServerError {
        string id = uuid:createType1AsString();
        sql:ParameterizedQuery q = `INSERT INTO menu_items (id, restaurant_id, name, price, stock)
            VALUES (${id}, ${restaurantId}, ${item.name}, ${item.price}, ${item.stock})`;
        sql:ExecutionResult|sql:Error result = dbClient->execute(q);
        if result is sql:Error {
            return <http:InternalServerError>{body: {message: "could not add menu item"}};
        }
        return {id, restaurantId, name: item.name, price: item.price, stock: item.stock, available: true};
    }

    resource function get [string restaurantId]/menu() returns MenuItem[]|http:InternalServerError {
        stream<MenuItem, sql:Error?> resultStream = dbClient->query(
            `SELECT id, restaurant_id as restaurantId, name, price, stock, available
             FROM menu_items WHERE restaurant_id = ${restaurantId}`);
        MenuItem[]|error items = from MenuItem m in resultStream select m;
        if items is error {
            return <http:InternalServerError>{body: {message: "could not fetch menu"}};
        }
        return items;
    }

    // Kitchen staff update the preparation status of an order.
    // Publishes a `kitchen.status.updated` Kafka event consumed by the Order Service.
    resource function put [string restaurantId]/orders/[string orderId]/status(@http:Payload StatusUpdateRequest req)
            returns http:Ok|http:BadRequest|http:InternalServerError {
        if req.status != "PREPARING" && req.status != "READY" {
            return <http:BadRequest>{body: {message: "status must be PREPARING or READY"}};
        }
        KitchenStatusUpdatedEvent event = {
            orderId,
            restaurantId,
            status: req.status,
            timestamp: time:utcToString(time:utcNow())
        };
        error? publishResult = publishKitchenStatusUpdated(event);
        if publishResult is error {
            return <http:InternalServerError>{body: {message: "could not publish kitchen status event"}};
        }
        return <http:Ok>{body: {message: "status update published", orderId, status: req.status}};
    }
