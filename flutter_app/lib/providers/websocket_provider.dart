import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/websocket_service.dart';
import '../services/local_notification_service.dart';
import 'auth_provider.dart';

final websocketServiceProvider = Provider<WebSocketService>((ref) {
  final storage = ref.read(storageServiceProvider);
  final ws = WebSocketService(storage: storage);
  StreamSubscription<Map<String, dynamic>>? notifSub;

  // Auto-connect when authenticated, disconnect on logout
  ref.listen(authProvider, (prev, next) {
    if (next.status == AuthStatus.authenticated) {
      ws.connect();
      // Listen for incoming messages and show local notifications
      notifSub?.cancel();
      notifSub = ws.messages.listen((msg) {
        _handleLocalNotification(msg);
      });
    } else if (next.status == AuthStatus.unauthenticated) {
      notifSub?.cancel();
      ws.disconnect();
    }
  });

  ref.onDispose(() {
    notifSub?.cancel();
    ws.dispose();
  });
  return ws;
});

/// Show a local notification for relevant WebSocket messages.
void _handleLocalNotification(Map<String, dynamic> msg) {
  final type = msg['type'] as String? ?? '';

  // Skip internal/coop messages — only notify for actionable things
  const skipTypes = {
    'pong', 'ping',
    'coop_invite_sent', 'coop_accepted', 'coop_declined',
    'coop_invite', 'coop_invite_failed', 'coop_completed',
  };
  if (skipTypes.contains(type)) return;

  final notif = LocalNotificationService();

  if (type == 'notification' || type == 'automated_message') {
    notif.show(
      title: msg['title'] as String? ?? 'FitOS',
      body: msg['message'] as String? ?? msg['body'] as String? ?? '',
      payload: type,
    );
  } else if (type == 'new_message') {
    final sender = msg['sender_name'] as String? ?? 'Nuovo messaggio';
    final text = msg['text'] as String? ?? msg['message'] as String? ?? '';
    notif.show(
      title: sender,
      body: text.length > 100 ? '${text.substring(0, 100)}...' : text,
      payload: 'chat_${msg['conversation_id'] ?? ''}',
    );
  }
}

// ── CO-OP Session State ──────────────────────────────────────

enum CoopStatus { idle, inviting, invited, active }

class CoopState {
  final CoopStatus status;
  final String? partnerId;
  final String? partnerName;
  final String? partnerPicture;

  const CoopState({
    this.status = CoopStatus.idle,
    this.partnerId,
    this.partnerName,
    this.partnerPicture,
  });

  CoopState copyWith({
    CoopStatus? status,
    String? partnerId,
    String? partnerName,
    String? partnerPicture,
  }) {
    return CoopState(
      status: status ?? this.status,
      partnerId: partnerId ?? this.partnerId,
      partnerName: partnerName ?? this.partnerName,
      partnerPicture: partnerPicture ?? this.partnerPicture,
    );
  }
}

class CoopNotifier extends StateNotifier<CoopState> {
  CoopNotifier() : super(const CoopState());

  void setInviting(String partnerId) {
    state = CoopState(status: CoopStatus.inviting, partnerId: partnerId);
  }

  void setInvited(String fromId, String fromName, String? fromPicture) {
    state = CoopState(
      status: CoopStatus.invited,
      partnerId: fromId,
      partnerName: fromName,
      partnerPicture: fromPicture,
    );
  }

  void setActive(String partnerId, String partnerName, String? partnerPicture) {
    state = CoopState(
      status: CoopStatus.active,
      partnerId: partnerId,
      partnerName: partnerName,
      partnerPicture: partnerPicture,
    );
  }

  void reset() {
    state = const CoopState();
  }
}

final coopProvider = StateNotifierProvider<CoopNotifier, CoopState>((ref) {
  return CoopNotifier();
});
