import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/invoice.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../api/api_client.dart';
import '../db/local_db.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final api = ref.watch(apiClientProvider);
  final svc = SyncService(api);
  svc.start();
  ref.onDispose(svc.stop);
  return svc;
});

/// The heart of the offline story.
///
/// Every local write goes through Hive first; then this service drains the
/// outbox in batches whenever connectivity is available. Pulls happen on a
/// timer and on reconnect. Failed pushes are retried with exponential
/// backoff + jitter, never blocking the UI.
class SyncService {
  SyncService(this._api);

  final ApiClient _api;
  Timer? _timer;
  StreamSubscription? _connSub;
  bool _running = false;
  int _backoffMs = 2000;
  static const int _maxBackoffMs = 5 * 60 * 1000;

  void start() {
    _connSub = Connectivity().onConnectivityChanged.listen((_) => syncNow());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => syncNow());
  }

  void stop() {
    _timer?.cancel();
    _connSub?.cancel();
  }

  // ---- enqueue helpers used by the UI ----
  Future<void> enqueueProduct(Product p) async {
    p.dirty = true;
    p.updatedAt = DateTime.now().toUtc();
    await LocalDb.putProduct(p);
    await LocalDb.outboxBox.put('product:${p.id}', {
      'entity': 'product',
      'id': p.id,
      'ts': DateTime.now().toUtc().toIso8601String(),
    });
    unawaited(syncNow());
  }

  Future<void> enqueueSale(Sale s) async {
    await LocalDb.putSale(s);
    await LocalDb.outboxBox.put('sale:${s.id}', {
      'entity': 'sale',
      'id': s.id,
      'ts': DateTime.now().toUtc().toIso8601String(),
    });
    unawaited(syncNow());
  }

  /// Queue an invoice for push. Invoices use a dedicated endpoint because
  /// their payload shape (line items + payments) doesn't fit the bulk
  /// /sync/push envelope — see [_pushInvoices].
  Future<void> enqueueInvoice(Invoice inv) async {
    inv.dirty = true;
    await LocalDb.putInvoice(inv);
    await LocalDb.outboxBox.put('invoice:${inv.id}', {
      'entity': 'invoice',
      'id': inv.id,
      'ts': DateTime.now().toUtc().toIso8601String(),
    });
    unawaited(syncNow());
  }

  /// Kick a sync cycle. Safe to call many times — only one runs at a time.
  Future<void> syncNow() async {
    if (_running) return;
    if (LocalDb.authToken == null) return;
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) return;
    _running = true;
    try {
      await _push();
      await _pushInvoices();
      await _pull();
      _backoffMs = 2000; // success: reset
    } on DioException {
      _backoffMs =
          min((_backoffMs * 2) + Random().nextInt(500), _maxBackoffMs);
      Future.delayed(Duration(milliseconds: _backoffMs), syncNow);
    } finally {
      _running = false;
    }
  }

  Future<void> _push() async {
    final entries = LocalDb.outboxBox.values.toList();
    if (entries.isEmpty) return;

    final productIds = <String>{};
    final saleIds = <String>{};
    for (final e in entries.take(200)) {
      final id = e['id'] as String;
      if (e['entity'] == 'product') productIds.add(id);
      if (e['entity'] == 'sale') saleIds.add(id);
    }

    final products = productIds
        .map((id) => LocalDb.findProduct(id))
        .whereType<Product>()
        .map((p) => p.toApiPayload())
        .toList();
    final sales = saleIds
        .map((id) => LocalDb.salesBox.get(id))
        .whereType<Map>()
        .map((m) => Sale.fromMap(Map<String, dynamic>.from(m)).toApiPayload())
        .toList();

    if (products.isEmpty && sales.isEmpty) return;

    final resp = await _api.post('/sync/push', data: {
      'deviceId': LocalDb.deviceId,
      'products': products,
      'sales': sales,
    });
    final results = (resp.data['results'] as List).cast<Map>();
    for (final r in results) {
      if (r['accepted'] == true) {
        final key = '${r['entity']}:${r['id']}';
        await LocalDb.outboxBox.delete(key);
        if (r['entity'] == 'product') {
          final p = LocalDb.findProduct(r['id']);
          if (p != null) {
            p.dirty = false;
            if (r['serverVersion'] is num) {
              p.version = (r['serverVersion'] as num).toInt();
            }
            await LocalDb.putProduct(p);
          }
        }
      }
      // Rejected entries stay in the outbox so the user can see and resolve them
      // (e.g. TIER_LIMIT_EXCEEDED — user must upgrade or remove product).
    }
  }

  /// Push queued invoices one at a time. We hit the dedicated
  /// /invoices endpoint because it carries richer state (server-assigned
  /// number, recomputed totals, fiscal fields) than the bulk push allows.
  /// Each invoice is upserted; if it transitioned from DRAFT it is then
  /// issued so a number is assigned.
  Future<void> _pushInvoices() async {
    final keys = LocalDb.outboxBox.keys
        .whereType<String>()
        .where((k) => k.startsWith('invoice:'))
        .toList();
    if (keys.isEmpty) return;
    for (final key in keys.take(50)) {
      final entry = LocalDb.outboxBox.get(key);
      if (entry == null) continue;
      final id = (entry as Map)['id'] as String?;
      if (id == null) {
        await LocalDb.outboxBox.delete(key);
        continue;
      }
      final inv = LocalDb.findInvoice(id);
      if (inv == null) {
        await LocalDb.outboxBox.delete(key);
        continue;
      }
      try {
        // Upsert the body — server recomputes totals + persists customer.
        final upsert = await _api.post('/invoices', data: inv.toApiPayload());
        var fresh = Invoice.fromMap({
          ...Map<String, dynamic>.from(upsert.data as Map),
          'dirty': false,
        });

        // If the local copy was non-DRAFT but the server still sees DRAFT
        // (i.e. issuance never reached the server), issue now to assign
        // a number.
        if (inv.status != 'DRAFT' && fresh.status == 'DRAFT') {
          final issued = await _api.post('/invoices/$id/issue');
          fresh = Invoice.fromMap({
            ...Map<String, dynamic>.from(issued.data as Map),
            'dirty': false,
          });
        }

        // Replay any unsynced payments (those the server doesn't yet have).
        final knownIds =
            fresh.payments.map((p) => p.id).toSet();
        for (final p in inv.payments) {
          if (!knownIds.contains(p.id)) {
            try {
              final r = await _api.post('/invoices/$id/payments',
                  data: p.toMap());
              fresh = Invoice.fromMap({
                ...Map<String, dynamic>.from(r.data as Map),
                'dirty': false,
              });
            } on DioException {
              // Will retry on next cycle; preserve local state.
            }
          }
        }

        await LocalDb.putInvoice(fresh);
        await LocalDb.outboxBox.delete(key);
      } on DioException {
        // Leave in outbox for the next cycle. Don't escalate — other
        // invoices might still succeed.
      }
    }
  }

  Future<void> _pull() async {
    final since = LocalDb.lastPullAt;
    final resp = await _api.post('/sync/pull', data: {
      'deviceId': LocalDb.deviceId,
      'since': since.toUtc().toIso8601String(),
    });
    final data = resp.data as Map;

    for (final raw in (data['products'] as List).cast<Map>()) {
      final p = Product.fromMap(Map<String, dynamic>.from(raw));
      final local = LocalDb.findProduct(p.id);
      // Last-write-wins by version; local dirty writes are never overwritten.
      if (local == null || (!local.dirty && local.version <= p.version)) {
        await LocalDb.putProduct(p);
      }
    }
    for (final raw in (data['sales'] as List).cast<Map>()) {
      final m = Map<String, dynamic>.from(raw);
      m['items'] = raw['items'] ?? [];
      await LocalDb.putSale(Sale.fromMap(m));
    }
    if (data['subscription'] is Map) {
      LocalDb.tier = (data['subscription'] as Map)['tier'] ?? LocalDb.tier;
    }
    LocalDb.lastPullAt = DateTime.parse(data['serverNow']).toUtc();
  }
}
