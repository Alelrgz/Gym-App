import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/nutritionist_service.dart';
import 'auth_provider.dart';

final nutritionistServiceProvider = Provider<NutritionistService>((ref) {
  final api = ref.read(apiClientProvider);
  return NutritionistService(api: api);
});

final nutritionistDataProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final service = ref.read(nutritionistServiceProvider);
  return service.getNutritionistData();
});

final nutritionistAppointmentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(nutritionistServiceProvider);
  return service.getAppointments();
});

final nutritionistAvailabilityProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(nutritionistServiceProvider);
  return service.getAvailability();
});

final nutritionistSessionRateProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final service = ref.read(nutritionistServiceProvider);
  return service.getSessionRate();
});

final nutritionistNotesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(nutritionistServiceProvider);
  return service.getNotes();
});
