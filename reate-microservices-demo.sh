#!/bin/bash

set -e

ROOT_DIR="microservices-demo"
MAIN_DIR="$ROOT_DIR/main-service"
ANALYTICS_DIR="$ROOT_DIR/analytics-service"

echo "Creating project structure..."
mkdir -p $MAIN_DIR/src/main/java/com/example/mainservice/{controller,service,config}
mkdir -p $MAIN_DIR/src/main/resources
mkdir -p $ANALYTICS_DIR/src/main/java/com/example/analyticsservice/controller
mkdir -p $ANALYTICS_DIR/src/main/resources

echo "Creating main-service files..."

# MainServiceApplication.java
cat > $MAIN_DIR/src/main/java/com/example/mainservice/MainServiceApplication.java <<EOL
package com.example.mainservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class MainServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(MainServiceApplication.class, args);
    }
}
EOL

# AsyncConfig.java
cat > $MAIN_DIR/src/main/java/com/example/mainservice/config/AsyncConfig.java <<EOL
package com.example.mainservice.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.web.reactive.function.client.WebClient;
import java.util.concurrent.Executor;

@Configuration
@EnableAsync
public class AsyncConfig {
    @Bean
    public Executor taskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(5);
        executor.setMaxPoolSize(20);
        executor.setQueueCapacity(500);
        executor.setThreadNamePrefix("AsyncExec-");
        executor.initialize();
        return executor;
    }

    @Bean
    public WebClient webClient() {
        return WebClient.builder().build();
    }
}
EOL

# AnalyticsService.java
cat > $MAIN_DIR/src/main/java/com/example/mainservice/service/AnalyticsService.java <<EOL
package com.example.mainservice.service;

import com.example.mainservice.controller.UserController.AnalyticsEvent;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;
import java.util.concurrent.CompletableFuture;

@Service
@RequiredArgsConstructor
public class AnalyticsService {

    private static final Logger logger = LoggerFactory.getLogger(AnalyticsService.class);
    private final WebClient webClient;

    @Value("\${analytics.service.url}")
    private String analyticsUrl;

    @Async
    public CompletableFuture<Void> sendEventAsync(AnalyticsEvent event) {
        logger.info("Async sendEventAsync - starting for event: {}", event.getEvent());

        Mono<String> respMono = webClient.post()
                .uri(analyticsUrl)
                .bodyValue(event)
                .retrieve()
                .bodyToMono(String.class)
                .doOnSuccess(s -> logger.info("Analytics service responded: {}", s))
                .doOnError(e -> logger.error("Error sending analytics: {}", e.getMessage()));

        CompletableFuture<Void> future = respMono.then().toFuture();
        future.whenComplete((v, ex) -> {
            if (ex != null) {
                logger.error("Async analytics call failed: {}", ex.getMessage());
            } else {
                logger.info("Async analytics call completed for event: {}", event.getEvent());
            }
        });

        return future;
    }
}
EOL

# UserController.java
cat > $MAIN_DIR/src/main/java/com/example/mainservice/controller/UserController.java <<EOL
package com.example.mainservice.controller;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.time.Instant;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

@RestController
@RequestMapping("/users")
@RequiredArgsConstructor
public class UserController {

    private static final Logger logger = LoggerFactory.getLogger(UserController.class);
    private final com.example.mainservice.service.AnalyticsService analyticsService;

    private final List<User> users = new CopyOnWriteArrayList<>();

    @PostMapping
    public ResponseEntity<String> createUser(@RequestBody CreateUserRequest req) {
        logger.info("Received request to create user: {}", req.getName());

        User user = new User(req.getName(), Instant.now().toString());
        users.add(user);
        logger.info("User '{}' added locally at {}", req.getName(), Instant.now().toString());

        AnalyticsEvent event = new AnalyticsEvent("USER_CREATED", req.getName(), Instant.now().toString());
        analyticsService.sendEventAsync(event);

        return ResponseEntity.accepted().body("User creation started");
    }

    @GetMapping
    public List<User> getAllUsers() {
        return users;
    }

    @Data
    public static class CreateUserRequest { private String name; }

    @Data
    @AllArgsConstructor
    public static class AnalyticsEvent { private String event; private String name; private String timestamp; }

    @Data
    @AllArgsConstructor
    public static class User { private String name; private String createdAt; }
}
EOL

# main-service application.properties
cat > $MAIN_DIR/src/main/resources/application.properties <<EOL
server.port=8080
analytics.service.url=http://localhost:8081/analytics/event
logging.level.root=INFO
logging.level.com.example=DEBUG
EOL

# main-service pom.xml
cat > $MAIN_DIR/pom.xml <<EOL
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.3.4</version>
    <relativePath/>
  </parent>
  <groupId>com.example</groupId>
  <artifactId>main-service</artifactId>
  <version>0.0.1-SNAPSHOT</version>
  <name>main-service</name>
  <properties>
    <java.version>17</java.version>
  </properties>
  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-webflux</artifactId>
    </dependency>
    <dependency>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <version>1.18.32</version>
        <scope>provided</scope>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
EOL

# --- analytics-service files ---
# AnalyticsServiceApplication.java
cat > $ANALYTICS_DIR/src/main/java/com/example/analyticsservice/AnalyticsServiceApplication.java <<EOL
package com.example.analyticsservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class AnalyticsServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(AnalyticsServiceApplication.class, args);
    }
}
EOL

# AnalyticsController.java
cat > $ANALYTICS_DIR/src/main/java/com/example/analyticsservice/controller/AnalyticsController.java <<EOL
package com.example.analyticsservice.controller;

import lombok.Data;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.Random;

@RestController
@RequestMapping("/analytics")
@Slf4j
public class AnalyticsController {

    private final Random random = new Random();

    @PostMapping("/event")
    public ResponseEntity<String> receiveEvent(@RequestBody AnalyticsEvent event) throws InterruptedException {
        log.info("📩 Received analytics event: {}", event);

        int delay = 1000 + random.nextInt(4000);
        Thread.sleep(delay);

        if (random.nextDouble() < 0.3) {
            log.error("💥 Simulated analytics failure!");
            return ResponseEntity.internalServerError().body("Simulated failure");
        }

        log.info("✅ Processed analytics event after {} ms", delay);
        return ResponseEntity.ok("Event processed successfully");
    }

    @Data
    public static class AnalyticsEvent {
        private String event;
        private String name;
        private String timestamp;
    }
}
EOL

# analytics-service application.properties
cat > $ANALYTICS_DIR/src/main/resources/application.properties <<EOL
server.port=8081
logging.level.root=INFO
logging.level.com.example=DEBUG
EOL

# analytics-service pom.xml
cat > $ANALYTICS_DIR/pom.xml <<EOL
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.3.4</version>
    <relativePath/>
  </parent>
  <groupId>com.example</groupId>
  <artifactId>analytics-service</artifactId>
  <version>0.0.1-SNAPSHOT</version>
  <name>analytics-service</name>
  <properties>
    <java.version>17</java.version>
  </properties>
  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
    <dependency>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <version>1.18.32</version>
        <scope>provided</scope>
    </dependency>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
    </dependency>
  </dependencies>
  <build>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
EOL

# Zip the project
zip -r microservices-demo-full-setup.zip $ROOT_DIR

echo "✅ Full microservices project created and zipped: microservices-demo-full-setup.zip"
