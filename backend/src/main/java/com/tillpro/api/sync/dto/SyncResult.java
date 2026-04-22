package com.tillpro.api.sync.dto;

import java.time.Instant;
import java.util.List;

public record SyncResult(List<Entry> results, Instant serverNow) {
    public record Entry(String entity, String id, boolean accepted, Long serverVersion, String reason) {
        public static Entry ok(String entity, String id, Long v) {
            return new Entry(entity, id, true, v, null);
        }
        public static Entry reject(String entity, String id, String reason) {
            return new Entry(entity, id, false, null, reason);
        }
    }
}
