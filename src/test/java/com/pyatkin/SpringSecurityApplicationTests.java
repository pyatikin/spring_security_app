package com.pyatkin;

import com.pyatkin.config.TestSecurityConfig;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;

@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.MOCK,
    properties = "spring.profiles.active=test"
)
@Import(TestSecurityConfig.class)
class SpringSecurityApplicationTests {

    @Test
    void contextLoads() {
    }
}
