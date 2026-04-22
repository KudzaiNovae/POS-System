package com.tillpro.api.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.Map;
import java.util.UUID;

@Service
public class JwtService {

    private final SecretKey key;
    private final long expirationMs;
    private final long refreshExpirationMs;

    public JwtService(
            @Value("${tillpro.jwt.secret}") String secret,
            @Value("${tillpro.jwt.expiration-ms}") long expirationMs,
            @Value("${tillpro.jwt.refresh-expiration-ms}") long refreshExpirationMs) {
        // HS256 requires at least 256 bits of key material
        byte[] bytes = secret.getBytes(StandardCharsets.UTF_8);
        if (bytes.length < 32) {
            throw new IllegalStateException(
                "tillpro.jwt.secret must be at least 32 bytes for HS256");
        }
        this.key = Keys.hmacShaKeyFor(bytes);
        this.expirationMs = expirationMs;
        this.refreshExpirationMs = refreshExpirationMs;
    }

    public String issueAccess(UUID userId, UUID tenantId, String tier, String role) {
        Date now = new Date();
        return Jwts.builder()
                .subject(userId.toString())
                .claims(Map.of(
                        "tenantId", tenantId.toString(),
                        "tier", tier,
                        "role", role,
                        "typ", "access"))
                .issuedAt(now)
                .expiration(new Date(now.getTime() + expirationMs))
                .signWith(key)
                .compact();
    }

    public String issueRefresh(UUID userId, UUID tenantId) {
        Date now = new Date();
        return Jwts.builder()
                .subject(userId.toString())
                .claims(Map.of("tenantId", tenantId.toString(), "typ", "refresh"))
                .issuedAt(now)
                .expiration(new Date(now.getTime() + refreshExpirationMs))
                .signWith(key)
                .compact();
    }

    public Claims parse(String token) {
        return Jwts.parser().verifyWith(key).build()
                .parseSignedClaims(token).getPayload();
    }

    public long getExpirationSeconds() { return expirationMs / 1000; }
}
