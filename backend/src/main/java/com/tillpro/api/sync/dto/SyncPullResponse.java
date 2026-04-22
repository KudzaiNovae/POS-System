package com.tillpro.api.sync.dto;

import com.tillpro.api.products.dto.ProductDto;
import com.tillpro.api.sales.dto.SaleDto;

import java.time.Instant;
import java.util.List;
import java.util.Map;

public record SyncPullResponse(
        List<ProductDto> products,
        List<SaleDto> sales,
        Map<String, Object> subscription,
        Instant serverNow
) {}
