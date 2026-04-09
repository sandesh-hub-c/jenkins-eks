package com.devops.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Main entry point for the Spring Boot DevOps Demo application.
 * This is a simple REST API used to demonstrate CI/CD with Jenkins, Docker, and EKS.
 */
@SpringBootApplication
public class DemoApplication {

    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}
