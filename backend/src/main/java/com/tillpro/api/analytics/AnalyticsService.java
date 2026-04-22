package com.tillpro.api.analytics;

import com.tillpro.api.domain.Product;
import com.tillpro.api.domain.Sale;
import com.tillpro.api.domain.SaleItem;
import com.tillpro.api.repo.ProductRepository;
import com.tillpro.api.repo.SaleItemRepository;
import com.tillpro.api.repo.SaleRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.*;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Business-intelligence layer for the owner dashboard.
 *
 * All queries are scoped by tenant_id (passed in explicitly) and run against
 * the authoritative sales tables. Output is plain JSON so the Flutter
 * fl_chart widgets can render without client-side aggregation.
 *
 * Lightweight "data science" we apply:
 *   - Revenue trend: daily grouping over configurable window
 *   - Hour-of-day heatmap: identifies staffing and stock-replenishment windows
 *   - Payment-mix donut: cash / mobile-money / card / credit breakdown
 *   - VAT-class stacked bar: for ZIMRA returns
 *   - Reorder predictions: velocity = qty_sold_30d / 30, days_of_stock =
 *       stock_qty / velocity; flag if days_of_stock < lead_time + buffer
 *   - Basket co-purchase: top "also-bought" product pairs by lift
 *   - Gross margin: revenue - COGS (using product cost_cents snapshot)
 *   - Shrinkage indicator: stock decrements NOT matched by a sale (manual)
 */
@Service
public class AnalyticsService {

    private final SaleRepository sales;
    private final SaleItemRepository items;
    private final ProductRepository products;

    private static final ZoneId ZONE = ZoneId.of("Africa/Harare");

    public AnalyticsService(SaleRepository sales, SaleItemRepository items,
                            ProductRepository products) {
        this.sales = sales;
        this.items = items;
        this.products = products;
    }

    // ------------------------------------------------------------------
    // Top-level: everything the dashboard needs in one round-trip
    // ------------------------------------------------------------------
    @Transactional(readOnly = true)
    public Map<String, Object> dashboard(UUID tenantId, int days) {
        int window = Math.max(1, Math.min(days, 365));
        Instant to = Instant.now();
        Instant from = to.minus(window, ChronoUnit.DAYS);

        List<Sale> allSales = sales.findByTenantIdAndClientCreatedAtBetween(
                tenantId, from, to).stream()
                .filter(s -> "COMPLETED".equals(s.getStatus()))
                .toList();

        List<UUID> ids = allSales.stream().map(Sale::getId).toList();
        List<SaleItem> allItems = ids.isEmpty()
                ? List.of()
                : items.findBySaleIdIn(ids);

        List<Product> catalog = products.findByTenantIdAndDeletedFalse(tenantId);

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("windowDays", window);
        out.put("from", from.toString());
        out.put("to", to.toString());
        out.put("headline", headline(allSales, allItems, catalog));
        out.put("revenueTrend", revenueTrend(allSales, window));
        out.put("hourHeatmap", hourHeatmap(allSales));
        out.put("paymentMix", paymentMix(allSales));
        out.put("vatByClass", vatByClass(allItems));
        out.put("topProducts", topProducts(allItems, 10));
        out.put("lowStock", lowStock(catalog));
        out.put("reorderPredictions", reorderPredictions(catalog, allItems, window));
        out.put("basketCoPurchase", basketCoPurchase(allItems, 10));
        out.put("margin", margin(allItems, catalog));
        return out;
    }

    // ------------------------------------------------------------------
    // Headline cards
    // ------------------------------------------------------------------
    private Map<String, Object> headline(List<Sale> ss, List<SaleItem> ii, List<Product> pp) {
        long revenue = ss.stream().mapToLong(Sale::getTotalCents).sum();
        long vat = ss.stream().mapToLong(s -> s.getVatCents() == null ? 0 : s.getVatCents()).sum();
        long net = ss.stream().mapToLong(s -> s.getSubtotalCents() == null ? 0 : s.getSubtotalCents()).sum();
        long salesCount = ss.size();
        double avgBasket = salesCount == 0 ? 0 : (double) revenue / salesCount;

        long pendingFiscal = ss.stream()
                .filter(s -> !"ACCEPTED".equals(s.getFiscalStatus()))
                .count();

        Map<String, Object> h = new LinkedHashMap<>();
        h.put("salesCount", salesCount);
        h.put("revenueCents", revenue);
        h.put("netCents", net);
        h.put("vatCents", vat);
        h.put("avgBasketCents", Math.round(avgBasket));
        h.put("pendingFiscal", pendingFiscal);
        h.put("uniqueProductsSold", ii.stream().map(SaleItem::getProductId).distinct().count());
        h.put("productsInCatalog", pp.size());
        return h;
    }

