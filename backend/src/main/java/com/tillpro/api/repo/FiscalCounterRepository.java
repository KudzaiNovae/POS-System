package com.tillpro.api.repo;

import com.tillpro.api.domain.FiscalCounter;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;

import java.util.Optional;
import java.util.UUID;

public interface FiscalCounterRepository extends JpaRepository<FiscalCounter, UUID> {
    /** Row-level pessimistic lock so two concurrent sales never share a number. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<FiscalCounter> findByTenantId(UUID tenantId);
}
