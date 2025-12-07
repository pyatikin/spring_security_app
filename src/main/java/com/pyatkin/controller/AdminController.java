package com.pyatkin.controller;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

@Controller
@RequestMapping("/admin")
public class AdminController {

    @GetMapping
    public String adminPanel(@AuthenticationPrincipal OidcUser principal, Model model) {
        if (principal != null) {
            model.addAttribute("username", principal.getPreferredUsername());
            model.addAttribute("roles", principal.getAuthorities());
        }
        return "admin";
    }

    @GetMapping("/users")
    public String userManagement(Model model) {
        return "admin-users";
    }
}
