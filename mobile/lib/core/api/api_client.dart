import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/local_db.dart';

/// Configure via --dart-define=API_BASE=https://api.tillpro.app
const _defaultBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://localhost:8080', // Android emulator → host localhost
);

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  ApiClient({String? baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: (baseUrl ?? _defaultBase) + '/api/v1',
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (opts, handler) {
        final token = LocalDb.authToken;
        if (token != null && token.isNotEmpty) {
          opts.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(opts);
      },
      onError: (e, handler) async {
        // One-shot refresh on 401
        if (e.response?.statusCode == 401 && LocalDb.refreshToken != null) {
          try {
            final r = await _dio.post('/auth/refresh',
                data: {'refreshToken': LocalDb.refreshToken});
            LocalDb.authToken = r.data['token'];
            LocalDb.refreshToken = r.data['refreshToken'];
            LocalDb.tier = r.data['tier'] ?? LocalDb.tier;
            final retry = await _dio.fetch(e.requestOptions
              ..headers['Authorization'] = 'Bearer ${LocalDb.authToken}');
            return handler.resolve(retry);
          } catch (_) {
            // fall through — real 401
          }
        }
        handler.next(e);
      },
    ));
  }

  final Dio _dio;
  Dio get dio => _dio;

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      _dio.post<T>(path, data: data);
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _dio.get<T>(path, queryParameters: query);
  Future<Response<T>> patch<T>(String path, {Object? data}) =>
      _dio.patch<T>(path, data: data);
  Future<Response<T>> delete<T>(String path) => _dio.delete<T>(path);
}
