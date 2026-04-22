package com.tillpro.api.sync.dto;

import com.tillpro.api.products.dto.ProductDto;
import com.tillpro.api.sales.dto.SaleDto;

import java.util.List;
import java.util.UUID;

public record SyncPushRequest(
        UUID deviceId,
        List<ProductDto> products,
        List<SaleDto> sales
) {}
