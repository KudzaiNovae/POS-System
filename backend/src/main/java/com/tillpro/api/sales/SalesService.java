package com.tillpro.api.sales;

import com.tillpro.api.domain.*;
import com.tillpro.api.fiscal.FiscalService;
import com.tillpro.api.repo.*;
import com.tillpro.api.sales.dto.SaleDto;
import com.tillpro.api.sales.dto.SaleItemDto;
import com.tillpro.api.subscriptions.TierPolicy;
import com.tillpro.api.web.ApiException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
public class SalesService {

    private final SaleRepository sales;
    private final SaleItemRepository items;
    private final ProductRepository products;
    private final StockMovementRepository moves;
    private final TierPolicy tier;
    private final FiscalService fiscal;

    public SalesService(SaleRepository sales, SaleItemRepository items,
                        ProductRepository products, StockMovementRepository moves,
                        TierPolicy tier, FiscalService fiscal) {
        this.sales = sales;
        this.items = items;
        this.products = products;
        this.moves = moves;
        this.tier = tier;
        this.fiscal = fiscal;
    }

    @Transactional
    public SaleDto record(UUID tenantId, SaleDto dto) {
        tier.assertCanWrite();

        Sale existing = sales.findById(dto.id()).orElse(null);
        if (existing != null) {
            if (!existing.getTenantId().equals(tenantId)) {
                throw ApiException.forbidden("Cross-tenant sale id.");
            }
            return hydrate(existing);
        }

        Sale sale = Sale.builder()
                .id(dto.id())
                .tenantId(tenantId)
                .cashierId(dto.cashierId())
                .customerId(dto.customerId())
                .totalCents(dto.totalCents())
                .taxCents(dto.taxCents() != null ? dto.taxCents() : 0L)
                .paymentMethod(dto.paymentMethod())
                .paymentRef(dto.paymentRef())
                .status(dto.status() != null ? dto.status() : "COMPLETED")
                .customerName(dto.customerName())
                .customerTin(dto.customerTin())
                .clientCreatedAt(dto.clientCreatedAt())
                .build();
        sales.save(sale);

        List<SaleItem> lineEntities = new ArrayList<>();
        for (SaleItemDto i : dto.items()) {
            SaleItem si = SaleItem.builder()
                    .id(i.id())
                    .saleId(sale.getId())
                    .productId(i.productId())
                    .tenantId(tenantId)
                    .nameSnapshot(i.nameSnapshot())
                    .qty(i.qty())
                    .unitPriceCents(i.unitPriceCents())
                    .lineTotalCents(i.lineTotalCents())
                    .vatClass(i.vatClass() != null ? i.vatClass() : "STANDARD")
                    .build();
            lineEntities.add(si);

            // Decrement stock (allow negative — a duka may oversell by design)
            Product p = products.findByIdAndTenantId(i.productId(), tenantId).orElse(null);
            if (p != null) {
                p.setStockQty(p.getStockQty().subtract(i.qty()));
                products.save(p);
                moves.save(StockMovement.builder()
                        .tenantId(tenantId).productId(p.getId())
                        .qtyDelta(i.qty().negate())
                        .reason("SALE").refId(sale.getId())
                        .build());
            }
        }

        // Fiscalise: compute VAT, assign receipt no, build QR, enqueue FDMS
        fiscal.fiscalise(sale, lineEntities);

        // Persist lines AFTER fiscal has populated net/vat
        for (SaleItem li : lineEntities) items.save(li);
        sales.save(sale);

        return hydrate(sale);
    }

    @Transactional
    public void voidSale(UUID tenantId, UUID saleId) {
        Sale sale = sales.findById(saleId)
                .filter(s -> s.getTenantId().equals(tenantId))
                .orElseThrow(() -> ApiException.notFound("Sale not found."));
        if ("VOIDED".equals(sale.getStatus())) return;
        sale.setStatus("VOIDED");
        sales.save(sale);

        for (SaleItem i : items.findBySaleId(saleId)) {
            products.findByIdAndTenantId(i.getProductId(), tenantId).ifPresent(p -> {
                p.setStockQty(p.getStockQty().add(i.getQty()));
                products.save(p);
                moves.save(StockMovement.builder()
                        .tenantId(tenantId).productId(p.getId())
                        .qtyDelta(i.getQty())
                        .reason("VOID").refId(sale.getId())
                        .build());
            });
        }
    }

    @Transactional(readOnly = true)
    public List<SaleDto> between(UUID tenantId, Instant from, Instant to) {
        return sales.findByTenantIdAndClientCreatedAtBetween(tenantId, from, to)
                .stream().map(this::hydrate).toList();
    }

    @Transactional(readOnly = true)
    public SaleDto get(UUID tenantId, UUID saleId) {
        Sale s = sales.findById(saleId)
                .filter(x -> x.getTenantId().equals(tenantId))
                .orElseThrow(() -> ApiException.notFound("Sale not found."));
        return hydrate(s);
    }

    private SaleDto hydrate(Sale sale) {
        List<SaleItemDto> dtos = items.findBySaleId(sale.getId()).stream()
                .map(SaleItemDto::from)
                .toList();
        return SaleDto.from(sale, dtos);
    }
}
