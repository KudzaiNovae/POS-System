package com.tillpro.api.repo;

import com.tillpro.api.domain.FdmsSubmission;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public interface FdmsSubmissionRepository extends JpaRepository<FdmsSubmission, UUID> {
    List<FdmsSubmission> findTop100ByStatusAndNextAttemptAtBeforeOrderByNextAttemptAtAsc(
            String status, Instant before);
    List<FdmsSubmission> findByTenantIdOrderByCreatedAtDesc(UUID tenantId);
}
