package com.tillpro.api.web;

import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public class ApiException extends RuntimeException {
    private final HttpStatus status;
    private final String code;

    public ApiException(HttpStatus status, String code, String message) {
        super(message);
        this.status = status;
        this.code = code;
    }

    public static ApiException validation(String msg)   { return new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION", msg); }
    public static ApiException unauth(String msg)       { return new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHENTICATED", msg); }
    public static ApiException forbidden(String msg)    { return new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", msg); }
    public static ApiException notFound(String msg)     { return new ApiException(HttpStatus.NOT_FOUND, "NOT_FOUND", msg); }
    public static ApiException conflict(String msg)     { return new ApiException(HttpStatus.CONFLICT, "CONFLICT", msg); }
    public static ApiException tierLimit(String msg)    { return new ApiException(HttpStatus.PAYMENT_REQUIRED, "TIER_LIMIT_EXCEEDED", msg); }
    public static ApiException paymentRequired(String msg) { return new ApiException(HttpStatus.PAYMENT_REQUIRED, "PAYMENT_REQUIRED", msg); }
}
