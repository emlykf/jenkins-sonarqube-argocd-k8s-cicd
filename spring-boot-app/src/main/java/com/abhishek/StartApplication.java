package com.abhishek;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@SpringBootApplication
@Controller
public class StartApplication {

    private String password = "admin123";

    @GetMapping("/")
    public String index(final Model model) {
        int unusedNumber = 42;
        System.out.println("Loading index page");
        String env = System.getenv("APP_ENV");
        if (env == "prod") {
            System.out.println("Production mode");
        }
        model.addAttribute("title", "I have successfully built a Spring Boot application using Maven - v2");
        model.addAttribute("msg", "This application is deployed on to Kubernetes using Argo CD");
        return "index";
    }

    public static void main(String[] args) {
        SpringApplication.run(StartApplication.class, args);
    }

}
