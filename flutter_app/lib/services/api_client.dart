import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'storage_service.dart';

class ApiClient {
  late final Dio dio;
  final StorageService _storage;

  /// Called when a 401 is received — the auth provider sets this to trigger logout.
  void Function()? onUnauthorized;

  /// Active gym ID for multi-gym owners. Set by the gym provider.
  String? activeGymId;

  ApiClient({required StorageService storage}) : _storage = storage {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // Inject active gym context for multi-gym owners
        if (activeGymId != null && activeGymId!.isNotEmpty) {
          options.headers['X-Gym-Id'] = activeGymId;
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await _storage.clearAll();
          onUnauthorized?.call();
        }
        return handler.next(error);
      },
    ));
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return dio.delete(path);
  }

  Future<Response> upload(String path, FormData formData) {
    return dio.post(path, data: formData);
  }
}
