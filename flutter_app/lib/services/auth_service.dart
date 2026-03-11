import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'storage_service.dart';

class AuthService {
  final ApiClient _api;
  final StorageService _storage;

  AuthService({required ApiClient api, required StorageService storage})
      : _api = api,
        _storage = storage;

  /// Login with username + password. Returns the authenticated User.
  Future<User> login(String username, String password) async {
    // Backend uses OAuth2PasswordRequestForm which requires form-encoded data
    final response = await _api.dio.post(
      ApiConfig.login,
      data: 'username=${Uri.encodeComponent(username)}&password=${Uri.encodeComponent(password)}',
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final user = User.fromLoginResponse(response.data as Map<String, dynamic>);
    await _storage.saveToken(user.token);
    await _storage.saveUser(user);
    return user;
  }

  /// Register a new client account, then login to get JWT.
  Future<User> register({
    required String username,
    required String password,
    String? email,
    String? gymCode,
  }) async {
    // Backend expects JSON body (user_data: dict)
    await _api.post(ApiConfig.register, data: {
      'username': username,
      'password': password,
      'role': 'client',
      if (email != null && email.isNotEmpty) 'email': email,
      if (gymCode != null && gymCode.isNotEmpty) 'gym_code': gymCode,
    });

    // Registration succeeded — now login to get JWT token
    return await login(username, password);
  }

  /// Check if user has a stored valid session.
  Future<User?> restoreSession() async {
    final token = await _storage.getToken();
    if (token == null) return null;

    final user = await _storage.getUser();
    if (user == null) {
      await _storage.clearAll();
      return null;
    }

    // Verify token is still valid by hitting a lightweight endpoint
    try {
      await _api.get(ApiConfig.notificationsUnreadCount);
      return user;
    } catch (_) {
      await _storage.clearAll();
      return null;
    }
  }

  /// Logout — clear all stored data.
  Future<void> logout() async {
    await _storage.clearAll();
  }
}
