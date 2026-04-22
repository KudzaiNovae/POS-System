package com.tillpro.api.repo;

import com.tillpro.api.domain.InvoiceCounter;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;

import java.util.Optional;
import java.util.UUID;

public interface InvoiceCounterRepository
        extends JpaRepository<InvoiceCounter, InvoiceCounter.Key> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<InvoiceCounter> findByTenantIdAndYearAndKind(
            UUID tenantId, Integer year, String kind);
}
