package com.tillpro.api.repo;

import com.tillpro.api.domain.Product;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ProductRepository extends JpaRepository<Product, UUID> {
    List<Product> findByTenantIdAndUpdatedAtAfter(UUID tenantId, Instant since);
    List<Product> findByTenantIdAndDeletedFalse(UUID tenantId);
    Optional<Product> findByIdAndTenantId(UUID id, UUID tenantId);
    long countByTenantIdAndDeletedFalse(UUID tenantId);
}
