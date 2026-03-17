import '../config/api_config.dart';
import 'api_client.dart';

class NutritionistService {
  final ApiClient _api;

  NutritionistService({required ApiClient api}) : _api = api;

  // ── Dashboard Data ─────────────────────────────────────
  Future<Map<String, dynamic>> getNutritionistData() async {
    final response = await _api.get(ApiConfig.nutritionistData);
    return response.data as Map<String, dynamic>;
  }

  // ── Client Detail ──────────────────────────────────────
  Future<Map<String, dynamic>> getClientDetail(String clientId) async {
    final response = await _api.get(ApiConfig.nutritionistClientDetail(clientId));
    return response.data as Map<String, dynamic>;
  }

  // ── Body Composition ───────────────────────────────────
  Future<Map<String, dynamic>> addBodyComposition({
    required String clientId,
    required double weight,
    double? bodyFatPct,
    double? fatMass,
    double? leanMass,
  }) async {
    final response = await _api.post(
      ApiConfig.nutritionistBodyComposition,
      data: {
        'client_id': clientId,
        'weight': weight,
        if (bodyFatPct != null) 'body_fat_pct': bodyFatPct,
        if (fatMass != null) 'fat_mass': fatMass,
        if (leanMass != null) 'lean_mass': leanMass,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Weight Goal ────────────────────────────────────────
  Future<Map<String, dynamic>> setWeightGoal(
      String clientId, double weightGoal) async {
    final response = await _api.post(
      ApiConfig.nutritionistWeightGoal,
      data: {'client_id': clientId, 'weight_goal': weightGoal},
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Health Data ────────────────────────────────────────
  Future<Map<String, dynamic>> updateHealthData(
      Map<String, dynamic> data) async {
    final response = await _api.post(
      ApiConfig.nutritionistHealthData,
      data: data,
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Diet Assignment ────────────────────────────────────
  Future<Map<String, dynamic>> assignDiet({
    required String clientId,
    required int calories,
    int protein = 0,
    int carbs = 0,
    int fat = 0,
    int hydrationTarget = 2500,
    int consistencyTarget = 80,
  }) async {
    final response = await _api.post(
      ApiConfig.nutritionistAssignDiet,
      data: {
        'client_id': clientId,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'hydration_target': hydrationTarget,
        'consistency_target': consistencyTarget,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Charts ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getClientWeightHistory(
      String clientId, String period) async {
    final response = await _api.get(
      '${ApiConfig.nutritionistClientWeightHistory(clientId)}?period=$period',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getClientDietConsistency(
      String clientId, String period) async {
    final response = await _api.get(
      '${ApiConfig.nutritionistClientDietConsistency(clientId)}?period=$period',
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Weekly Meal Plan ───────────────────────────────────
  Future<Map<String, dynamic>> getClientWeeklyMealPlan(
      String clientId) async {
    final response =
        await _api.get(ApiConfig.nutritionistClientWeeklyMealPlan(clientId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setClientWeeklyMealPlan({
    required String clientId,
    required int dayOfWeek,
    required List<Map<String, dynamic>> meals,
  }) async {
    final response = await _api.post(
      ApiConfig.nutritionistClientWeeklyMealPlan(clientId),
      data: {
        'client_id': clientId,
        'day_of_week': dayOfWeek,
        'meals': meals,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Availability ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAvailability() async {
    final response = await _api.get(ApiConfig.nutritionistAvailability);
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> setAvailability(
      List<Map<String, dynamic>> availability) async {
    final response = await _api.post(
      ApiConfig.nutritionistAvailability,
      data: {'availability': availability},
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Session Rate ───────────────────────────────────────
  Future<Map<String, dynamic>> getSessionRate() async {
    final response = await _api.get(ApiConfig.nutritionistSessionRate);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setSessionRate(double? rate) async {
    final response = await _api.post(
      ApiConfig.nutritionistSessionRate,
      data: {'session_rate': rate},
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Appointments ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAppointments() async {
    final response = await _api.get(ApiConfig.nutritionistAppointments);
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> completeAppointment(
      String appointmentId, {String? notes}) async {
    final response = await _api.post(
      ApiConfig.nutritionistAppointmentComplete(appointmentId),
      data: {'notes': notes},
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Notes ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getNotes() async {
    final response = await _api.get(ApiConfig.nutritionistNotes);
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> saveNote({
    String? id,
    required String title,
    required String content,
  }) async {
    if (id != null) {
      final response = await _api.put(
        '${ApiConfig.nutritionistNotes}/$id',
        data: {'title': title, 'content': content},
      );
      return response.data as Map<String, dynamic>;
    }
    final response = await _api.post(
      ApiConfig.nutritionistNotes,
      data: {'title': title, 'content': content},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteNote(String id) async {
    await _api.delete('${ApiConfig.nutritionistNotes}/$id');
  }

  // ── Profile / Settings ─────────────────────────────────
  Future<Map<String, dynamic>> updateProfile({
    String? bio,
    String? specialties,
  }) async {
    final response = await _api.put(
      ApiConfig.nutritionistProfileUpdate,
      data: {
        if (bio != null) 'bio': bio,
        if (specialties != null) 'specialties': specialties,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
