package com.pyatkin.config;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.authority.mapping.GrantedAuthoritiesMapper;
import org.springframework.security.web.SecurityFilterChain;

import java.util.HashSet;

@TestConfiguration
@EnableWebSecurity
public class TestSecurityConfig {

    @Bean
    @Primary
    public SecurityFilterChain testSecurityFilterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(authorize -> authorize
                .requestMatchers("/", "/home", "/public/**", "/css/**", "/js/**", "/images/**").permitAll()
                .requestMatchers("/actuator/health", "/actuator/info").permitAll()
                .requestMatchers("/admin/**").hasRole("ADMIN")
                .requestMatchers("/user/**", "/profile/**").hasAnyRole("USER", "ADMIN")
                .anyRequest().authenticated()
            )
            .csrf().disable();

        return http.build();
    }

    @Bean
    @Primary
    public GrantedAuthoritiesMapper testUserAuthoritiesMapper() {
        return authorities -> {
            var mappedAuthorities = new HashSet<SimpleGrantedAuthority>();
            mappedAuthorities.add(new SimpleGrantedAuthority("ROLE_USER"));
            return mappedAuthorities;
        };
    }
}
