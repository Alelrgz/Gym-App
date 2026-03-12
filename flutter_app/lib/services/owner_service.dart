import '../config/api_config.dart';
import 'api_client.dart';

class OwnerService {
  final ApiClient _api;

  OwnerService({required ApiClient api}) : _api = api;

  // ── Multi-Gym ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getGyms() async {
    final response = await _api.get(ApiConfig.ownerGyms);
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createGym(String name) async {
    final response = await _api.post(ApiConfig.ownerGyms, data: {'name': name});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateGym(String gymId, Map<String, dynamic> data) async {
    final response = await _api.put(ApiConfig.ownerGym(gymId), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteGym(String gymId) async {
    await _api.delete(ApiConfig.ownerGym(gymId));
  }

  // ── Dashboard / Core ────────────────────────────────────
  Future<Map<String, dynamic>> getOwnerData() async {
    final response = await _api.get(ApiConfig.ownerData);
    return response.data as Map<String, dynamic>;
  }

  Future<String> getGymCode() async {
    final response = await _api.get(ApiConfig.ownerGymCode);
    return (response.data as Map<String, dynamic>)['gym_code'] as String? ?? '';
  }

  Future<Map<String, dynamic>> getGymSettings() async {
    final response = await _api.get(ApiConfig.ownerGymSettings);
    return response.data as Map<String, dynamic>;
  }

  Future<void> updateGymName(String name, String password) async {
    await _api.post(ApiConfig.ownerGymSettings, data: {'gym_name': name, 'password': password});
  }

  Future<List<Map<String, dynamic>>> getActivityFeed() async {
    final response = await _api.get(ApiConfig.ownerActivityFeed);
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ── Trainers & Approvals ────────────────────────────────
  Future<List<Map<String, dynamic>>> getPendingTrainers() async {
    final response = await _api.get(ApiConfig.ownerPendingTrainers);
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getApprovedTrainers() async {
    final response = await _api.get(ApiConfig.ownerApprovedTrainers);
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> approveTrainer(String id) async {
    await _api.post(ApiConfig.ownerApproveTrainer(id));
  }

  Future<void> rejectTrainer(String id) async {
    await _api.post(ApiConfig.ownerRejectTrainer(id));
  }

  // ── Commissions ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getCommissions({String period = 'month'}) async {
    final response = await _api.get('${ApiConfig.ownerCommissions}?period=$period');
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> setCommissionRate(String trainerId, double rate) async {
    await _api.put(ApiConfig.ownerTrainerCommission(trainerId), data: {'commission_rate': rate});
  }

  // ── Subscription Plans ──────────────────────────────────
  Future<List<Map<String, dynamic>>> getSubscriptionPlans({bool includeInactive = true}) async {
    final response = await _api.get('${ApiConfig.ownerSubscriptionPlans}?include_inactive=$includeInactive');
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createPlan(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.ownerSubscriptionPlans, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> updatePlan(String id, Map<String, dynamic> data) async {
    await _api.put(ApiConfig.ownerSubscriptionPlan(id), data: data);
  }

  Future<void> deletePlan(String id) async {
    await _api.delete(ApiConfig.ownerSubscriptionPlan(id));
  }

  // ── Offers ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getOffers() async {
    final response = await _api.get(ApiConfig.ownerOffers);
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createOffer(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.ownerOffers, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> updateOffer(String id, Map<String, dynamic> data) async {
    await _api.put(ApiConfig.ownerOffer(id), data: data);
  }

  Future<void> deleteOffer(String id) async {
    await _api.delete(ApiConfig.ownerOffer(id));
  }

  // ── Automated Messages ──────────────────────────────────
  Future<List<Map<String, dynamic>>> getAutomatedMessages() async {
    final response = await _api.get(ApiConfig.ownerAutomatedMessages);
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> getAutomatedMessage(String id) async {
    final response = await _api.get(ApiConfig.ownerAutomatedMessage(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createAutomatedMessage(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.ownerAutomatedMessages, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> updateAutomatedMessage(String id, Map<String, dynamic> data) async {
    await _api.put(ApiConfig.ownerAutomatedMessage(id), data: data);
  }

  Future<void> deleteAutomatedMessage(String id) async {
    await _api.delete(ApiConfig.ownerAutomatedMessage(id));
  }

  Future<void> toggleAutomatedMessage(String id) async {
    await _api.post(ApiConfig.ownerAutomatedMessageToggle(id));
  }

  Future<Map<String, dynamic>> previewAutomatedMessage(String id) async {
    final response = await _api.post(ApiConfig.ownerAutomatedMessagePreview(id));
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getAutomatedMessagesLog() async {
    final response = await _api.get(ApiConfig.ownerAutomatedMessagesLog);
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> triggerCheck() async {
    await _api.post(ApiConfig.ownerAutomatedMessagesTrigger);
  }

  // ── CRM ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> getCrmPipeline() async {
    final response = await _api.get(ApiConfig.ownerCrmPipeline);
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getAtRiskClients() async {
    final response = await _api.get(ApiConfig.ownerCrmAtRisk);
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> getCrmAnalytics() async {
    final response = await _api.get(ApiConfig.ownerCrmAnalytics);
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getCrmInteractions() async {
    final response = await _api.get(ApiConfig.ownerCrmInteractions);
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getPipelineClients(String status) async {
    final response = await _api.get(ApiConfig.ownerCrmPipelineClients(status));
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getExClients() async {
    final response = await _api.get(ApiConfig.ownerCrmExClients);
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> generateWhatsappLink(String phone, String message) async {
    final response = await _api.post(ApiConfig.ownerCrmWhatsappLink, data: {
      'phone': phone,
      'message': message,
    });
    return response.data as Map<String, dynamic>;
  }

  // ── Client Metrics (reuses trainer endpoints) ──────────
  Future<Map<String, dynamic>> getClientWeekStreak(String clientId) async {
    final response = await _api.get(ApiConfig.trainerClientWeekStreak(clientId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getClientDietConsistency(String clientId, {String period = 'month'}) async {
    final response = await _api.get('${ApiConfig.trainerClientDietConsistency(clientId)}?period=$period');
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getClientWorkoutLog(String clientId) async {
    final response = await _api.get(ApiConfig.trainerClientWorkoutLog(clientId));
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getClientCourseLog(String clientId) async {
    final response = await _api.get(ApiConfig.trainerClientCourseLog(clientId));
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ── Facilities ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getActivityTypes() async {
    final response = await _api.get(ApiConfig.ownerActivityTypes);
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createActivityType(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.ownerActivityTypes, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> updateActivityType(String id, Map<String, dynamic> data) async {
    await _api.put(ApiConfig.ownerActivityType(id), data: data);
  }

  Future<void> deleteActivityType(String id) async {
    await _api.delete(ApiConfig.ownerActivityType(id));
  }

  Future<List<Map<String, dynamic>>> getFacilities(String activityTypeId) async {
    final response = await _api.get(ApiConfig.ownerFacilitiesForType(activityTypeId));
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createFacility(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.ownerFacilities, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> updateFacility(String id, Map<String, dynamic> data) async {
    await _api.put(ApiConfig.ownerFacility(id), data: data);
  }

  Future<void> deleteFacility(String id) async {
    await _api.delete(ApiConfig.ownerFacility(id));
  }

  Future<List<dynamic>> getFacilityAvailability(String id) async {
    final response = await _api.get(ApiConfig.ownerFacilityAvailability(id));
    return response.data as List<dynamic>;
  }

  Future<void> setFacilityAvailability(String id, Map<String, dynamic> data) async {
    await _api.post(ApiConfig.ownerFacilityAvailability(id), data: data);
  }

  Future<List<Map<String, dynamic>>> getFacilityBookings() async {
    final response = await _api.get(ApiConfig.ownerFacilityBookings);
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ── Settings ────────────────────────────────────────────
  Future<Map<String, dynamic>> getShowerSettings() async {
    final response = await _api.get(ApiConfig.ownerShowerSettings);
    return response.data as Map<String, dynamic>;
  }

  Future<void> updateShowerSettings(Map<String, dynamic> data) async {
    await _api.put(ApiConfig.ownerShowerSettings, data: data);
  }

  Future<Map<String, dynamic>> generateDeviceKey() async {
    final response = await _api.post(ApiConfig.ownerGenerateDeviceKey);
    return response.data as Map<String, dynamic>;
  }

  // ── SMTP Email Settings ────────────────────────────────
  Future<Map<String, dynamic>> getSmtpSettings() async {
    final response = await _api.get(ApiConfig.ownerSmtpSettings);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSmtpSettings(Map<String, dynamic> data) async {
    final response = await _api.put(ApiConfig.ownerSmtpSettings, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> testSmtpSettings() async {
    final response = await _api.post(ApiConfig.ownerSmtpTest);
    return response.data as Map<String, dynamic>;
  }

  // ── SMTP OAuth ────────────────────────────────────────
  Future<Map<String, dynamic>> getSmtpOAuthAuthorizeUrl(String provider) async {
    final response = await _api.get(ApiConfig.ownerSmtpOAuthAuthorize(provider));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSmtpOAuthStatus() async {
    final response = await _api.get(ApiConfig.ownerSmtpOAuthStatus);
    return response.data as Map<String, dynamic>;
  }

  Future<void> disconnectSmtpOAuth() async {
    await _api.delete(ApiConfig.ownerSmtpOAuthDisconnect);
  }

  // ── FCM Push Settings ────────────────────────────────
  Future<Map<String, dynamic>> getFcmSettings() async {
    final response = await _api.get(ApiConfig.ownerFcmSettings);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateFcmSettings(Map<String, dynamic> data) async {
    final response = await _api.put(ApiConfig.ownerFcmSettings, data: data);
    return response.data as Map<String, dynamic>;
  }

  // ── Stripe Connect ──────────────────────────────────────
  Future<Map<String, dynamic>> getStripeStatus() async {
    final response = await _api.get(ApiConfig.ownerStripeStatus);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> startStripeOnboard() async {
    final response = await _api.post(ApiConfig.ownerStripeOnboard);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStripeDashboard() async {
    final response = await _api.get(ApiConfig.ownerStripeDashboard);
    return response.data as Map<String, dynamic>;
  }

  // ── POS Terminal ────────────────────────────────────────
  Future<Map<String, dynamic>> getTerminalTestMode() async {
    final response = await _api.get(ApiConfig.terminalTestMode);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTerminalLocation(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.terminalCreateLocation, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> registerTerminalReader(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.terminalRegisterReader, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> importTerminalReader(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.terminalImportReader, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getTerminalReaders() async {
    final response = await _api.get(ApiConfig.terminalReaders);
    return (response.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
