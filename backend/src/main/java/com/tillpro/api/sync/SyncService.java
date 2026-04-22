package com.tillpro.api.sync;

import com.tillpro.api.domain.Sale;
import com.tillpro.api.domain.Subscription;
import com.tillpro.api.products.ProductService;
import com.tillpro.api.products.dto.ProductDto;
import com.tillpro.api.repo.SaleItemRepository;
import com.tillpro.api.repo.SaleRepository;
import com.tillpro.api.sales.SalesService;
import com.tillpro.api.sales.dto.SaleDto;
import com.tillpro.api.sales.dto.SaleItemDto;
import com.tillpro.api.subscriptions.TierPolicy;
import com.tillpro.api.sync.dto.*;
import com.tillpro.api.web.ApiException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class SyncService {

    private final ProductService productService;
    private final SalesService salesService;
    private final com.tillpro.api.repo.ProductRepository productRepo;
    private final SaleRepository saleRepo;
    private final SaleItemRepository itemRepo;
    private final TierPolicy tier;

    public SyncService(ProductService productService, SalesService salesService,
                       com.tillpro.api.repo.ProductRepository productRepo,
                       SaleRepository saleRepo, SaleItemRepository itemRepo,
                       TierPolicy tier) {
        this.productService = productService;
        this.salesService = salesService;
        this.productRepo = productRepo;
        this.saleRepo = saleRepo;
        this.itemRepo = itemRepo;
        this.tier = tier;
    }

    /**
     * Receive a batch of client writes. Each entry is applied in its own
     * nested transaction so a single bad row doesn't fail the whole batch.
     */
    @Transactional
    public SyncResult push(UUID tenantId, SyncPushRequest req) {
        List<SyncResult.Entry> out = new ArrayList<>();

        if (req.products() != null) {
            for (ProductDto p : req.products()) {
                try {
                    ProductDto saved = productService.upsert(tenantId, p);
                    out.add(SyncResult.Entry.ok("product", saved.id().toString(), saved.version()));
                } catch (ApiException ex) {
                    out.add(SyncResult.Entry.reject("product", p.id().toString(), ex.getCode()));
                }
            }
        }
        if (req.sales() != null) {
            for (SaleDto s : req.sales()) {
                try {
                    SaleDto saved = salesService.record(tenantId, s);
                    out.add(SyncResult.Entry.ok("sale", saved.id().toString(), 1L));
                } catch (ApiException ex) {
                    out.add(SyncResult.Entry.reject("sale", s.id().toString(), ex.getCode()));
                }
            }
        }
        return new SyncResult(out, Instant.now());
    }

    /**
     * Return all rows updated after `since`. Paging is omitted here for
     * brevity — a duka will have a handful of products and tens of sales
     * per day, well under one response budget.
     */
    @Transactional(readOnly = true)
    public SyncPullResponse pull(UUID tenantId, SyncPullRequest req) {
        Instant since = req.since() != null ? req.since() : Instant.EPOCH;

        List<ProductDto> products = productRepo
                .findByTenantIdAndUpdatedAtAfter(tenantId, since).stream()
                .map(ProductDto::from).toList();

        List<Sale> sales = saleRepo.findByTenantIdAndUpdatedAtAfter(tenantId, since);
        List<UUID> saleIds = sales.stream().map(Sale::getId).toList();
        Map<UUID, List<SaleItemDto>> itemsBySale = saleIds.isEmpty()
                ? Map.of()
                : itemRepo.findBySaleIdIn(saleIds).stream()
                    .collect(Collectors.groupingBy(
                        com.tillpro.api.domain.SaleItem::getSaleId,
                        Collectors.mapping(SaleItemDto::from, Collectors.toList())));

        List<SaleDto> saleDtos = sales.stream()
                .map(s -> SaleDto.from(s, itemsBySale.getOrDefault(s.getId(), List.of())))
                .toList();

        Subscription sub = tier.current();
        Map<String, Object> subPayload = Map.of(
                "tier", sub.getTier().name(),
                "status", sub.getStatus().name(),
                "currentPeriodEnd", sub.getCurrentPeriodEnd().toString()
        );

        return new SyncPullResponse(products, saleDtos, subPayload, Instant.now());
    }
}
