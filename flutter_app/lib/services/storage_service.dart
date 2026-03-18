import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

class StorageService {
  static const _tokenKey = 'jwt_token';
  static const _userKey = 'user_data';

  // Use SharedPreferences on web and desktop (macOS/Windows/Linux).
  // Use FlutterSecureStorage only on mobile (iOS/Android).
  static bool get _useSecure {
    if (kIsWeb) return false;
    // Desktop platforms: use SharedPreferences to avoid keychain issues
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) return false;
    return true; // iOS, Android
  }

  final FlutterSecureStorage? _secure;

  StorageService()
      : _secure = _useSecure
            ? const FlutterSecureStorage(
                aOptions: AndroidOptions(encryptedSharedPreferences: true),
                iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
              )
            : null;

  Future<void> saveToken(String token) async {
    if (_useSecure) {
      await _secure!.write(key: _tokenKey, value: token);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<String?> getToken() async {
    if (_useSecure) {
      return await _secure!.read(key: _tokenKey);
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveUser(User user) async {
    final json = jsonEncode(user.toJson());
    if (_useSecure) {
      await _secure!.write(key: _userKey, value: json);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, json);
    }
  }

  Future<User?> getUser() async {
    String? data;
    if (_useSecure) {
      data = await _secure!.read(key: _userKey);
    } else {
      final prefs = await SharedPreferences.getInstance();
      data = prefs.getString(_userKey);
    }
    if (data == null) return null;
    try {
      return User.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    if (_useSecure) {
      await _secure!.deleteAll();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    }
  }
}
