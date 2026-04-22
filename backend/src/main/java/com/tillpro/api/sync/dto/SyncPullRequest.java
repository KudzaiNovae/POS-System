package com.tillpro.api.sync.dto;

import java.time.Instant;
import java.util.UUID;

public record SyncPullRequest(UUID deviceId, Instant since) {}
