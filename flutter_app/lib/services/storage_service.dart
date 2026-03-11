import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

class StorageService {
  static const _tokenKey = 'jwt_token';
  static const _userKey = 'user_data';

  // On web, FlutterSecureStorage is not available — use SharedPreferences.
  // On mobile, use FlutterSecureStorage for encrypted token storage.
  final FlutterSecureStorage? _secure;

  StorageService() : _secure = kIsWeb ? null : const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } else {
      await _secure!.write(key: _tokenKey, value: token);
    }
  }

  Future<String?> getToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    }
    return await _secure!.read(key: _tokenKey);
  }

  Future<void> saveUser(User user) async {
    final json = jsonEncode(user.toJson());
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, json);
    } else {
      await _secure!.write(key: _userKey, value: json);
    }
  }

  Future<User?> getUser() async {
    String? data;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      data = prefs.getString(_userKey);
    } else {
      data = await _secure!.read(key: _userKey);
    }
    if (data == null) return null;
    try {
      return User.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } else {
      await _secure!.deleteAll();
    }
  }
}
