import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

class StorageService {
  static const _tokenKey = 'jwt_token';
  static const _userKey = 'user_data';

  // Use SharedPreferences everywhere for reliability.
  // FlutterSecureStorage with encryptedSharedPreferences can lose data
  // on some Android devices when the app is killed and reopened from a notification.
  // JWT tokens expire in 8 hours anyway, so SharedPreferences is sufficient.
  static bool get _useSecure {
    if (kIsWeb) return false;
    // Use secure storage only on iOS (Keychain is reliable)
    if (!kIsWeb && Platform.isIOS) return true;
    return false;
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
