import ballerina/http;
import ballerina/sql;

configurable int servicePort = 8087;

service /admin on new http:Listener(servicePort) {

    resource function get reports/restaurants() returns RestaurantStats[]|http:InternalServerError {
        stream<RestaurantStats, sql:Error?> resultStream = dbClient->query(
            `SELECT restaurant_id as restaurantId, total_orders as totalOrders, total_revenue as totalRevenue,
                    cancelled_orders as cancelledOrders, CAST(last_updated AS CHAR) as lastUpdated
             FROM restaurant_stats ORDER BY total_revenue DESC`);
        RestaurantStats[]|error stats = from RestaurantStats s in resultStream select s;
        if stats is error {
            return <http:InternalServerError>{body: {message: "could not fetch restaurant stats"}};
        }
        return stats;
    }

    resource function get reports/restaurants/[string restaurantId]() returns RestaurantStats|http:NotFound|http:InternalServerError {
        RestaurantStats|sql:Error result = dbClient->queryRow(
            `SELECT restaurant_id as restaurantId, total_orders as totalOrders, total_revenue as totalRevenue,
                    cancelled_orders as cancelledOrders, CAST(last_updated AS CHAR) as lastUpdated
             FROM restaurant_stats WHERE restaurant_id = ${restaurantId}`);
        if result is sql:NoRowsError {
            return <http:NotFound>{body: {message: "no stats for this restaurant yet"}};
        }
        if result is sql:Error {
            return <http:InternalServerError>{body: {message: "could not fetch restaurant stats"}};
        }
        return result;
    }

    resource function get reports/delivery() returns DriverStats[]|http:InternalServerError {
        stream<DriverStats, sql:Error?> resultStream = dbClient->query(
            `SELECT driver_id as driverId, total_deliveries as totalDeliveries, active_deliveries as activeDeliveries,
                    CAST(last_updated AS CHAR) as lastUpdated
             FROM driver_stats ORDER BY total_deliveries DESC`);
        DriverStats[]|error stats = from DriverStats s in resultStream select s;
        if stats is error {
            return <http:InternalServerError>{body: {message: "could not fetch delivery stats"}};
        }
        return stats;
    }

    resource function get reports/delivery/[string driverId]() returns DriverStats|http:NotFound|http:InternalServerError {
        DriverStats|sql:Error result = dbClient->queryRow(
            `SELECT driver_id as driverId, total_deliveries as totalDeliveries, active_deliveries as activeDeliveries,
                    CAST(last_updated AS CHAR) as lastUpdated
             FROM driver_stats WHERE driver_id = ${driverId}`);
        if result is sql:NoRowsError {
            return <http:NotFound>{body: {message: "no stats for this driver yet"}};
        }
        if result is sql:Error {
            return <http:InternalServerError>{body: {message: "could not fetch driver stats"}};
        }
        return result;
    }

    resource function get reports/summary() returns json|http:InternalServerError {
        record {| int totalOrders; decimal totalRevenue; int totalCancelled; |}|sql:Error orderTotals =
            dbClient->queryRow(`SELECT CAST(COALESCE(SUM(total_orders),0) AS SIGNED) as totalOrders,
                                        COALESCE(SUM(total_revenue),0) as totalRevenue,
                                        CAST(COALESCE(SUM(cancelled_orders),0) AS SIGNED) as totalCancelled
                                 FROM restaurant_stats`);
        record {| int totalDeliveries; int activeDeliveries; |}|sql:Error deliveryTotals =
            dbClient->queryRow(`SELECT CAST(COALESCE(SUM(total_deliveries),0) AS SIGNED) as totalDeliveries,
                                        CAST(COALESCE(SUM(active_deliveries),0) AS SIGNED) as activeDeliveries
                                 FROM driver_stats`);
        if orderTotals is sql:Error || deliveryTotals is sql:Error {
            return <http:InternalServerError>{body: {message: "could not compute summary"}};
        }
        return {
            orders: orderTotals,
            deliveries: deliveryTotals
        };
    }

    resource function get health() returns json {
        return {status: "UP", 'service: "admin-service"};
    }
}
