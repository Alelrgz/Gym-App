import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client_profile.dart';
import '../services/client_service.dart';
import 'auth_provider.dart';

final clientServiceProvider = Provider<ClientService>((ref) {
  final api = ref.read(apiClientProvider);
  return ClientService(api: api);
});

/// Fetches the full client dashboard data. Refreshable.
final clientDataProvider = FutureProvider.autoDispose<ClientProfile>((ref) async {
  final service = ref.read(clientServiceProvider);
  return service.getClientData();
});

/// Fetches all client-owned workouts. Refreshable.
final clientWorkoutsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final service = ref.read(clientServiceProvider);
  return service.getClientWorkouts();
});

/// Unread message count badge.
final unreadMessagesProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.read(clientServiceProvider);
  return service.getUnreadMessageCount();
});

/// Unread notification count badge.
final unreadNotificationsProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.read(clientServiceProvider);
  return service.getUnreadNotificationCount();
});

/// Notifications list.
final notificationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final service = ref.read(clientServiceProvider);
  return service.getNotifications();
});

/// Conversations list.
final conversationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final service = ref.read(clientServiceProvider);
  return service.getConversations();
});

/// Gym members list.
final gymMembersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final service = ref.read(clientServiceProvider);
  return service.getGymMembers();
});

/// Friends list.
final friendsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final service = ref.read(clientServiceProvider);
  return service.getFriends();
});

/// Leaderboard data (users, weekly challenge, league).
final leaderboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final service = ref.read(clientServiceProvider);
  return service.getLeaderboardData();
});

/// Flag to auto-open meal scanner when diet screen loads.
final pendingMealScanProvider = StateProvider<bool>((ref) => false);

/// Appointments list.
final appointmentsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final service = ref.read(clientServiceProvider);
  return service.getAppointments();
});
