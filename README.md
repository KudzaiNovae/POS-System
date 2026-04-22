# TillPro

Offline-first POS, invoicing, and analytics SaaS built for Zimbabwean SMEs (with first-class support across Southern and East Africa). Sells in dollars, declares in ZWG, fiscalises through ZIMRA.

```
inventoryapp/
├── backend/   — Spring Boot 3 + PostgreSQL 16 + Flyway (multi-tenant)
├── mobile/    — Flutter 3 client (Android/iOS/desktop), Hive cache, Riverpod
├── docker-compose.yml
└── .github/workflows/ci.yml
```

## What's in the box

**Point of sale.** Barcode scan, weighed items, multiple tenders per basket (Cash · Card · EcoCash · OneMoney · InnBucks · ZIPIT · Credit), 80 mm thermal receipt printing.

**Invoicing.** Drafts, sent invoices, partial / full payments, credit notes, quotes & proformas, A4 PDF export and share, fiscal numbering when issued.

**Inventory.** Catalog with VAT class, cost & sale price, reorder level, low-stock alerts, multi-currency price snapshots.

**Customers.** Address book, captured TINs for VAT invoices, outstanding balance ledger.

**ZIMRA fiscalisation.** Each completed sale is queued to FDMS, retried with exponential backoff, and audited from the in-app fiscal queue. Daily Z-Reports lock the till and feed VAT returns.

**Insights.** Server-driven dashboard: revenue trend, payment mix, VAT-by-class, top products, low stock, hour-of-day heatmap, gross margin. PRO/BUSINESS unlocks reorder predictions and basket co-purchase analysis.

**Subscriptions.** FREE / STARTER / PRO / BUSINESS tiers with mobile-money checkout (EcoCash / OneMoney / InnBucks / Card). Tier policy is enforced both server-side (`TierPolicy`) and client-side (`feature_gate.dart`).

**Offline-first.** Every write goes through Hive. A Riverpod-backed `SyncService` drains an outbox over `connectivity_plus` events with exponential backoff + jitter; pulls happen on a 30 s timer and on reconnect. Last-write-wins by version, dirty rows never overwritten by a pull.

## Quick start

### Prerequisites
- Docker 24+ and Docker Compose v2
- Flutter 3.41+ (for the mobile app)

### Backend + database
```bash
docker compose up --build
# API:    http://localhost:8080
# Health: http://localhost:8080/actuator/health
```

Override defaults via a `.env` file beside `docker-compose.yml`:
```env
POSTGRES_PASSWORD=changeme
JWT_SECRET=please-rotate-this-for-production
```

### Mobile
```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE=http://10.0.2.2:8080   # Android emulator → host
```

## Development workflow

| Task | Command |
|---|---|
| Backend unit + integration tests | `cd backend && ./mvnw verify` |
| Backend hot reload | `cd backend && ./mvnw spring-boot:run` |
| Flutter analyze | `cd mobile && flutter analyze` |
| Flutter tests | `cd mobile && flutter test` |
| Generate APK | `cd mobile && flutter build apk --release` |

CI mirrors all of the above on every push and pull request — see `.github/workflows/ci.yml`.

## Architecture

### Multi-tenant by design
Every JPA entity carries a `tenant_id`. `TenantContext` is hydrated from the JWT on each request, and the persistence layer rejects cross-tenant reads. Subscriptions, FDMS submissions, Z-Reports and analytics are all tenant-scoped.

### Offline-first contract
1. UI mutates Hive optimistically and marks the row `dirty: true`.
2. The mutation is queued in the `outbox` box.
3. `SyncService` drains the outbox in batches (`/sync/push` for products & sales, `/invoices` per-row for richer state).
4. Pulls (`/sync/pull`) merge by version; dirty local rows are never overwritten.

### Invoicing pipeline
- `InvoiceController` upserts → `InvoiceService` recomputes totals and persists customer.
- A separate `/invoices/{id}/issue` POST assigns a fiscal number when the draft transitions out of `DRAFT`.
- `creditNote`, `convert` (quote → invoice), and `sweepOverdue` are server-side helpers exposed in the mobile UI.

### ZIMRA / FDMS
- `SalesService` enqueues fiscalisation on every completed sale.
- A `FdmsSubmitter` poller submits and retries with exponential backoff.
- The mobile fiscal queue screen is the audit surface for owners/managers.

## Project documents

- `PRODUCT.md` — product brief
- `ARCHITECTURE.md` — system architecture deep-dive
- `API.md` — REST API reference
- `INTEGRATION_SUMMARY.md` — frontend ↔ backend integration notes

## License

Proprietary. © TillPro.
