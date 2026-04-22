package com.tillpro.api.sync;

import com.tillpro.api.security.TenantContext;
import com.tillpro.api.sync.dto.*;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/sync")
public class SyncController {

    private final SyncService svc;

    public SyncController(SyncService svc) { this.svc = svc; }

    @PostMapping("/push")
    public SyncResult push(@RequestBody SyncPushRequest req) {
        return svc.push(TenantContext.requireTenantId(), req);
    }

    @PostMapping("/pull")
    public SyncPullResponse pull(@RequestBody SyncPullRequest req) {
        return svc.pull(TenantContext.requireTenantId(), req);
    }
}
