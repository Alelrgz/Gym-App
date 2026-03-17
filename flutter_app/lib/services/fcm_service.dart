import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'local_notification_service.dart';
import 'api_client.dart';
import '../config/api_config.dart';

/// Top-level background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
  // The system tray notification is shown automatically by FCM.
  // When the user taps it, the app opens and onMessageOpenedApp fires.
}

class FcmService {
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;
  FcmService._();

  ApiClient? _api;
  bool _initialized = false;

  /// Initialize FCM. Call after Firebase.initializeApp() and after login.
  Future<void> init(ApiClient api) async {
    if (kIsWeb || _initialized) return;
    _api = api;

    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission (iOS requires this, Android auto-grants)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Permission denied — skipping');
        return;
      }

      // Get and register the device token
      final token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen(_registerToken);

      // Handle foreground messages — show local notification
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app was in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Handle notification tap that launched the app from terminated state
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      _initialized = true;
      debugPrint('[FCM] Initialized with token: ${token?.substring(0, 20)}...');
    } catch (e) {
      debugPrint('[FCM] Init error: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    if (_api == null) return;
    try {
      await _api!.post(
        ApiConfig.registerDevice,
        data: {'token': token, 'platform': 'android'},
      );
      debugPrint('[FCM] Token registered');
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // Show a local notification (FCM doesn't auto-show in foreground)
    LocalNotificationService().show(
      title: notification.title ?? '',
      body: notification.body ?? '',
      payload: message.data.containsKey('link')
          ? message.data['link']
          : null,
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM] Opened app from notification: ${message.data}');

    // If the notification has a link (WhatsApp/SMS), open it
    final link = message.data['link'];
    if (link != null && link.toString().isNotEmpty) {
      final uri = Uri.tryParse(link.toString());
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
