package com.tillpro.api.repo;

import com.tillpro.api.domain.SaleItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public interface SaleItemRepository extends JpaRepository<SaleItem, UUID> {
    List<SaleItem> findBySaleId(UUID saleId);
    List<SaleItem> findBySaleIdIn(List<UUID> saleIds);

    @Query("""
           SELECT i.productId AS productId, i.nameSnapshot AS name,
                  SUM(i.qty) AS qty, SUM(i.lineTotalCents) AS revenue
             FROM SaleItem i, Sale s
            WHERE i.saleId = s.id
              AND i.tenantId = :tenantId
              AND s.status = 'COMPLETED'
              AND s.clientCreatedAt BETWEEN :from AND :to
            GROUP BY i.productId, i.nameSnapshot
            ORDER BY SUM(i.lineTotalCents) DESC
           """)
    List<TopProductRow> topProducts(@Param("tenantId") UUID tenantId,
                                    @Param("from") Instant from,
                                    @Param("to") Instant to);

    interface TopProductRow {
        UUID getProductId();
        String getName();
        java.math.BigDecimal getQty();
        Long getRevenue();
    }
}
