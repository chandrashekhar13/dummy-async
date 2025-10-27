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

    @Value("${analytics.service.url}")
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
