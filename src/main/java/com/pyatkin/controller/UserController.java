package com.pyatkin.controller;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

@Controller
@RequestMapping("/profile")
public class UserController {

    @GetMapping
    public String profile(@AuthenticationPrincipal OidcUser principal, Model model) {
        if (principal != null) {
            model.addAttribute("username", principal.getPreferredUsername());
            model.addAttribute("email", principal.getEmail());
            model.addAttribute("name", principal.getFullName());
            model.addAttribute("roles", principal.getAuthorities());
        }
        return "profile";
    }
}
