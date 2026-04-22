package com.tillpro.api.repo;

import com.tillpro.api.domain.ZReport;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ZReportRepository extends JpaRepository<ZReport, UUID> {
    Optional<ZReport> findByTenantIdAndBusinessDate(UUID tenantId, LocalDate d);
    List<ZReport> findTop30ByTenantIdOrderByBusinessDateDesc(UUID tenantId);
}