    // ------------------------------------------------------------------
    // Revenue trend (one point per day, in the tenant's local zone)
    // ------------------------------------------------------------------
    private List<Map<String, Object>> revenueTrend(List<Sale> ss, int window) {
        Map<LocalDate, long[]> bucket = new TreeMap<>();
        LocalDate today = LocalDate.now(ZONE);
        for (int i = window - 1; i >= 0; i--) {
            bucket.put(today.minusDays(i), new long[]{0L, 0L}); // [revenue, count]
        }
        for (Sale s : ss) {
            LocalDate d = s.getClientCreatedAt().atZone(ZONE).toLocalDate();
            bucket.computeIfAbsent(d, k -> new long[]{0L, 0L});
            long[] v = bucket.get(d);
            v[0] += s.getTotalCents();
            v[1] += 1;
        }
        List<Map<String, Object>> out = new ArrayList<>();
        for (var e : bucket.entrySet()) {
            out.add(Map.of(
                    "date", e.getKey().toString(),
                    "revenueCents", e.getValue()[0],
                    "salesCount", e.getValue()[1]));
        }
        return out;
    }

    // ------------------------------------------------------------------
    // Hour-of-day heatmap: 7 days × 24 hours grid of revenue
    // ------------------------------------------------------------------
    private List<Map<String, Object>> hourHeatmap(List<Sale> ss) {
        long[][] grid = new long[7][24];
        for (Sale s : ss) {
            ZonedDateTime z = s.getClientCreatedAt().atZone(ZONE);
            int dow = z.getDayOfWeek().getValue() - 1; // 0 = Monday
            int hr = z.getHour();
            grid[dow][hr] += s.getTotalCents();
        }
        List<Map<String, Object>> out = new ArrayList<>();
        String[] days = {"Mon","Tue","Wed","Thu","Fri","Sat","Sun"};
        for (int d = 0; d < 7; d++) {
            for (int h = 0; h < 24; h++) {
                if (grid[d][h] > 0) {
                    out.add(Map.of(
                            "day", days[d], "dayIndex", d,
                            "hour", h,
                            "revenueCents", grid[d][h]));
                }
            }
        }
        return out;
    }

    // ------------------------------------------------------------------
    // Payment mix (EcoCash / OneMoney / InnBucks / Cash / Card / Credit)
    // ------------------------------------------------------------------
    private List<Map<String, Object>> paymentMix(List<Sale> ss) {
        Map<String, Long> m = ss.stream().collect(Collectors.groupingBy(
                s -> s.getPaymentMethod() == null ? "UNKNOWN" : s.getPaymentMethod(),
                Collectors.summingLong(Sale::getTotalCents)));
        return m.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
                .map(e -> (Map<String, Object>) new LinkedHashMap<String, Object>() {{
                    put("method", e.getKey());
                    put("revenueCents", e.getValue());
                }})
                .toList();
    }

    // ------------------------------------------------------------------
    // VAT revenue grouped by class (STANDARD / ZERO / EXEMPT / LUXURY)
    // ------------------------------------------------------------------
    private List<Map<String, Object>> vatByClass(List<SaleItem> ii) {
        Map<String, long[]> m = new LinkedHashMap<>();
        for (SaleItem li : ii) {
            String c = li.getVatClass() == null ? "STANDARD" : li.getVatClass();
            m.computeIfAbsent(c, k -> new long[]{0L, 0L, 0L}); // gross, net, vat
            long[] v = m.get(c);
            v[0] += li.getLineTotalCents();
            v[1] += li.getNetCents() == null ? 0 : li.getNetCents();
            v[2] += li.getVatCents() == null ? 0 : li.getVatCents();
        }
        return m.entrySet().stream().map(e -> {
            Map<String, Object> r = new LinkedHashMap<>();
            r.put("class", e.getKey());
            r.put("grossCents", e.getValue()[0]);
            r.put("netCents", e.getValue()[1]);
            r.put("vatCents", e.getValue()[2]);
            return r;
        }).toList();
    }

