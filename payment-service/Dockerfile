# ---- Build stage ----
FROM ballerina/ballerina:2201.10.0 AS build
WORKDIR /home/ballerina
COPY . .
RUN bal build

# ---- Runtime stage ----
FROM eclipse-temurin:21-jre
WORKDIR /home
COPY target/bin/payment_service.jar ./app.jar
EXPOSE 8084
CMD ["java", "-jar", "app.jar"]