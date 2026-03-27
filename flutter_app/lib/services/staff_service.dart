import '../config/api_config.dart';
import 'api_client.dart';

class StaffService {
  final ApiClient _api;

  StaffService({required ApiClient api}) : _api = api;

  // ── Gym Info ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getGymInfo() async {
    final response = await _api.get(ApiConfig.staffGymInfo);
    return response.data as Map<String, dynamic>;
  }

  // ── Members ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMembers() async {
    final response = await _api.get(ApiConfig.staffMembers);
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> getMember(String memberId) async {
    final response = await _api.get(ApiConfig.staffMember(memberId));
    return response.data as Map<String, dynamic>;
  }

  // ── Check-in ──────────────────────────────────────────────
  Future<Map<String, dynamic>> checkIn(String memberId) async {
    final response = await _api.post(
      ApiConfig.staffCheckin,
      data: {'member_id': memberId},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCheckinsToday() async {
    final response = await _api.get(ApiConfig.staffCheckinsToday);
    return response.data as Map<String, dynamic>;
  }

  // ── Appointments ──────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAppointmentsToday() async {
    final response = await _api.get(ApiConfig.staffAppointmentsToday);
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ── Trainers ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getTrainers() async {
    final response = await _api.get(ApiConfig.staffTrainers);
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> getTrainerSchedule(String trainerId) async {
    final response = await _api.get(ApiConfig.staffTrainerSchedule(trainerId));
    return response.data as Map<String, dynamic>;
  }

  // ── Subscriptions ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSubscriptionPlans() async {
    final response = await _api.get(ApiConfig.staffSubscriptionPlans);
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> subscribeClient(
      String clientId, String planId) async {
    final response = await _api.post(
      ApiConfig.staffSubscribeClient,
      data: {'client_id': clientId, 'plan_id': planId},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelSubscription(String clientId) async {
    final response = await _api.post(
      ApiConfig.staffCancelSubscription,
      data: {'client_id': clientId},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> previewSubscriptionChange(
      String clientId, String planId) async {
    final response = await _api.post(
      ApiConfig.staffChangeSubscriptionPreview,
      data: {'client_id': clientId, 'plan_id': planId},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> changeSubscription(
      String clientId, String planId, String paymentMethod) async {
    final response = await _api.post(
      ApiConfig.staffChangeSubscription,
      data: {
        'client_id': clientId,
        'plan_id': planId,
        'payment_method': paymentMethod,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Onboarding ────────────────────────────────────────────
  Future<Map<String, dynamic>> getWaiverTemplate() async {
    final response = await _api.get(ApiConfig.staffWaiverTemplate);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> onboardClient(
      Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.staffOnboardClient, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createPaymentIntent(
      String planId, String clientName,
      {String? couponCode}) async {
    final response = await _api.post(
      ApiConfig.staffCreatePaymentIntent,
      data: {
        'plan_id': planId,
        'client_name': clientName,
        if (couponCode != null) 'coupon_code': couponCode,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendCredentials({
    required String clientId,
    required String method,
    required String username,
    required String temporaryPassword,
    String? name,
  }) async {
    final response = await _api.post(
      ApiConfig.staffSendCredentials,
      data: {
        'client_id': clientId,
        'method': method,
        'username': username,
        'temporary_password': temporaryPassword,
        'name': name,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Remote Signing Session ───────────────────────────────
  Future<Map<String, dynamic>> createSigningSession({
    required String clientName,
    required String waiverText,
  }) async {
    final response = await _api.post(
      ApiConfig.staffSigningSession,
      data: {'client_name': clientName, 'waiver_text': waiverText},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> pollSigningSession(String token) async {
    final response = await _api.get(ApiConfig.staffSigningSessionStatus(token));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createPhotoSnapSession() async {
    final response = await _api.post(ApiConfig.staffPhotoSnapSession, data: {});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> pollPhotoSnapSession(String token) async {
    final response = await _api.get(ApiConfig.staffPhotoSnapSessionStatus(token));
    return response.data as Map<String, dynamic>;
  }

  // ── Password / Username ───────────────────────────────────
  Future<Map<String, dynamic>> resetMemberPassword(String memberId) async {
    final response = await _api.post(
      ApiConfig.staffResetMemberPassword,
      data: {'member_id': memberId},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> changeMemberUsername(
      String memberId, String newUsername) async {
    final response = await _api.post(
      ApiConfig.staffChangeMemberUsername,
      data: {'member_id': memberId, 'new_username': newUsername},
    );
    return response.data as Map<String, dynamic>;
  }

  // ── NFC Tags ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getNfcTags() async {
    final response = await _api.get(ApiConfig.staffNfcTags);
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> registerNfc(
      String nfcUid, String memberId, String label) async {
    final response = await _api.post(
      ApiConfig.staffRegisterNfc,
      data: {'nfc_uid': nfcUid, 'member_id': memberId, 'label': label},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> unregisterNfc(String tagId) async {
    await _api.delete(ApiConfig.staffUnregisterNfc(tagId));
  }

  // ── Shower Usage ──────────────────────────────────────────
  Future<Map<String, dynamic>> getShowerUsage({String? day}) async {
    final path = day != null
        ? '${ApiConfig.staffShowerUsage}?day=$day'
        : ApiConfig.staffShowerUsage;
    final response = await _api.get(path);
    return response.data as Map<String, dynamic>;
  }

  // ── Terminal/POS ─────────────────────────────────────────
  Future<Map<String, dynamic>> processTerminalPayment({
    required double amount,
    required String description,
    String currency = 'eur',
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _api.post(
      ApiConfig.terminalProcessCustomPayment,
      data: {
        'amount': amount,
        'description': description,
        'currency': currency,
        if (metadata != null) 'metadata': metadata,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTerminalPaymentStatus(
      String paymentIntentId) async {
    final response =
        await _api.get(ApiConfig.terminalPaymentStatus(paymentIntentId));
    return response.data as Map<String, dynamic>;
  }

  Future<void> cancelTerminalPayment(String paymentIntentId) async {
    await _api.post(
      ApiConfig.terminalCancelPayment,
      data: {'payment_intent_id': paymentIntentId},
    );
  }

  Future<void> simulateTerminalPayment() async {
    await _api.post(ApiConfig.terminalSimulatePayment);
  }

  // ── Medical Certificates ────────────────────────────────
  Future<Map<String, dynamic>> uploadCertificate(
    String memberId, {
    required String fileData,
    required String filename,
    String? expirationDate,
  }) async {
    final response = await _api.post(
      ApiConfig.staffUploadCertificate(memberId),
      data: {
        'file_data': fileData,
        'filename': filename,
        if (expirationDate != null) 'expiration_date': expirationDate,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateCertificateExpiry(
      String memberId, String expirationDate) async {
    final response = await _api.put(
      ApiConfig.staffUpdateCertificate(memberId),
      data: {'expiration_date': expirationDate},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteCertificate(String memberId) async {
    await _api.delete(ApiConfig.staffDeleteCertificate(memberId));
  }

  // ── Certificate Approval ────────────────────────────────
  Future<Map<String, dynamic>> getPendingCertificates() async {
    final response = await _api.get(ApiConfig.staffPendingCertificates);
    return response.data as Map<String, dynamic>;
  }

  Future<void> approveCertificate(int certId) async {
    await _api.post(ApiConfig.staffApproveCertificate(certId));
  }

  Future<void> rejectCertificate(int certId, {String? reason}) async {
    await _api.post(
      ApiConfig.staffRejectCertificate(certId),
      data: {'reason': reason ?? ''},
    );
  }
}
