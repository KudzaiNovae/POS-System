import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../db/local_db.dart';

class AuthState {
  AuthState({this.token, this.tenantId, this.tier = 'FREE'});
  final String? token;
  final String? tenantId;
  final String tier;
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final api = ref.watch(apiClientProvider);
  return AuthController(api);
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._api)
      : super(AuthState(
          token: LocalDb.authToken,
          tenantId: LocalDb.tenantId,
          tier: LocalDb.tier,
        )) {
    if (LocalDb.deviceId == null) {
      LocalDb.deviceId = const Uuid().v4();
    }
  }

  final ApiClient _api;

  Future<void> register({
    required String businessName,
    required String countryCode,
    required String currency,
    required String ownerEmail,
    required String password,
    String? ownerPhone,
  }) async {
    final r = await _api.post('/auth/register', data: {
      'businessName': businessName,
      'countryCode': countryCode,
      'currency': currency,
      'ownerEmail': ownerEmail,
      'ownerPhone': ownerPhone,
      'password': password,
    });
    // Persist profile inputs so Settings can display them even before the
    // server echoes them back in a future subscription payload.
    LocalDb.shopName = businessName;
    LocalDb.countryCode = countryCode;
    LocalDb.currency = currency;
    LocalDb.ownerEmail = ownerEmail;
    _store(r.data);
  }

  Future<void> login(String email, String password) async {
    final r = await _api.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    LocalDb.ownerEmail = email;
    _store(r.data);
  }

  Future<void> refreshSession() async {
    final refreshToken = LocalDb.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return;
    }
    final r = await _api.post('/auth/refresh', data: {
      'refreshToken': refreshToken,
    });
    _store(r.data);
  }

  Future<Map<String, dynamic>> upgradeSubscription({
    required String tier,
    required String provider,
    required String phone,
  }) async {
    final r = await _api.post('/subscriptions/checkout', data: {
      'tier': tier,
      'provider': provider,
      'phone': phone,
    });
    if (r.data is Map) {
      await refreshSession();
      return Map<String, dynamic>.from(r.data as Map);
    }
    throw StateError('Unexpected checkout response.');
  }

  void logout() {
    LocalDb.authToken = null;
    LocalDb.refreshToken = null;
    LocalDb.tenantId = null;
    LocalDb.tier = 'FREE';
    state = AuthState();
  }

  void _store(Map data) {
    LocalDb.authToken = data['token'];
    LocalDb.refreshToken = data['refreshToken'];
    LocalDb.tenantId = data['tenantId'];
    LocalDb.tier = data['tier'] ?? 'FREE';
    state = AuthState(
      token: LocalDb.authToken,
      tenantId: LocalDb.tenantId,
      tier: LocalDb.tier,
    );
  }
}
