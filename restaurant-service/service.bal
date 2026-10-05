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
