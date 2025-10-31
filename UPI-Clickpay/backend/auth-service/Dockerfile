FROM openjdk:17-jdk-slim

WORKDIR /app

COPY target/auth-service-1.0.0.jar app.jar

EXPOSE 8081

CMD ["java", "-jar", "app.jar"]