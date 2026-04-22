import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/db/local_db.dart';
import '../../core/sync/sync_service.dart';
import '../../models/invoice.dart';

/// Riverpod controller for the invoice module.
///
/// Design:
///   - Local Hive copy is the source of truth for the UI.
///   - Every write is optimistic: we save locally, mark dirty, then try to
///     POST. If the POST fails (offline), the sync service drains later.
///   - Pulls refresh the list from the server when online; merges without
///     clobbering local dirty rows.
final invoiceListProvider =
    StateNotifierProvider<InvoiceListController, List<Invoice>>((ref) {
  final api = ref.watch(apiClientProvider);
  final sync = ref.watch(syncServiceProvider);
  return InvoiceListController(api, sync)..bootstrap();
});

class InvoiceListController extends StateNotifier<List<Invoice>> {
  InvoiceListController(this._api, this._sync) : super(LocalDb.allInvoices());

  final ApiClient _api;
  final SyncService _sync;

  void bootstrap() {
    state = LocalDb.allInvoices();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final r = await _api.get('/invoices');
      final remote = (r.data as List)
          .map((e) => Invoice.fromMap({
                ...Map<String, dynamic>.from(e as Map),
                'dirty': false,
              }))
          .toList();
      for (final inv in remote) {
        final local = LocalDb.findInvoice(inv.id);
        if (local == null || !local.dirty) {
          await LocalDb.putInvoice(inv);
        }
      }
      state = LocalDb.allInvoices();
    } catch (_) {
      // offline — local cache is enough
    }
  }

  Future<void> saveDraft(Invoice inv) async {
    inv.dirty = true;
    await LocalDb.putInvoice(inv);
    state = LocalDb.allInvoices();
    // Try the network now; if offline the SyncService will drain later.
    await _sync.enqueueInvoice(inv);
    _push(inv);
  }

  /// Convert a quote to an invoice (server-side; same id, new kind+number).
  Future<Invoice?> convertToInvoice(String id) async {
    try {
      final r = await _api.post('/invoices/$id/convert');
      final fresh = Invoice.fromMap({
        ...Map<String, dynamic>.from(r.data as Map),
        'dirty': false,
      });
      await LocalDb.putInvoice(fresh);
      state = LocalDb.allInvoices();
      return fresh;
    } catch (_) {
      return null;
    }
  }

  /// Issue a credit note that mirrors the parent invoice with negative lines.
  Future<Invoice?> creditNote(String id, String? reason) async {
    try {
      final r =
          await _api.post('/invoices/$id/credit-note', data: {'reason': reason});
      final fresh = Invoice.fromMap({
        ...Map<String, dynamic>.from(r.data as Map),
        'dirty': false,
      });
      await LocalDb.putInvoice(fresh);
      state = LocalDb.allInvoices();
      return fresh;
    } catch (_) {
      return null;
    }
  }

  /// Ask the server to flip SENT/PARTIAL invoices past their due date into
  /// OVERDUE so the dashboards stay honest.
  Future<int> sweepOverdue() async {
    try {
      final r = await _api.post('/invoices/sweep-overdue');
      final n = ((r.data as Map)['updated'] as num?)?.toInt() ?? 0;
      await _refresh();
      return n;
    } catch (_) {
      return 0;
    }
  }

  Future<Invoice?> issue(Invoice inv) async {
    if (inv.status == 'DRAFT') {
      // Flip locally so the UI updates immediately; server will assign number.
      inv.status = inv.totalCents == 0 ? 'PAID' : 'SENT';
      inv.dirty = true;
      await LocalDb.putInvoice(inv);
      state = LocalDb.allInvoices();
    }
    try {
      await _api.post('/invoices', data: inv.toApiPayload());
      final r = await _api.post('/invoices/${inv.id}/issue');
      final fresh = Invoice.fromMap({
        ...Map<String, dynamic>.from(r.data as Map),
        'dirty': false,
      });
      await LocalDb.putInvoice(fresh);
      state = LocalDb.allInvoices();
      return fresh;
    } catch (_) {
      // Couldn't reach the server — keep local optimistic state and queue.
      await _sync.enqueueInvoice(inv);
      return null;
    }
  }

  Future<Invoice?> recordPayment(String invoiceId, InvoicePayment p) async {
    // Append locally for instant feedback.
    final local = LocalDb.findInvoice(invoiceId);
    if (local != null) {
      local.payments = [...local.payments, p];
      if (local.paidCents >= local.totalCents) local.status = 'PAID';
      else if (local.paidCents > 0) local.status = 'PARTIAL';
      local.dirty = true;
      await LocalDb.putInvoice(local);
      state = LocalDb.allInvoices();
    }
    try {
      final r = await _api.post('/invoices/$invoiceId/payments',
          data: p.toMap());
      final fresh = Invoice.fromMap({
        ...Map<String, dynamic>.from(r.data as Map),
        'dirty': false,
      });
      await LocalDb.putInvoice(fresh);
      state = LocalDb.allInvoices();
      return fresh;
    } catch (_) {
      // Queue for later — local state already reflects the payment.
      if (local != null) await _sync.enqueueInvoice(local);
      return null;
    }
  }

  Future<void> voidInvoice(String id, String? reason) async {
    final local = LocalDb.findInvoice(id);
    if (local != null) {
      local.status = 'VOIDED';
      local.dirty = true;
      await LocalDb.putInvoice(local);
      state = LocalDb.allInvoices();
    }
    try {
      await _api.post('/invoices/$id/void', data: {'reason': reason});
    } catch (_) {
      if (local != null) await _sync.enqueueInvoice(local);
    }
  }

  Future<void> _push(Invoice inv) async {
    try {
      final r = await _api.post('/invoices', data: inv.toApiPayload());
      final fresh = Invoice.fromMap({
        ...Map<String, dynamic>.from(r.data as Map),
        'dirty': false,
      });
      await LocalDb.putInvoice(fresh);
      state = LocalDb.allInvoices();
    } catch (_) {/* offline — sync_service will retry */}
  }
}
