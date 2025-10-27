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
