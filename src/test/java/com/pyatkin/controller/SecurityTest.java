package com.pyatkin.controller;

import com.pyatkin.config.TestSecurityConfig;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.test.context.support.WithAnonymousUser;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.MOCK,
    properties = "spring.profiles.active=test"
)
@AutoConfigureMockMvc
@Import(TestSecurityConfig.class)
class SecurityTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @WithAnonymousUser
    void profilePageShouldRequireAuthentication() throws Exception {
        mockMvc.perform(get("/profile"))
            .andExpect(status().is3xxRedirection());
    }

    @Test
    @WithMockUser(roles = "USER")
    void profilePageShouldBeAccessibleForAuthenticatedUsers() throws Exception {
        mockMvc.perform(get("/profile"))
            .andExpect(status().isOk());
    }

    @Test
    @WithAnonymousUser
    void adminPageShouldRequireAuthentication() throws Exception {
        mockMvc.perform(get("/admin"))
            .andExpect(status().is3xxRedirection());
    }

    @Test
    @WithMockUser(roles = "USER")
    void adminPageShouldBeForbiddenForRegularUsers() throws Exception {
        mockMvc.perform(get("/admin"))
            .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void adminPageShouldBeAccessibleForAdmins() throws Exception {
        mockMvc.perform(get("/admin"))
            .andExpect(status().isOk());
    }
}
