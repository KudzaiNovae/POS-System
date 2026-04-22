package com.tillpro.api.customers;

import com.tillpro.api.customers.dto.CustomerDto;
import com.tillpro.api.domain.Customer;
import com.tillpro.api.repo.CustomerRepository;
import com.tillpro.api.web.ApiException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class CustomerService {

    private final CustomerRepository customers;

    public CustomerService(CustomerRepository customers) {
        this.customers = customers;
    }

    @Transactional(readOnly = true)
    public List<CustomerDto> list(UUID tenantId) {
        return customers.findByTenantId(tenantId).stream()
                .map(CustomerDto::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public CustomerDto get(UUID tenantId, UUID id) {
        Customer c = customers.findByIdAndTenantId(id, tenantId)
                .orElseThrow(() -> ApiException.notFound("Customer not found."));
        return CustomerDto.from(c);
    }

    @Transactional
    public CustomerDto upsert(UUID tenantId, CustomerDto dto) {
        Customer c = customers.findByIdAndTenantId(dto.id(), tenantId).orElse(null);
        if (c == null) {
            c = Customer.builder()
                    .id(dto.id())
                    .tenantId(tenantId)
                    .balanceCents(dto.balanceCents() != null ? dto.balanceCents() : 0L)
                    .build();
        }
        c.setName(dto.name());
        c.setPhone(dto.phone());
        c.setEmail(dto.email());
        c.setTin(dto.tin());
        if (dto.balanceCents() != null) c.setBalanceCents(dto.balanceCents());
        return CustomerDto.from(customers.save(c));
    }

    @Transactional
    public void delete(UUID tenantId, UUID id) {
        Customer c = customers.findByIdAndTenantId(id, tenantId)
                .orElseThrow(() -> ApiException.notFound("Customer not found."));
        customers.delete(c);
    }
}
