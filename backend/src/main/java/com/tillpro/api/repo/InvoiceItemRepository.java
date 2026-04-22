package com.tillpro.api.repo;

import com.tillpro.api.domain.InvoiceItem;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

public interface InvoiceItemRepository extends JpaRepository<InvoiceItem, UUID> {
    List<InvoiceItem> findByInvoiceId(UUID invoiceId);
    List<InvoiceItem> findByInvoiceIdIn(List<UUID> invoiceIds);

    @Transactional
    void deleteByInvoiceId(UUID invoiceId);
}
