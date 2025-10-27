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
