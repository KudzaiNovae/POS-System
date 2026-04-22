package com.tillpro.api;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class TillProApplicationTests {
    @Test
    void contextLoads() { /* smoke test */ }
}
