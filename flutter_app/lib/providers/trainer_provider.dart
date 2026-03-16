import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trainer_profile.dart';
import '../services/trainer_service.dart';
import 'auth_provider.dart';

final trainerServiceProvider = Provider<TrainerService>((ref) {
  final api = ref.read(apiClientProvider);
  return TrainerService(api: api);
});

final trainerDataProvider = FutureProvider.autoDispose<TrainerProfile>((ref) async {
  final service = ref.read(trainerServiceProvider);
  return service.getTrainerData();
});

final trainerWeeklyOverviewProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final service = ref.read(trainerServiceProvider);
  return service.getWeeklyOverview();
});

final trainerExercisesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(trainerServiceProvider);
  return service.getExercises();
});

final trainerWorkoutsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(trainerServiceProvider);
  return service.getWorkouts();
});

final trainerSplitsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(trainerServiceProvider);
  return service.getSplits();
});

final trainerCoursesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(trainerServiceProvider);
  return service.getCourses();
});

final courseExercisesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(trainerServiceProvider);
  return service.getCourseExercises();
});

final trainerPendingAppointmentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(trainerServiceProvider);
  return service.getPendingAppointments();
});
