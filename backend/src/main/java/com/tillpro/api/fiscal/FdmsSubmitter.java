package com.tillpro.api.fiscal;

import com.tillpro.api.domain.FdmsSubmission;
import com.tillpro.api.domain.Sale;
import com.tillpro.api.repo.FdmsSubmissionRepository;
import com.tillpro.api.repo.SaleRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

/**
 * Background poller that drains the FDMS submission queue and calls ZIMRA.
 *
 * The real FDMS integration requires:
 *   - a device certificate issued by ZIMRA on fiscalisation
 *   - JWS-signing each payload with the device key
 *   - posting to the FDMS receive-invoice endpoint
 *   - storing the returned verification reference on the sale
 *
 * For the MVP scaffold we stub the transport: a successful "dry run" marks
 * the submission ACCEPTED so the rest of the system behaves correctly
 * end-to-end. A real deployment replaces `fdmsCall(...)` with HTTP + signing.
 */
@Component
@EnableScheduling
public class FdmsSubmitter {

    private final FdmsSubmissionRepository submissions;
    private final SaleRepository sales;
    private final boolean stubMode;

    public FdmsSubmitter(FdmsSubmissionRepository submissions, SaleRepository sales,
                         @Value("${tillpro.fdms.stub:true}") boolean stubMode) {
        this.submissions = submissions;
        this.sales = sales;
        this.stubMode = stubMode;
    }

    @Scheduled(fixedDelay = 15_000) // every 15s
    @Transactional
    public void drain() {
        List<FdmsSubmission> batch = submissions
                .findTop100ByStatusAndNextAttemptAtBeforeOrderByNextAttemptAtAsc(
                        "PENDING", Instant.now());
        for (FdmsSubmission s : batch) {
            try {
                String verificationRef = fdmsCall(s.getPayloadJson());
                s.setStatus("ACCEPTED");
                Sale sale = sales.findById(s.getSaleId()).orElse(null);
                if (sale != null) {
                    sale.setFiscalStatus("ACCEPTED");
                    sale.setFiscalReference(verificationRef);
                    sales.save(sale);
                }
            } catch (Exception e) {
                s.setAttempts(s.getAttempts() + 1);
                s.setLastError(e.getClass().getSimpleName() + ": " + e.getMessage());
                if (s.getAttempts() >= 20) {
                    s.setStatus("DEAD_LETTER");
                } else {
                    // Exponential backoff up to 1h
                    long base = Math.min(3600L, (long) Math.pow(2, s.getAttempts()));
                    s.setNextAttemptAt(Instant.now().plus(Duration.ofSeconds(base)));
                }
            }
            submissions.save(s);
        }
    }

    /** Replace with real HTTP + JWS call when deploying to production. */
    private String fdmsCall(String payloadJson) {
        if (stubMode) {
            // Produce a deterministic-ish reference that a verifier could check.
            return "ZIMRA-" + Integer.toHexString(payloadJson.hashCode()).toUpperCase();
        }
        throw new UnsupportedOperationException(
            "Configure tillpro.fdms.* and enable production submitter.");
    }
}
