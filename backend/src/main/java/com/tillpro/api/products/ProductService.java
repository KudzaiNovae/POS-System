package com.tillpro.api.products;

import com.tillpro.api.domain.Product;
import com.tillpro.api.products.dto.ProductDto;
import com.tillpro.api.repo.ProductRepository;
import com.tillpro.api.subscriptions.TierPolicy;
import com.tillpro.api.web.ApiException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
public class ProductService {

    private final ProductRepository products;
    private final TierPolicy tier;

    public ProductService(ProductRepository products, TierPolicy tier) {
        this.products = products;
        this.tier = tier;
    }

    @Transactional(readOnly = true)
    public List<ProductDto> list(UUID tenantId, Instant since, int limit) {
        Instant cutoff = since != null ? since : Instant.EPOCH;
        return products.findByTenantIdAndUpdatedAtAfter(tenantId, cutoff).stream()
                .limit(limit)
                .map(ProductDto::from)
                .toList();
    }

    @Transactional
    public ProductDto upsert(UUID tenantId, ProductDto dto) {
        Product p = products.findByIdAndTenantId(dto.id(), tenantId).orElse(null);
        boolean isNew = (p == null);

        if (isNew) {
            long count = products.countByTenantIdAndDeletedFalse(tenantId);
            tier.assertProductCount(count + 1);
            p = Product.builder()
                    .id(dto.id())
                    .tenantId(tenantId)
                    .build();
        }

        p.setSku(dto.sku());
        p.setName(dto.name());
        p.setBarcode(dto.barcode());
        p.setPriceCents(dto.priceCents());
        p.setCostCents(dto.costCents() != null ? dto.costCents() : 0L);
        p.setStockQty(dto.stockQty() != null ? dto.stockQty() : BigDecimal.ZERO);
        p.setReorderLevel(dto.reorderLevel() != null ? dto.reorderLevel() : BigDecimal.ZERO);
        p.setUnit(dto.unit() != null ? dto.unit() : "pc");
        p.setVatClass(dto.vatClass() != null ? dto.vatClass() : "STANDARD");
        p.setDeleted(Boolean.TRUE.equals(dto.deleted()));

        return ProductDto.from(products.save(p));
    }

    @Transactional
    public ProductDto patch(UUID tenantId, UUID id, ProductDto dto) {
        Product p = products.findByIdAndTenantId(id, tenantId)
                .orElseThrow(() -> ApiException.notFound("Product not found."));
        if (dto.name() != null)           p.setName(dto.name());
        if (dto.priceCents() != null)     p.setPriceCents(dto.priceCents());
        if (dto.costCents() != null)      p.setCostCents(dto.costCents());
        if (dto.stockQty() != null)       p.setStockQty(dto.stockQty());
        if (dto.reorderLevel() != null)   p.setReorderLevel(dto.reorderLevel());
        if (dto.barcode() != null)        p.setBarcode(dto.barcode());
        if (dto.unit() != null)           p.setUnit(dto.unit());
        if (dto.vatClass() != null)       p.setVatClass(dto.vatClass());
        return ProductDto.from(products.save(p));
    }

    @Transactional
    public void softDelete(UUID tenantId, UUID id) {
        Product p = products.findByIdAndTenantId(id, tenantId)
                .orElseThrow(() -> ApiException.notFound("Product not found."));
        p.setDeleted(true);
        products.save(p);
    }
}
