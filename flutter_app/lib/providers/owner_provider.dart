import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/owner_service.dart';
import 'auth_provider.dart';

final ownerServiceProvider = Provider<OwnerService>((ref) {
  final api = ref.read(apiClientProvider);
  return OwnerService(api: api);
});

final ownerDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final service = ref.read(ownerServiceProvider);
  return service.getOwnerData();
});

final ownerGymCodeProvider = FutureProvider.autoDispose<String>((ref) async {
  final service = ref.read(ownerServiceProvider);
  return service.getGymCode();
});

final ownerPendingTrainersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(ownerServiceProvider);
  return service.getPendingTrainers();
});

final ownerApprovedTrainersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(ownerServiceProvider);
  return service.getApprovedTrainers();
});

final ownerSubscriptionPlansProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(ownerServiceProvider);
  return service.getSubscriptionPlans();
});

final ownerOffersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(ownerServiceProvider);
  return service.getOffers();
});

final ownerActivityTypesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(ownerServiceProvider);
  return service.getActivityTypes();
});
