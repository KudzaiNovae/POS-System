package com.tillpro.api.reports;

import com.tillpro.api.domain.ZReport;
import com.tillpro.api.security.TenantContext;
import com.tillpro.api.web.ApiException;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/reports/z")
public class ZReportController {

    private final ZReportService svc;

    public ZReportController(ZReportService svc) { this.svc = svc; }

    /** Closes (or re-closes) the business day. Owners / managers only. */
    @PostMapping("/close")
    public ZReport close(@RequestBody(required = false) Map<String, String> body) {
        if (!isManagerOrOwner()) {
            throw ApiException.forbidden("Only owners/managers can close the day.");
        }
        LocalDate d = (body == null || body.get("date") == null)
                ? LocalDate.now()
                : LocalDate.parse(body.get("date"));
        return svc.close(TenantContext.requireTenantId(), d);
    }

    @GetMapping("/list")
    public List<ZReport> list() {
        return svc.recent(TenantContext.requireTenantId());
    }

    @GetMapping("/{date}")
    public ZReport get(@PathVariable String date) {
        return svc.get(TenantContext.requireTenantId(), LocalDate.parse(date));
    }

    private static boolean isManagerOrOwner() {
        String role = TenantContext.getRole();
        return "OWNER".equals(role) || "MANAGER".equals(role);
    }
}