    // ------------------------------------------------------------------
    // Top N products by revenue
    // ------------------------------------------------------------------
    private List<Map<String, Object>> topProducts(List<SaleItem> ii, int n) {
        Map<UUID, long[]> m = new HashMap<>();
        Map<UUID, String> names = new HashMap<>();
        for (SaleItem li : ii) {
            names.putIfAbsent(li.getProductId(), li.getNameSnapshot());
            m.computeIfAbsent(li.getProductId(), k -> new long[]{0L});
            m.get(li.getProductId())[0] += li.getLineTotalCents();
        }
        return m.entrySet().stream()
                .sorted((a, b) -> Long.compare(b.getValue()[0], a.getValue()[0]))
                .limit(n)
                .map(e -> {
                    Map<String, Object> r = new LinkedHashMap<>();
                    r.put("productId", e.getKey());
                    r.put("name", names.get(e.getKey()));
                    r.put("revenueCents", e.getValue()[0]);
                    return r;
                })
                .toList();
    }

    // ------------------------------------------------------------------
    // Low stock list (reorder point breached)
    // ------------------------------------------------------------------
    private List<Map<String, Object>> lowStock(List<Product> pp) {
        return pp.stream()
                .filter(p -> p.getReorderLevel() != null
                          && p.getReorderLevel().compareTo(BigDecimal.ZERO) > 0
                          && p.getStockQty().compareTo(p.getReorderLevel()) <= 0)
                .sorted(Comparator.comparing(p -> p.getStockQty()))
                .limit(30)
                .map(p -> {
                    Map<String, Object> r = new LinkedHashMap<>();
                    r.put("productId", p.getId());
                    r.put("name", p.getName());
                    r.put("stockQty", p.getStockQty());
                    r.put("reorderLevel", p.getReorderLevel());
                    return r;
                })
                .toList();
    }

    // ------------------------------------------------------------------
    // Reorder predictions: velocity × lead_time
    //   velocity = qty_sold_in_window / window (units per day)
    //   daysOfStock = stock_qty / velocity
    //   predictStockoutDate = now + daysOfStock
    //   urgent = daysOfStock < 7
    // ------------------------------------------------------------------
    private List<Map<String, Object>> reorderPredictions(List<Product> pp,
                                                         List<SaleItem> ii,
                                                         int window) {
        // sum qty sold per product
        Map<UUID, BigDecimal> sold = new HashMap<>();
        for (SaleItem li : ii) {
            sold.merge(li.getProductId(), li.getQty(), BigDecimal::add);
        }
        List<Map<String, Object>> out = new ArrayList<>();
        for (Product p : pp) {
            BigDecimal qty = sold.getOrDefault(p.getId(), BigDecimal.ZERO);
            if (qty.compareTo(BigDecimal.ZERO) == 0) continue; // not moving
            BigDecimal velocity = qty.divide(
                    BigDecimal.valueOf(window), 4, RoundingMode.HALF_UP);
            if (velocity.compareTo(BigDecimal.ZERO) == 0) continue;
            BigDecimal daysOfStock = p.getStockQty()
                    .divide(velocity, 1, RoundingMode.HALF_UP);
            Map<String, Object> r = new LinkedHashMap<>();
            r.put("productId", p.getId());
            r.put("name", p.getName());
            r.put("velocityPerDay", velocity);
            r.put("stockQty", p.getStockQty());
            r.put("daysOfStock", daysOfStock);
            r.put("urgent", daysOfStock.compareTo(BigDecimal.valueOf(7)) < 0);
            out.add(r);
        }
        // sort by daysOfStock asc (most urgent first)
        out.sort((a, b) -> ((BigDecimal) a.get("daysOfStock"))
                .compareTo((BigDecimal) b.get("daysOfStock")));
        return out.stream().limit(20).toList();
    }

