import 'package:hive_flutter/hive_flutter.dart';

import '../../models/customer.dart';
import '../../models/invoice.dart';
import '../../models/product.dart';
import '../../models/sale.dart';

class LocalDb {
  static const products = 'products';
  static const sales = 'sales';
  static const saleItems = 'sale_items';
  static const invoices = 'invoices';
  static const customers = 'customers';
  static const outbox = 'outbox';
  static const meta = 'meta';

  static Future<void> openAll() async {
    // Registering typed boxes would require Hive adapters — for brevity we
    // store Maps and rehydrate through model fromMap/toMap.
    await Hive.openBox<Map>(products);
    await Hive.openBox<Map>(sales);
    await Hive.openBox<Map>(saleItems);
    await Hive.openBox<Map>(invoices);
    await Hive.openBox<Map>(customers);
    await Hive.openBox<Map>(outbox);
    await Hive.openBox(meta);
  }

  static Box<Map> get productsBox => Hive.box<Map>(products);
  static Box<Map> get salesBox => Hive.box<Map>(sales);
  static Box<Map> get saleItemsBox => Hive.box<Map>(saleItems);
  static Box<Map> get invoicesBox => Hive.box<Map>(invoices);
  static Box<Map> get customersBox => Hive.box<Map>(customers);
  static Box<Map> get outboxBox => Hive.box<Map>(outbox);
  static Box get metaBox => Hive.box(meta);

  // ---- meta helpers ----
  static String? get authToken => metaBox.get('authToken');
  static set authToken(String? v) => metaBox.put('authToken', v);

  static String? get refreshToken => metaBox.get('refreshToken');
  static set refreshToken(String? v) => metaBox.put('refreshToken', v);

  static String? get tenantId => metaBox.get('tenantId');
  static set tenantId(String? v) => metaBox.put('tenantId', v);

  static String get tier => metaBox.get('tier', defaultValue: 'FREE');
  static set tier(String v) => metaBox.put('tier', v);

  static String? get deviceId => metaBox.get('deviceId');
  static set deviceId(String? v) => metaBox.put('deviceId', v);

  // Shop profile (captured at registration, echoed in settings).
  static String? get shopName => metaBox.get('shopName');
  static set shopName(String? v) => metaBox.put('shopName', v);

  static String? get shopAddress => metaBox.get('shopAddress');
  static set shopAddress(String? v) => metaBox.put('shopAddress', v);

  static String? get shopPhone => metaBox.get('shopPhone');
  static set shopPhone(String? v) => metaBox.put('shopPhone', v);

  // ZIMRA registration: TIN + VAT number go on every receipt.
  static String? get tin => metaBox.get('tin');
  static set tin(String? v) => metaBox.put('tin', v);

  static String? get vatNumber => metaBox.get('vatNumber');
  static set vatNumber(String? v) => metaBox.put('vatNumber', v);

  static String? get fiscalDeviceId => metaBox.get('fiscalDeviceId');
  static set fiscalDeviceId(String? v) => metaBox.put('fiscalDeviceId', v);

  // Printer setup (Bluetooth MAC or USB path). Optional.
  static String? get printerTarget => metaBox.get('printerTarget');
  static set printerTarget(String? v) => metaBox.put('printerTarget', v);

  static String get countryCode =>
      metaBox.get('countryCode', defaultValue: 'ZW');
  static set countryCode(String v) => metaBox.put('countryCode', v);

  // USD is the sticky retail-pricing currency in Zimbabwe; ZWG is the local
  // legal tender (launched April 2024). Shops can switch in Settings.
  static String get currency =>
      metaBox.get('currency', defaultValue: 'USD');
  static set currency(String v) => metaBox.put('currency', v);

  static String? get ownerEmail => metaBox.get('ownerEmail');
  static set ownerEmail(String? v) => metaBox.put('ownerEmail', v);

  // UI locale ('en' | 'sw' | 'sn' | 'pcm' ...). Not yet wired to a full i18n
  // bundle — persisted so the settings picker survives restarts.
  static String get locale => metaBox.get('locale', defaultValue: 'en');
  static set locale(String v) => metaBox.put('locale', v);

  static DateTime get lastPullAt =>
      DateTime.tryParse(metaBox.get('lastPullAt', defaultValue: '1970-01-01T00:00:00Z'))!;
  static set lastPullAt(DateTime v) =>
      metaBox.put('lastPullAt', v.toUtc().toIso8601String());

  // ---- product helpers ----
  static List<Product> allProducts() => productsBox.values
      .map((m) => Product.fromMap(Map<String, dynamic>.from(m)))
      .where((p) => !p.deleted)
      .toList();

  static Future<void> putProduct(Product p) =>
      productsBox.put(p.id, p.toMap());

  static Product? findProduct(String id) {
    final m = productsBox.get(id);
    return m == null ? null : Product.fromMap(Map<String, dynamic>.from(m));
  }

  // ---- sales helpers ----
  static Future<void> putSale(Sale s) async {
    await salesBox.put(s.id, s.toMap());
    for (final i in s.items) {
      await saleItemsBox.put(i.id, i.toMap());
    }
  }

  static List<Sale> salesBetween(DateTime from, DateTime to) {
    return salesBox.values
        .map((m) => Sale.fromMap(Map<String, dynamic>.from(m)))
        .where((s) =>
            s.clientCreatedAt.isAfter(from) && s.clientCreatedAt.isBefore(to))
        .toList();
  }

  // ---- invoice helpers ----
  static Future<void> putInvoice(Invoice inv) =>
      invoicesBox.put(inv.id, inv.toMap());

  static Invoice? findInvoice(String id) {
    final m = invoicesBox.get(id);
    return m == null ? null : Invoice.fromMap(Map<String, dynamic>.from(m));
  }

  static List<Invoice> allInvoices() => invoicesBox.values
      .map((m) => Invoice.fromMap(Map<String, dynamic>.from(m)))
      .toList()
    ..sort((a, b) => b.clientCreatedAt.compareTo(a.clientCreatedAt));

  // ---- customer helpers ----
  static Future<void> putCustomer(Customer c) =>
      customersBox.put(c.id, c.toMap());

  static Customer? findCustomer(String id) {
    final m = customersBox.get(id);
    return m == null ? null : Customer.fromMap(Map<String, dynamic>.from(m));
  }

  static List<Customer> allCustomers() => customersBox.values
      .map((m) => Customer.fromMap(Map<String, dynamic>.from(m)))
      .toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  static Future<void> deleteCustomer(String id) => customersBox.delete(id);
}
