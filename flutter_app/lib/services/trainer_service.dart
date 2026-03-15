import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/trainer_profile.dart';
import 'api_client.dart';

class TrainerService {
  final ApiClient _api;

  TrainerService({required ApiClient api}) : _api = api;

  // ── Core Data ────────────────────────────────────────────
  Future<TrainerProfile> getTrainerData() async {
    final response = await _api.get(ApiConfig.trainerData);
    return TrainerProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getWeeklyOverview() async {
    final response = await _api.get(ApiConfig.trainerWeeklyOverview);
    return response.data as Map<String, dynamic>;
  }

  Future<List<TrainerClient>> getClients() async {
    final response = await _api.get(ApiConfig.trainerClients);
    return (response.data as List)
        .map((c) => TrainerClient.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  // ── Exercises ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getExercises() async {
    final response = await _api.get(ApiConfig.trainerExercises);
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getCourseExercises() async {
    final response = await _api.get(ApiConfig.exercises);
    final all = (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return all.where((ex) => ex['type'] == 'Course').toList();
  }

  Future<Map<String, dynamic>> createExercise(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.exercises, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> updateExercise(String id, Map<String, dynamic> data) async {
    await _api.put(ApiConfig.exercise(id), data: data);
  }

  Future<Map<String, dynamic>> uploadExerciseVideo(String id, String filePath, String fileName) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _api.upload(ApiConfig.exerciseVideo(id), formData);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteExercise(String id) async {
    await _api.delete(ApiConfig.exercise(id));
  }

  // ── Workouts ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getWorkouts() async {
    final response = await _api.get(ApiConfig.trainerWorkouts);
    return (response.data as List).map((w) => Map<String, dynamic>.from(w as Map)).toList();
  }

  Future<Map<String, dynamic>> createWorkout(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.trainerWorkouts, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> updateWorkout(String id, Map<String, dynamic> data) async {
    await _api.put(ApiConfig.trainerWorkout(id), data: data);
  }

  Future<void> deleteWorkout(String id) async {
    await _api.delete(ApiConfig.trainerWorkout(id));
  }

  Future<void> assignWorkout(Map<String, dynamic> data) async {
    await _api.post(ApiConfig.trainerAssignWorkout, data: data);
  }

  // ── Splits ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSplits() async {
    final response = await _api.get(ApiConfig.trainerSplits);
    return (response.data as List).map((s) => Map<String, dynamic>.from(s as Map)).toList();
  }

  Future<Map<String, dynamic>> createSplit(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.trainerSplits, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> updateSplit(String id, Map<String, dynamic> data) async {
    await _api.put(ApiConfig.trainerSplit(id), data: data);
  }

  Future<void> deleteSplit(String id) async {
    await _api.delete(ApiConfig.trainerSplit(id));
  }

  Future<void> assignSplit(Map<String, dynamic> data) async {
    await _api.post(ApiConfig.trainerAssignSplit, data: data);
  }

  // ── Schedule & Events ────────────────────────────────────
  Future<void> createEvent(Map<String, dynamic> data) async {
    await _api.post(ApiConfig.trainerEvents, data: data);
  }

  Future<Map<String, dynamic>> updateEvent(String id, Map<String, dynamic> updates) async {
    final response = await _api.put(ApiConfig.trainerEvent(id), data: updates);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rescheduleEventSeries(String id, Map<String, dynamic> updates) async {
    final response = await _api.put(ApiConfig.trainerEventRescheduleSeries(id), data: updates);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteEvent(String id) async {
    await _api.delete(ApiConfig.trainerEvent(id));
  }

  Future<void> completeScheduleEntry(Map<String, dynamic> data) async {
    await _api.post(ApiConfig.trainerScheduleComplete, data: data);
  }

  // ── Availability ─────────────────────────────────────────
  Future<List<dynamic>> getAvailability() async {
    final response = await _api.get(ApiConfig.trainerAvailabilitySettings);
    return response.data as List<dynamic>;
  }

  Future<void> saveAvailability(Map<String, dynamic> data) async {
    await _api.post(ApiConfig.trainerAvailabilitySettings, data: data);
  }

  // ── Profile ──────────────────────────────────────────────
  Future<void> saveBio(String bio) async {
    await _api.post(ApiConfig.trainerBio, data: {'bio': bio});
  }

  Future<void> saveSpecialties(List<String> specialties) async {
    await _api.post(ApiConfig.trainerSpecialties, data: {'specialties': specialties});
  }

  // ── Commissions ────────────────────────────────────────────
  Future<Map<String, dynamic>> getMyCommissions({String period = 'month'}) async {
    final response = await _api.get('${ApiConfig.trainerMyCommissions}?period=$period');
    return response.data as Map<String, dynamic>;
  }

  // ── Notes ────────────────────────────────────────────────
  Future<List<dynamic>> getPersonalNotes() async {
    final response = await _api.get(ApiConfig.trainerNotes);
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> savePersonalNote({required String title, required String content}) async {
    final response = await _api.post(ApiConfig.trainerNotes, data: {'title': title, 'content': content});
    return response.data as Map<String, dynamic>;
  }

  Future<void> updatePersonalNote(String noteId, {required String title, required String content}) async {
    await _api.put('${ApiConfig.trainerNotes}/$noteId', data: {'title': title, 'content': content});
  }

  Future<void> deletePersonalNote(String noteId) async {
    await _api.delete('${ApiConfig.trainerNotes}/$noteId');
  }

  // ── Courses ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCourses() async {
    final response = await _api.get(ApiConfig.trainerCourses);
    return (response.data as List).map((c) => Map<String, dynamic>.from(c as Map)).toList();
  }

  Future<Map<String, dynamic>> createCourse(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.trainerCourses, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> updateCourse(String id, Map<String, dynamic> data) async {
    await _api.put(ApiConfig.trainerCourse(id), data: data);
  }

  Future<void> deleteCourse(String id) async {
    await _api.delete(ApiConfig.trainerCourse(id));
  }

  Future<List<Map<String, dynamic>>> getCourseLessons(String courseId) async {
    final response = await _api.get(ApiConfig.trainerCourseLessons(courseId));
    return (response.data as List).map((l) => Map<String, dynamic>.from(l as Map)).toList();
  }

  Future<Map<String, dynamic>> scheduleLesson(String courseId, Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.trainerCourseSchedule(courseId), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeLesson(int lessonId, Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.trainerLessonComplete(lessonId), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteLesson(int lessonId) async {
    await _api.delete(ApiConfig.trainerLessonDelete(lessonId));
  }

  // ── Client Metrics ─────────────────────────────────────────
  Future<Map<String, dynamic>> getClientWeightHistory(String clientId, {String period = 'month'}) async {
    final response = await _api.get('${ApiConfig.trainerClientWeightHistory(clientId)}?period=$period');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getClientStrengthProgress(String clientId) async {
    final response = await _api.get(ApiConfig.trainerClientStrengthProgress(clientId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getClientDietConsistency(String clientId, {String period = 'month'}) async {
    final response = await _api.get('${ApiConfig.trainerClientDietConsistency(clientId)}?period=$period');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getClientWeekStreak(String clientId) async {
    final response = await _api.get(ApiConfig.trainerClientWeekStreak(clientId));
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getClientWorkoutLog(String clientId, {int limit = 30}) async {
    final response = await _api.get('${ApiConfig.trainerClientWorkoutLog(clientId)}?limit=$limit');
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getClientNotes(String clientId) async {
    final response = await _api.get(ApiConfig.trainerClientNotes(clientId));
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> saveClientNote(String clientId, {required String title, required String content}) async {
    final response = await _api.post(ApiConfig.trainerClientNotes(clientId), data: {'title': title, 'content': content});
    return response.data as Map<String, dynamic>;
  }

  Future<void> updateNote(String noteId, {required String title, required String content}) async {
    await _api.put('${ApiConfig.trainerNotes}/$noteId', data: {'title': title, 'content': content});
  }

  Future<void> deleteNote(String noteId) async {
    await _api.delete('${ApiConfig.trainerNotes}/$noteId');
  }

  // ── Messages (shared endpoints) ──────────────────────────
  Future<List<dynamic>> getConversations() async {
    final response = await _api.get(ApiConfig.conversations);
    return response.data as List<dynamic>;
  }

  Future<int> getUnreadMessageCount() async {
    final response = await _api.get(ApiConfig.unreadCount);
    return response.data['count'] as int? ?? 0;
  }

  // ── Notifications (shared endpoints) ─────────────────────
  Future<List<dynamic>> getNotifications() async {
    final response = await _api.get(ApiConfig.notifications);
    return response.data as List<dynamic>;
  }

  Future<int> getUnreadNotificationCount() async {
    final response = await _api.get(ApiConfig.notificationsUnreadCount);
    return response.data['count'] as int? ?? 0;
  }
}
