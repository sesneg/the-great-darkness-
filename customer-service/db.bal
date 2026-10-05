import ballerinax/mysql;
import ballerinax/mysql.driver as _;
//import ballerina/sql;

configurable string dbHost = "localhost";
configurable int dbPort = 3306;
configurable string dbUser = "fooddelivery";
configurable string dbPassword = "fooddelivery_pw";
configurable string dbName = "customer_db";

final mysql:Client dbClient = check new (
    host = dbHost,
    port = dbPort,
    user = dbUser,
    password = dbPassword,
    database = dbName,
    connectionPool = {maxOpenConnections: 10}
);
