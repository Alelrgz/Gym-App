import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notification service — shows system-tray notifications when
/// the app is in the foreground or background.
/// No-op on web (web doesn't support flutter_local_notifications).
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Android notification channel for general messages.
  static const _androidChannel = AndroidNotificationChannel(
    'fitos_general',
    'Notifiche Generali',
    description: "Notifiche dall'app Heaven's Fit",
    importance: Importance.high,
  );

  Future<void> init() async {
    if (kIsWeb || _initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channel
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_androidChannel);
      await androidPlugin.requestNotificationsPermission();
    }

    // Request iOS permission
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  /// Show a local notification.
  Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb || !_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  // ─── REST TIMER NOTIFICATION ───────────────────────────

  static const _timerChannel = AndroidNotificationChannel(
    'fitos_rest_timer',
    'Timer Riposo',
    description: 'Countdown timer durante il riposo tra le serie',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  static const int _timerNotificationId = 99999;

  /// Show or update the rest timer notification with remaining seconds.
  Future<void> showRestTimer({required int secondsRemaining, required String exerciseName}) async {
    if (kIsWeb || !_initialized) return;

    final minutes = secondsRemaining ~/ 60;
    final seconds = secondsRemaining % 60;
    final timeStr = minutes > 0
        ? '${minutes}m ${seconds.toString().padLeft(2, '0')}s'
        : '${seconds}s';

    // Create timer channel if needed
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_timerChannel);
    }

    final androidDetails = AndroidNotificationDetails(
      _timerChannel.id,
      _timerChannel.name,
      channelDescription: _timerChannel.description,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      playSound: false,
      enableVibration: false,
      icon: '@mipmap/ic_launcher',
      subText: exerciseName,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.show(
      _timerNotificationId,
      'Riposo — $timeStr',
      'Prossima serie di $exerciseName',
      details,
    );
  }

  /// Show "rest complete" notification.
  Future<void> showRestComplete({required String exerciseName}) async {
    if (kIsWeb || !_initialized) return;

    await _plugin.cancel(_timerNotificationId);

    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _plugin.show(
      _timerNotificationId + 1,
      'Riposo completato!',
      'Continua con $exerciseName',
      details,
    );
  }

  /// Cancel the rest timer notification.
  Future<void> cancelRestTimer() async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancel(_timerNotificationId);
  }

  void _onNotificationTap(NotificationResponse response) {
    // Future: deep-link based on response.payload
  }
}
