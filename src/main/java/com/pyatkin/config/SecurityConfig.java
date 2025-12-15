package com.pyatkin.config;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.authority.mapping.GrantedAuthoritiesMapper;
import org.springframework.security.oauth2.client.oidc.authentication.OidcIdTokenDecoderFactory;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.security.oauth2.core.oidc.user.OidcUserAuthority;
import org.springframework.security.oauth2.core.user.OAuth2UserAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtIssuerValidator;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.logout.LogoutSuccessHandler;
import org.springframework.security.web.csrf.CookieCsrfTokenRepository;
import org.springframework.security.web.csrf.CsrfTokenRequestAttributeHandler;
import org.springframework.web.util.UriComponentsBuilder;

import java.util.Collection;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    // Keycloak logout через NGINX
    private static final String KEYCLOAK_LOGOUT_URL = "https://example.com/realms/spring-app/protocol/openid-connect/logout";
    private static final String POST_LOGOUT_REDIRECT_URI = "https://example.com/";

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        CsrfTokenRequestAttributeHandler requestHandler = new CsrfTokenRequestAttributeHandler();
        requestHandler.setCsrfRequestAttributeName("_csrf");

        http
                .authorizeHttpRequests(authorize -> authorize
                        // Публичные страницы
                        .requestMatchers("/", "/home", "/public/**", "/css/**", "/js/**", "/images/**").permitAll()
                        .requestMatchers("/actuator/health", "/actuator/info").permitAll()
                        // Защищенные страницы
                        .requestMatchers("/admin/**").hasRole("ADMIN")
                        .requestMatchers("/user/**", "/profile/**").hasAnyRole("USER", "ADMIN")
                        .anyRequest().authenticated()
                )
                .oauth2Login(oauth2 -> oauth2
                        // Перенаправление на Keycloak
                        .defaultSuccessUrl("/profile", true)
                        .failureUrl("/?error=auth_failed")
                )
                .logout(logout -> logout
                        .logoutUrl("/logout")
                        .logoutSuccessHandler(keycloakLogoutSuccessHandler())
                        .invalidateHttpSession(true)
                        .clearAuthentication(true)
                        .deleteCookies("JSESSIONID")
                )
                .csrf(csrf -> csrf
                        .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
                        .csrfTokenRequestHandler(requestHandler)
                );

        return http.build();
    }

    /**
     * Keycloak logout handler - выход из Keycloak с RP-Initiated Logout
     */
    private LogoutSuccessHandler keycloakLogoutSuccessHandler() {
        return (HttpServletRequest request, HttpServletResponse response, Authentication authentication) -> {
            String logoutUrl;

            if (authentication != null && authentication.getPrincipal() instanceof OidcUser oidcUser) {
                String idToken = oidcUser.getIdToken().getTokenValue();

                logoutUrl = UriComponentsBuilder.fromUriString(KEYCLOAK_LOGOUT_URL)
                        .queryParam("id_token_hint", idToken)
                        .queryParam("post_logout_redirect_uri", POST_LOGOUT_REDIRECT_URI)
                        .build()
                        .toUriString();
            } else {
                logoutUrl = UriComponentsBuilder.fromUriString(KEYCLOAK_LOGOUT_URL)
                        .queryParam("post_logout_redirect_uri", POST_LOGOUT_REDIRECT_URI)
                        .build()
                        .toUriString();
            }

            response.sendRedirect(logoutUrl);
        };
    }

    /**
     * Mapper для извлечения ролей из Keycloak JWT токена
     * Маппит realm_access.roles и resource_access.*.roles в Spring Security GrantedAuthority
     */
    @Bean
    public GrantedAuthoritiesMapper userAuthoritiesMapper() {
        return authorities -> {
            Set<GrantedAuthority> mappedAuthorities = new HashSet<>();

            authorities.forEach(authority -> {
                if (authority instanceof OidcUserAuthority oidcUserAuthority) {
                    mappedAuthorities.addAll(extractAuthorities(oidcUserAuthority.getIdToken().getClaims()));
                } else if (authority instanceof OAuth2UserAuthority oauth2UserAuthority) {
                    mappedAuthorities.addAll(extractAuthorities(oauth2UserAuthority.getAttributes()));
                }
            });

            return mappedAuthorities;
        };
    }

    /**
     * Кастомная фабрика JWT декодера для ID токенов
     * Принимает токены с issuer от NGINX (https://example.com)
     */
    @Bean
    public OidcIdTokenDecoderFactory idTokenDecoderFactory() {
        OidcIdTokenDecoderFactory idTokenDecoderFactory = new OidcIdTokenDecoderFactory();
        idTokenDecoderFactory.setJwtValidatorFactory(clientRegistration -> {
            // Валидатор для issuer от NGINX
            OAuth2TokenValidator<Jwt> issuerValidator = new JwtIssuerValidator(
                    "https://example.com/realms/spring-app"
            );
            OAuth2TokenValidator<Jwt> timestampValidator = new JwtTimestampValidator();

            return new DelegatingOAuth2TokenValidator<>(
                    issuerValidator,
                    timestampValidator
            );
        });
        return idTokenDecoderFactory;
    }

    @SuppressWarnings("unchecked")
    private Collection<GrantedAuthority> extractAuthorities(Map<String, Object> claims) {
        Set<GrantedAuthority> authorities = new HashSet<>();

        // Извлекаем realm roles из realm_access.roles
        if (claims.containsKey("realm_access")) {
            Map<String, Object> realmAccess = (Map<String, Object>) claims.get("realm_access");
            if (realmAccess.containsKey("roles")) {
                Collection<String> roles = (Collection<String>) realmAccess.get("roles");
                authorities.addAll(roles.stream()
                        .map(role -> new SimpleGrantedAuthority("ROLE_" + role.toUpperCase()))
                        .collect(Collectors.toSet()));
            }
        }

        // Извлекаем client roles из resource_access.<client_id>.roles
        if (claims.containsKey("resource_access")) {
            Map<String, Object> resourceAccess = (Map<String, Object>) claims.get("resource_access");
            resourceAccess.forEach((resource, resourceClaims) -> {
                if (resourceClaims instanceof Map) {
                    Map<String, Object> resourceMap = (Map<String, Object>) resourceClaims;
                    if (resourceMap.containsKey("roles")) {
                        Collection<String> roles = (Collection<String>) resourceMap.get("roles");
                        authorities.addAll(roles.stream()
                                .map(role -> new SimpleGrantedAuthority("ROLE_" + role.toUpperCase()))
                                .collect(Collectors.toSet()));
                    }
                }
            });
        }

        return authorities;
    }
}