package com.tillpro.api.repo;

import com.tillpro.api.domain.Invoice;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface InvoiceRepository extends JpaRepository<Invoice, UUID> {
    Optional<Invoice> findByIdAndTenantId(UUID id, UUID tenantId);
    List<Invoice> findByTenantIdOrderByClientCreatedAtDesc(UUID tenantId);
    List<Invoice> findByTenantIdAndUpdatedAtAfter(UUID tenantId, Instant since);
    List<Invoice> findByTenantIdAndStatus(UUID tenantId, String status);
    List<Invoice> findByTenantIdAndDueDateBeforeAndStatusIn(
            UUID tenantId, LocalDate before, List<String> statuses);
    List<Invoice> findByTenantIdAndCustomerIdOrderByIssueDateDesc(UUID tenantId, UUID customerId);
}
