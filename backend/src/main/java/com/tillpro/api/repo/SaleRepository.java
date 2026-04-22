package com.tillpro.api.repo;

import com.tillpro.api.domain.Sale;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public interface SaleRepository extends JpaRepository<Sale, UUID> {
    List<Sale> findByTenantIdAndUpdatedAtAfter(UUID tenantId, Instant since);

    List<Sale> findByTenantIdAndClientCreatedAtBetween(UUID tenantId, Instant from, Instant to);

    @Query("""
           SELECT COUNT(s) FROM Sale s
            WHERE s.tenantId = :tenantId
              AND s.clientCreatedAt >= :since
           """)
    long countSince(@Param("tenantId") UUID tenantId, @Param("since") Instant since);

    @Query("""
           SELECT COALESCE(SUM(s.totalCents),0) FROM Sale s
            WHERE s.tenantId = :tenantId
              AND s.status = 'COMPLETED'
              AND s.clientCreatedAt BETWEEN :from AND :to
           """)
    long sumRevenueBetween(@Param("tenantId") UUID tenantId,
                           @Param("from") Instant from,
                           @Param("to") Instant to);
}
