import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/db/local_db.dart';
import '../../models/customer.dart';

/// Riverpod controller for the customer module.
///
/// Same offline-first contract as invoices: Hive is the source of
/// truth for the UI; writes hit the network optimistically and fall
/// back to a local-only state when offline (the next sync cycle will
/// drain dirty rows).
final customerListProvider =
    StateNotifierProvider<CustomerListController, List<Customer>>((ref) {
  final api = ref.watch(apiClientProvider);
  return CustomerListController(api)..bootstrap();
});

class CustomerListController extends StateNotifier<List<Customer>> {
  CustomerListController(this._api) : super(LocalDb.allCustomers());

  final ApiClient _api;

  Future<void> bootstrap() async {
    state = LocalDb.allCustomers();
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final r = await _api.get('/customers');
      final remote = (r.data as List)
          .map((e) =>
              Customer.fromMap({...Map<String, dynamic>.from(e as Map), 'dirty': false}))
          .toList();
      for (final c in remote) {
        final local = LocalDb.findCustomer(c.id);
        if (local == null || !local.dirty) {
          await LocalDb.putCustomer(c);
        }
      }
      state = LocalDb.allCustomers();
    } catch (_) {
      // offline — local cache is enough
    }
  }

  Future<Customer?> upsert(Customer c) async {
    c.dirty = true;
    c.updatedAt = DateTime.now().toUtc();
    await LocalDb.putCustomer(c);
    state = LocalDb.allCustomers();
    try {
      final r = await _api.post('/customers', data: c.toApiPayload());
      final fresh = Customer.fromMap(
          {...Map<String, dynamic>.from(r.data as Map), 'dirty': false});
      await LocalDb.putCustomer(fresh);
      state = LocalDb.allCustomers();
      return fresh;
    } catch (_) {
      // Will reconcile on the next sync; local copy stays dirty.
      return null;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _api.delete('/customers/$id');
      await LocalDb.deleteCustomer(id);
      state = LocalDb.allCustomers();
      return true;
    } catch (_) {
      return false;
    }
  }
}
