import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import 'storage_service.dart';

class WebSocketService {
  final StorageService _storage;
  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _intentionalClose = false;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  // CO-OP filtered streams
  Stream<Map<String, dynamic>> get coopInvites =>
      messages.where((m) => m['type'] == 'coop_invite');
  Stream<Map<String, dynamic>> get coopAccepted =>
      messages.where((m) => m['type'] == 'coop_accepted');
  Stream<Map<String, dynamic>> get coopDeclined =>
      messages.where((m) => m['type'] == 'coop_declined');
  Stream<Map<String, dynamic>> get coopInviteFailed =>
      messages.where((m) => m['type'] == 'coop_invite_failed');
  Stream<Map<String, dynamic>> get coopInviteSent =>
      messages.where((m) => m['type'] == 'coop_invite_sent');
  Stream<Map<String, dynamic>> get coopCompleted =>
      messages.where((m) => m['type'] == 'coop_completed');

  bool get isConnected => _channel != null;

  WebSocketService({required StorageService storage}) : _storage = storage;

  Future<void> connect() async {
    if (_channel != null) return;
    _intentionalClose = false;

    final token = await _storage.getToken();
    if (token == null) {
      debugPrint('[WS] No token found — skipping connect');
      return;
    }

    final clientId = DateTime.now().millisecondsSinceEpoch.toString();
    final wsUrl = '${ApiConfig.wsUrl}/ws/$clientId?token=$token';
    debugPrint('[WS] Connecting to $wsUrl');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      debugPrint('[WS] Connected');
      _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            if (msg['type'] != 'pong') {
              _messageController.add(msg);
            }
          } catch (_) {}
        },
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
      );
      _startPingTimer();
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void sendCoopInvite(String partnerId) {
    send({'type': 'coop_invite', 'partner_id': partnerId});
  }

  void sendCoopAccept(String inviterId) {
    send({'type': 'coop_accept', 'inviter_id': inviterId});
  }

  void sendCoopDecline(String inviterId) {
    send({'type': 'coop_decline', 'inviter_id': inviterId});
  }

  void sendCoopCompleted(String partnerId) {
    send({'type': 'coop_completed', 'partner_id': partnerId});
  }

  void disconnect() {
    _intentionalClose = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      send({'type': 'ping'});
    });
  }

  void _onDisconnected() {
    _channel = null;
    _pingTimer?.cancel();
    if (!_intentionalClose) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