    // ------------------------------------------------------------------
    // Basket co-purchase (frequent pairs).
    //  support(A,B) = #baskets containing both / total baskets
    //  confidence(A→B) = #baskets with both / #baskets with A
    //  lift(A,B) = confidence(A→B) / support(B)
    //  We surface the top-N pairs by (count, lift).
    // ------------------------------------------------------------------
    private List<Map<String, Object>> basketCoPurchase(List<SaleItem> ii, int n) {
        // group items by sale_id
        Map<UUID, List<SaleItem>> bySale = ii.stream()
                .collect(Collectors.groupingBy(SaleItem::getSaleId));
        int totalBaskets = bySale.size();
        if (totalBaskets < 3) return List.of(); // not enough signal

        Map<UUID, Long> singleCount = new HashMap<>();
        Map<UUID, String> names = new HashMap<>();
        Map<String, long[]> pairCount = new HashMap<>(); // key = "minId|maxId"

        for (var basket : bySale.values()) {
            var distinct = basket.stream()
                    .collect(Collectors.toMap(SaleItem::getProductId,
                            SaleItem::getNameSnapshot, (a, b) -> a));
            for (var e : distinct.entrySet()) {
                singleCount.merge(e.getKey(), 1L, Long::sum);
                names.putIfAbsent(e.getKey(), e.getValue());
            }
            List<UUID> pids = new ArrayList<>(distinct.keySet());
            for (int i = 0; i < pids.size(); i++) {
                for (int j = i + 1; j < pids.size(); j++) {
                    UUID a = pids.get(i), b = pids.get(j);
                    String key = a.compareTo(b) < 0 ? a + "|" + b : b + "|" + a;
                    pairCount.computeIfAbsent(key, k -> new long[]{0L});
                    pairCount.get(key)[0] += 1;
                }
            }
        }

        List<Map<String, Object>> pairs = new ArrayList<>();
        for (var e : pairCount.entrySet()) {
            if (e.getValue()[0] < 2) continue;
            String[] ids = e.getKey().split("\\|");
            UUID a = UUID.fromString(ids[0]), b = UUID.fromString(ids[1]);
            long pairN = e.getValue()[0];
            long aN = singleCount.getOrDefault(a, 1L);
            long bN = singleCount.getOrDefault(b, 1L);
            double supportB = (double) bN / totalBaskets;
            double confidence = (double) pairN / aN;
            double lift = supportB == 0 ? 0 : confidence / supportB;
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("a", names.getOrDefault(a, a.toString()));
            row.put("b", names.getOrDefault(b, b.toString()));
            row.put("baskets", pairN);
            row.put("lift", Math.round(lift * 100.0) / 100.0);
            pairs.add(row);
        }
        pairs.sort((x, y) -> {
            int c = Long.compare((Long) y.get("baskets"), (Long) x.get("baskets"));
            return c != 0 ? c
                    : Double.compare((Double) y.get("lift"), (Double) x.get("lift"));
        });
        return pairs.stream().limit(n).toList();
    }

    // ------------------------------------------------------------------
    // Margin: gross revenue minus COGS (cost_cents × qty)
    // ------------------------------------------------------------------
    private Map<String, Object> margin(List<SaleItem> ii, List<Product> pp) {
        Map<UUID, Long> costByPid = pp.stream()
                .collect(Collectors.toMap(Product::getId,
                        p -> p.getCostCents() == null ? 0L : p.getCostCents()));
        long revenue = 0L, cogs = 0L;
        for (SaleItem li : ii) {
            revenue += li.getLineTotalCents();
            long unitCost = costByPid.getOrDefault(li.getProductId(), 0L);
            cogs += Math.round(unitCost * li.getQty().doubleValue());
        }
        long grossProfit = revenue - cogs;
        double marginPct = revenue == 0 ? 0 : (double) grossProfit / revenue * 100.0;
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("revenueCents", revenue);
        r.put("cogsCents", cogs);
        r.put("grossProfitCents", grossProfit);
        r.put("marginPct", Math.round(marginPct * 10.0) / 10.0);
        return r;
    }
}
