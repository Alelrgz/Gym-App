import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../models/user.dart';

/// Holds the currently selected gym ID for multi-gym owners.
/// Defaults to the first gym in the owner's list.
final activeGymIdProvider = StateProvider<String?>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null || user.role != 'owner') return null;
  if (user.gyms.isEmpty) return user.id; // fallback for pre-migration
  return user.gyms.first.id;
});

/// Returns the list of gyms for the current owner.
final ownerGymsProvider = Provider<List<GymInfo>>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user?.gyms ?? [];
});
