package com.tillpro.api.customers;

import com.tillpro.api.customers.dto.CustomerDto;
import com.tillpro.api.security.TenantContext;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/customers")
public class CustomerController {

    private final CustomerService svc;

    public CustomerController(CustomerService svc) { this.svc = svc; }

    @GetMapping
    public List<CustomerDto> list() {
        return svc.list(TenantContext.requireTenantId());
    }

    @GetMapping("/{id}")
    public CustomerDto get(@PathVariable UUID id) {
        return svc.get(TenantContext.requireTenantId(), id);
    }

    @PostMapping
    public CustomerDto upsert(@Valid @RequestBody CustomerDto dto) {
        return svc.upsert(TenantContext.requireTenantId(), dto);
    }

    @DeleteMapping("/{id}")
    public void delete(@PathVariable UUID id) {
        svc.delete(TenantContext.requireTenantId(), id);
    }
}
