package com.devops.demo.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.InetAddress;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Simple REST controller that exposes health and info endpoints.
 * Used to verify the application is running correctly on EKS.
 */
@RestController
public class HelloController {

    private static final DateTimeFormatter FORMATTER =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    /**
     * Root endpoint — returns a welcome message.
     */
    @GetMapping("/")
    public Map<String, String> home() {
        Map<String, String> response = new LinkedHashMap<>();
        response.put("message", "Welcome to the DevOps Demo App!");
        response.put("status", "UP");
        response.put("timestamp", LocalDateTime.now().format(FORMATTER));
        return response;
    }

    /**
     * Health check endpoint — used by Kubernetes liveness/readiness probes.
     */
    @GetMapping("/health")
    public Map<String, String> health() {
        Map<String, String> response = new LinkedHashMap<>();
        response.put("status", "healthy");
        response.put("timestamp", LocalDateTime.now().format(FORMATTER));
        return response;
    }

    /**
     * Info endpoint — shows hostname (pod name in Kubernetes) for load balancing demo.
     */
    @GetMapping("/info")
    public Map<String, String> info() {
        Map<String, String> response = new LinkedHashMap<>();
        response.put("application", "devops-demo");
        response.put("version", "1.0.0");
        response.put("timestamp", LocalDateTime.now().format(FORMATTER));
        try {
            response.put("hostname", InetAddress.getLocalHost().getHostName());
        } catch (Exception e) {
            response.put("hostname", "unknown");
        }
        return response;
    }
}
