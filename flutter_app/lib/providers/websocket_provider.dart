import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/websocket_service.dart';
import 'auth_provider.dart';

final websocketServiceProvider = Provider<WebSocketService>((ref) {
  final storage = ref.read(storageServiceProvider);
  final ws = WebSocketService(storage: storage);

  // Auto-connect when authenticated, disconnect on logout
  ref.listen(authProvider, (prev, next) {
    if (next.status == AuthStatus.authenticated) {
      ws.connect();
    } else if (next.status == AuthStatus.unauthenticated) {
      ws.disconnect();
    }
  });

  ref.onDispose(() => ws.dispose());
  return ws;
});

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
