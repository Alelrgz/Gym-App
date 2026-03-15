import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/client_profile.dart';
import 'api_client.dart';

class ClientService {
  final ApiClient _api;
  ApiClient get api => _api;

  ClientService({required ApiClient api}) : _api = api;

  /// Fetch full client dashboard data.
  Future<ClientProfile> getClientData() async {
    final response = await _api.get(ApiConfig.clientData);
    return ClientProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get gym info (id, name, trainer).
  Future<Map<String, dynamic>> getGymInfo() async {
    final response = await _api.get(ApiConfig.clientGymInfo);
    return response.data as Map<String, dynamic>;
  }

  /// Get fitness goal and macro targets.
  Future<Map<String, dynamic>> getFitnessGoal() async {
    final response = await _api.get(ApiConfig.clientFitnessGoal);
    return response.data as Map<String, dynamic>;
  }

  /// Get unread message count.
  Future<int> getUnreadMessageCount() async {
    final response = await _api.get(ApiConfig.unreadCount);
    return (response.data as Map<String, dynamic>)['unread_count'] as int? ?? 0;
  }

  /// Get unread notification count.
  Future<int> getUnreadNotificationCount() async {
    final response = await _api.get(ApiConfig.notificationsUnreadCount);
    return (response.data as Map<String, dynamic>)['unread_count'] as int? ?? 0;
  }

  /// Get gym trainers list.
  Future<List<dynamic>> getGymTrainers() async {
    final response = await _api.get(ApiConfig.clientGymTrainers);
    return response.data as List<dynamic>;
  }

  /// Get weight history.
  Future<Map<String, dynamic>> getWeightHistory({String period = 'month'}) async {
    final response = await _api.get(
      ApiConfig.clientWeightHistory,
      queryParameters: {'period': period},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Toggle daily quest completion.
  Future<Map<String, dynamic>> toggleQuest(int questIndex) async {
    final response = await _api.post(
      ApiConfig.clientQuestToggle,
      data: {'quest_index': questIndex},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Fetch leaderboard data (users, weekly challenge, league info).
  Future<Map<String, dynamic>> getLeaderboardData() async {
    final response = await _api.get(ApiConfig.leaderboardData);
    return response.data as Map<String, dynamic>;
  }

  /// Fetch member profile for leaderboard tap.
  Future<Map<String, dynamic>> getMemberProfile(String memberId) async {
    final response = await _api.get(ApiConfig.memberProfile(memberId));
    return response.data as Map<String, dynamic>;
  }

  /// Join a gym by code.
  Future<Map<String, dynamic>> joinGym(String gymCode) async {
    final response = await _api.post(
      ApiConfig.clientJoinGym,
      data: {'gym_code': gymCode},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Select a trainer.
  Future<Map<String, dynamic>> selectTrainer(int trainerId) async {
    final response = await _api.post(
      ApiConfig.clientSelectTrainer,
      data: {'trainer_id': trainerId},
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Notifications ────────────────────────────────────────────

  Future<List<dynamic>> getNotifications() async {
    final response = await _api.get(ApiConfig.notifications);
    return response.data as List<dynamic>;
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _api.post(ApiConfig.notificationRead(notificationId));
  }

  Future<void> markAllNotificationsRead() async {
    await _api.post(ApiConfig.notificationsReadAll);
  }

  // ── Messages / Conversations ─────────────────────────────────

  Future<List<dynamic>> getConversations() async {
    final response = await _api.get(ApiConfig.conversations);
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getConversationMessages(String conversationId, {int limit = 50}) async {
    final response = await _api.get(
      ApiConfig.conversationMessages(conversationId),
      queryParameters: {'limit': limit},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendMessage({required String receiverId, required String content}) async {
    final response = await _api.post(ApiConfig.sendMessage, data: {
      'receiver_id': receiverId,
      'content': content,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> markConversationRead(String conversationId) async {
    await _api.post(ApiConfig.markRead(conversationId));
  }

  Future<Map<String, dynamic>> uploadMedia({
    required String receiverId,
    required String filePath,
    required String fileName,
    required String mimeType,
    double? duration,
  }) async {
    final formData = FormData.fromMap({
      'receiver_id': receiverId,
      'file': await MultipartFile.fromFile(filePath, filename: fileName, contentType: DioMediaType.parse(mimeType)),
      'duration': ?duration,
    });
    final response = await _api.upload(ApiConfig.uploadMedia, formData);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadMediaBytes({
    required String receiverId,
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    double? duration,
  }) async {
    final formData = FormData.fromMap({
      'receiver_id': receiverId,
      'file': MultipartFile.fromBytes(bytes, filename: fileName, contentType: DioMediaType.parse(mimeType)),
      'duration': ?duration,
    });
    final response = await _api.upload(ApiConfig.uploadMedia, formData);
    return response.data as Map<String, dynamic>;
  }

  // ── Gym Members & Friends ────────────────────────────────────

  Future<List<dynamic>> getGymMembers() async {
    final response = await _api.get(ApiConfig.clientGymMembers);
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getFriends() async {
    final response = await _api.get(ApiConfig.friends);
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> sendFriendRequest(String userId, {String? message}) async {
    final response = await _api.post(ApiConfig.friendRequest, data: {
      'to_user_id': userId,
      if (message != null && message.isNotEmpty) 'message': message,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> respondToFriendRequest(int requestId, bool accept) async {
    final response = await _api.post(ApiConfig.friendRequestRespond, data: {
      'request_id': requestId,
      'accept': accept,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> cancelFriendRequest(int requestId) async {
    await _api.delete(ApiConfig.friendRequestCancel(requestId));
  }

  Future<void> removeFriend(String friendId) async {
    await _api.delete(ApiConfig.friendRemove(friendId));
  }

  Future<List<dynamic>> getIncomingFriendRequests() async {
    final response = await _api.get(ApiConfig.friendRequestsIncoming);
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getOutgoingFriendRequests() async {
    final response = await _api.get(ApiConfig.friendRequestsOutgoing);
    return response.data as List<dynamic>;
  }

  // ── Appointments ─────────────────────────────────────────────

  Future<List<dynamic>> getAppointments({bool includePast = false}) async {
    final response = await _api.get(
      ApiConfig.clientAppointments,
      queryParameters: {'include_past': includePast},
    );
    return response.data as List<dynamic>;
  }

  // ── QR Access Token ──────────────────────────────────────────

  Future<Map<String, dynamic>> generateAccessToken() async {
    final response = await _api.post(ApiConfig.clientAccessToken);
    return response.data as Map<String, dynamic>;
  }

  // ── Diet & Nutrition ─────────────────────────────────────────

  Future<Map<String, dynamic>> selfAssignDiet({
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    int hydrationTarget = 2500,
    int consistencyTarget = 80,
  }) async {
    final response = await _api.post(ApiConfig.dietSelfAssign, data: {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'hydration_target': hydrationTarget,
      'consistency_target': consistencyTarget,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> logMeal(Map<String, dynamic> mealData) async {
    final response = await _api.post(ApiConfig.dietLog, data: mealData);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDietLogForDate(String date) async {
    final response = await _api.get(ApiConfig.dietLogForDate(date));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getWeeklyMealPlan() async {
    final response = await _api.get(ApiConfig.weeklyMealPlan);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addMealToPlan({
    required int dayOfWeek,
    required String mealType,
    required String mealName,
    String? description,
    int calories = 0,
    int protein = 0,
    int carbs = 0,
    int fat = 0,
  }) async {
    final response = await _api.post(ApiConfig.weeklyMealPlanAdd, data: {
      'day_of_week': dayOfWeek,
      'meal_type': mealType,
      'meal_name': mealName,
      'description': description,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteMealFromPlan(int mealId) async {
    final response = await _api.delete(ApiConfig.weeklyMealPlanDelete(mealId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> scanMeal(List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: DioMediaType.parse('image/jpeg')),
    });
    final response = await _api.upload(ApiConfig.dietScan, formData);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> lookupBarcode(String barcode) async {
    final response = await _api.get(ApiConfig.dietBarcode(barcode));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addWater() async {
    final response = await _api.post(ApiConfig.clientAddWater);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> logWeight(double weight) async {
    final response = await _api.post(
      '${ApiConfig.clientLogWeight}?weight=$weight',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setWeightGoal(double goal) async {
    final response = await _api.post(
      '${ApiConfig.clientWeightGoal}?weight_goal=$goal',
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Physique Photos ────────────────────────────────────────

  Future<Map<String, dynamic>> getPhysiquePhotos() async {
    final response = await _api.get(ApiConfig.physiquePhotos);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadPhysiquePhotoBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? title,
    String? photoDate,
    String? notes,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName, contentType: DioMediaType.parse(mimeType)),
      'title': ?title,
      'photo_date': ?photoDate,
      'notes': ?notes,
    });
    final response = await _api.upload(ApiConfig.physiquePhotoUpload, formData);
    return response.data as Map<String, dynamic>;
  }

  // ── Strength Progress ──────────────────────────────────────

  Future<Map<String, dynamic>> getStrengthProgress({String period = 'month'}) async {
    final response = await _api.get(
      ApiConfig.clientStrengthProgress,
      queryParameters: {'period': period},
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Workout / Schedule ──────────────────────────────────────

  Future<Map<String, dynamic>> completeWorkout(Map<String, dynamic> payload) async {
    final response = await _api.post(ApiConfig.completeWorkout, data: payload);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateWorkoutSet(Map<String, dynamic> payload) async {
    final response = await _api.put(ApiConfig.updateWorkoutSet, data: payload);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createWorkout({
    required String title,
    required String duration,
    required String difficulty,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final response = await _api.post(ApiConfig.clientCreateWorkout, data: {
      'title': title,
      'duration': duration,
      'difficulty': difficulty,
      'exercises': exercises,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateClientWorkout(String workoutId, Map<String, dynamic> updates) async {
    final response = await _api.put(ApiConfig.clientUpdateWorkout(workoutId), data: updates);
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getExerciseLibrary() async {
    final response = await _api.get(ApiConfig.exercises);
    final list = response.data as List<dynamic>;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  // ── Profile Updates ──────────────────────────────────────────

  Future<void> updateProfile(Map<String, dynamic> data) async {
    await _api.put(ApiConfig.clientProfile, data: data);
  }

  Future<Map<String, dynamic>> uploadProfilePicture(List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: DioMediaType.parse('image/jpeg')),
    });
    final response = await _api.upload(ApiConfig.profilePicture, formData);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteProfilePicture() async {
    await _api.delete(ApiConfig.profilePicture);
  }

  Future<void> updateBio(String bio) async {
    await _api.post(ApiConfig.profileBio, data: {'bio': bio});
  }

  // ── Privacy ────────────────────────────────────────────────

  Future<String> getPrivacyMode() async {
    final response = await _api.get(ApiConfig.clientPrivacy);
    return (response.data as Map<String, dynamic>)['privacy_mode'] as String? ?? 'public';
  }

  Future<void> setPrivacyMode(String mode) async {
    await _api.post(ApiConfig.clientPrivacy, data: {'mode': mode});
  }

  // ── Friend Progress ────────────────────────────────────────

  Future<Map<String, dynamic>> getFriendProgress(String friendId) async {
    final response = await _api.get(ApiConfig.friendProgress(friendId));
    return response.data as Map<String, dynamic>;
  }

  // ── CO-OP Workout ──────────────────────────────────────────

  Future<Map<String, dynamic>> completeCoopWorkout(Map<String, dynamic> payload) async {
    final response = await _api.post(ApiConfig.completeCoopWorkout, data: payload);
    return response.data as Map<String, dynamic>;
  }

  // ── Community ────────────────────────────────────────────

  Future<Map<String, dynamic>> getCommunityFeed({String? cursor, int limit = 20}) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;
    final response = await _api.get(ApiConfig.communityFeed, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createCommunityPost({
    required String postType,
    String? content,
    List<int>? imageBytes,
    String? imageFilename,
    String? eventTitle,
    String? eventDate,
    String? eventTime,
    String? eventLocation,
    int? maxParticipants,
    int? questXpReward,
    String? questDeadline,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'post_type': postType,
      if (content != null) 'content': content,
      if (eventTitle != null) 'event_title': eventTitle,
      if (eventDate != null) 'event_date': eventDate,
      if (eventTime != null) 'event_time': eventTime,
      if (eventLocation != null) 'event_location': eventLocation,
      if (maxParticipants != null) 'max_participants': maxParticipants,
      if (questXpReward != null) 'quest_xp_reward': questXpReward,
      if (questDeadline != null) 'quest_deadline': questDeadline,
      if (imageBytes != null && imageFilename != null)
        'image': MultipartFile.fromBytes(imageBytes, filename: imageFilename),
    });
    final response = await _api.upload(ApiConfig.communityPosts, formData);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> toggleEventParticipation(String postId) async {
    final response = await _api.post(ApiConfig.communityPostParticipate(postId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> togglePostLike(String postId) async {
    final response = await _api.post(ApiConfig.communityPostLike(postId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPostComments(String postId, {String? cursor, int limit = 20}) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;
    final response = await _api.get(ApiConfig.communityPostComments(postId), queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addComment(String postId, String content, {int? parentCommentId}) async {
    final response = await _api.post(ApiConfig.communityPostComments(postId), data: {
      'content': content,
      if (parentCommentId != null) 'parent_comment_id': parentCommentId,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteCommunityPost(String postId) async {
    final response = await _api.delete(ApiConfig.communityPostDelete(postId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteCommunityComment(int commentId) async {
    final response = await _api.delete(ApiConfig.communityCommentDelete(commentId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> pinCommunityPost(String postId) async {
    final response = await _api.post(ApiConfig.communityPostPin(postId));
    return response.data as Map<String, dynamic>;
  }
}
