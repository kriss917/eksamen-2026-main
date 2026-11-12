FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn -B dependency:go-offline
COPY src ./src
RUN mvn -B package 

FROM eclipse-temurin:21-jre
WORKDIR /app
RUN useradd --system --uid 1001 appuser
COPY --from=builder /app/target/*.jar /app/application.jar
USER appuser
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/application.jar"]