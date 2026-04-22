package com.tillpro.api.products;

import com.tillpro.api.domain.Product;
import com.tillpro.api.products.dto.ProductDto;
import com.tillpro.api.security.TenantContext;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/products")
public class ProductController {

    private final ProductService svc;

    public ProductController(ProductService svc) { this.svc = svc; }

    @GetMapping
    public List<ProductDto> list(
            @RequestParam(required = false) Instant since,
            @RequestParam(required = false, defaultValue = "200") int limit) {
        return svc.list(TenantContext.requireTenantId(), since, limit);
    }

    @PostMapping
    public ProductDto upsert(@Valid @RequestBody ProductDto dto) {
        return svc.upsert(TenantContext.requireTenantId(), dto);
    }

    @PatchMapping("/{id}")
    public ProductDto patch(@PathVariable UUID id, @RequestBody ProductDto dto) {
        return svc.patch(TenantContext.requireTenantId(), id, dto);
    }

    @DeleteMapping("/{id}")
    public void delete(@PathVariable UUID id) {
        svc.softDelete(TenantContext.requireTenantId(), id);
    }
}
