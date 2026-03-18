import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/staff_service.dart';
import 'auth_provider.dart';

final staffServiceProvider = Provider<StaffService>((ref) {
  final api = ref.read(apiClientProvider);
  return StaffService(api: api);
});

final staffGymInfoProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final service = ref.read(staffServiceProvider);
  return service.getGymInfo();
});

final staffMembersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(staffServiceProvider);
  return service.getMembers();
});

final staffCheckinsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final service = ref.read(staffServiceProvider);
  return service.getCheckinsToday();
});

final staffAppointmentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(staffServiceProvider);
  return service.getAppointmentsToday();
});

final staffTrainersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(staffServiceProvider);
  return service.getTrainers();
});

final staffSubscriptionPlansProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(staffServiceProvider);
  return service.getSubscriptionPlans();
});
