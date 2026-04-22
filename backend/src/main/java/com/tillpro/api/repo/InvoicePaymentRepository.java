package com.tillpro.api.repo;

import com.tillpro.api.domain.InvoicePayment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface InvoicePaymentRepository extends JpaRepository<InvoicePayment, UUID> {
    List<InvoicePayment> findByInvoiceIdOrderByPaidAtDesc(UUID invoiceId);
}
