import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import '../models/user.dart';

/// Holds the currently selected gym ID for multi-gym owners.
/// Does NOT watch authProvider to avoid resetting when auth state changes.
final activeGymIdProvider = StateProvider<String?>((ref) {
  return null; // initialized by dashboard _syncGymContext
});

/// Returns the list of gyms for the current owner.
final ownerGymsProvider = Provider<List<GymInfo>>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user?.gyms ?? [];
});

/// Returns the default gym ID (first gym) for initialization.
final defaultGymIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authProvider);
  final user = authState.user;
  if (user == null || user.role != 'owner') return null;
  if (user.gyms.isEmpty) return user.id;
  return user.gyms.first.id;
});
