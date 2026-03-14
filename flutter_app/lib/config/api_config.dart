import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  /// Override this at app startup to point native builds at your backend.
  /// Web builds auto-detect the host from the browser URL.
  /// For Android emulator use '10.0.2.2', for physical devices use your
  /// machine's LAN IP (e.g. '192.168.1.5').
  static String nativeHost = 'localhost';
  static int port = 9008;

  static String get wsUrl {
    final base = baseUrl;
    return base.replaceFirst('http', 'ws');
  }

  static String get baseUrl {
    if (kIsWeb) {
      // Use the same host the app was loaded from, so it works
      // from both localhost and LAN IP on phones
      final host = Uri.base.host;
      return 'http://$host:$port';
    }
    return 'http://$nativeHost:$port';
  }

  // Auth
  static const login = '/api/auth/login';
  static const register = '/api/auth/register';

  // Client
  static const clientData = '/api/client/data';
  static const clientProfile = '/api/client/profile';
  static const clientPrivacy = '/api/client/privacy';
  static const clientFitnessGoal = '/api/client/fitness-goal';
  static const clientGymInfo = '/api/client/gym-info';
  static const clientWeightHistory = '/api/client/weight-history';
  static const clientStrengthProgress = '/api/client/strength-progress';
  static const clientAccessToken = '/api/client/access-token';
  static const clientGymTrainers = '/api/client/gym-trainers';
  static const clientGymMembers = '/api/client/gym-members';
  static const clientAppointments = '/api/client/appointments';
  static const clientSubscriptionPlans = '/api/client/subscription-plans';
  static const clientJoinGym = '/api/client/join-gym';
  static const clientLeaveGym = '/api/client/leave-gym';
  static const clientSelectTrainer = '/api/client/select-trainer';
  static const clientQuestToggle = '/api/client/quest/toggle';

  // Diet
  static const dietScan = '/api/client/diet/scan';
  static const dietLog = '/api/client/diet/log';
  static const dietSelfAssign = '/api/client/diet/self-assign';
  static const weeklyMealPlan = '/api/client/weekly-meal-plan';
  static const weeklyMealPlanAdd = '/api/client/weekly-meal-plan/add';
  static String weeklyMealPlanDelete(int id) => '/api/client/weekly-meal-plan/$id';
  static String dietLogForDate(String date) => '/api/client/diet-log/$date';
  static String dietBarcode(String code) => '/api/client/diet/barcode/$code';

  // Messages
  static const conversations = '/api/messages/conversations';
  static const sendMessage = '/api/messages/send';
  static const unreadCount = '/api/messages/unread-count';
  static const uploadMedia = '/api/messages/upload-media';
  static String conversationMessages(String id) => '/api/messages/conversation/$id';
  static String markRead(String id) => '/api/messages/conversation/$id/read';

  // Friends
  static const friends = '/api/friends';
  static const friendRequest = '/api/friends/request';
  static const friendRequestRespond = '/api/friends/request/respond';
  static const friendRequestsIncoming = '/api/friends/requests/incoming';
  static const friendRequestsOutgoing = '/api/friends/requests/outgoing';
  static String friendRemove(String id) => '/api/friends/$id';
  static String friendRequestCancel(int id) => '/api/friends/request/$id';

  // Notifications
  static const notifications = '/api/notifications';
  static const notificationsUnreadCount = '/api/notifications/unread-count';
  static const notificationsReadAll = '/api/notifications/read-all';
  static String notificationRead(String id) => '/api/notifications/$id/read';

  // Physique Photos
  static const physiquePhotos = '/api/physique/photos';
  static const physiquePhotoUpload = '/api/physique/photo';
  static String physiquePhotoDelete(int id) => '/api/physique/photo/$id';

  // Hydration
  static const clientAddWater = '/api/client/add-water';

  // Weight
  static const clientLogWeight = '/api/client/log-weight';
  static const clientWeightGoal = '/api/client/weight-goal';

  // Profile
  static const profilePicture = '/api/profile/picture';
  static const profileBio = '/api/profile/bio';

  // Schedule / Workout
  static String clientSchedule(String date) => '/api/client/schedule?date=$date';
  static const completeWorkout = '/api/client/schedule/complete';
  static const completeCoopWorkout = '/api/client/schedule/complete-coop';
  static const updateWorkoutSet = '/api/client/schedule/update_set';
  static const clientCreateWorkout = '/api/client/workout/create';
  static String clientUpdateWorkout(String id) => '/api/client/workout/$id';

  // Leaderboard
  static const leaderboardData = '/api/leaderboard/data';
  static String memberProfile(String id) => '/api/client/member/$id';
  static String friendStatus(String id) => '/api/friends/status/$id';
  static String friendProgress(String id) => '/api/friends/$id/progress';

  // Appointments
  static String trainerAvailability(int id) => '/api/client/trainers/$id/availability';
  static String trainerAvailableSlots(int id) => '/api/client/trainers/$id/available-slots';
  static String trainerSessionTypes(int id) => '/api/client/trainers/$id/session-types';
  static String trainerSessionRate(int id) => '/api/client/trainers/$id/session-rate';
  static const appointmentCheckoutSession = '/api/client/appointment-checkout-session';

  // ── Trainer ─────────────────────────────────────────────
  static const trainerData = '/api/trainer/data';
  static const trainerWeeklyOverview = '/api/trainer/weekly-overview';
  static const trainerClients = '/api/trainer/clients';
  static const trainerExercises = '/api/trainer/exercises';
  static const trainerWorkouts = '/api/trainer/workouts';
  static String trainerWorkout(String id) => '/api/trainer/workouts/$id';
  static const trainerSplits = '/api/trainer/splits';
  static String trainerSplit(String id) => '/api/trainer/splits/$id';
  static const trainerAssignWorkout = '/api/trainer/assign_workout';
  static const trainerAssignSplit = '/api/trainer/assign_split';
  static const trainerCourses = '/api/trainer/courses';
  static String trainerCourse(String id) => '/api/trainer/courses/$id';
  static String trainerCourseLessons(String id) => '/api/trainer/courses/$id/lessons';
  static String trainerCourseSchedule(String id) => '/api/trainer/courses/$id/schedule';
  static String trainerLessonComplete(int id) => '/api/trainer/courses/lessons/$id/complete';
  static String trainerLessonDelete(int id) => '/api/trainer/courses/lessons/$id';
  static const trainerEvents = '/api/trainer/events';
  static String trainerEvent(String id) => '/api/trainer/events/$id';
  static String trainerEventRescheduleSeries(String id) => '/api/trainer/events/$id/reschedule-series';
  static const trainerScheduleComplete = '/api/trainer/schedule/complete';
  static const trainerAvailabilitySettings = '/api/trainer/availability';
  static const trainerNotes = '/api/trainer/notes';
  static const trainerBio = '/api/profile/bio';
  static const trainerSpecialties = '/api/profile/specialties';
  static const trainerMyCommissions = '/api/trainer/my-commissions';
  static const exercises = '/api/exercises';
  static String exercise(String id) => '/api/exercises/$id';
  static String exerciseVideo(String id) => '/api/exercises/$id/video';

  // ── Trainer Client Metrics ────────────────────────────────
  static String trainerClientWeightHistory(String id) => '/api/trainer/client/$id/weight-history';
  static String trainerClientStrengthProgress(String id) => '/api/trainer/client/$id/strength-progress';
  static String trainerClientDietConsistency(String id) => '/api/trainer/client/$id/diet-consistency';
  static String trainerClientWeekStreak(String id) => '/api/trainer/client/$id/week-streak';
  static String trainerClientWorkoutLog(String id) => '/api/trainer/client/$id/workout-log';
  static String trainerClientNotes(String id) => '/api/trainer/client/$id/notes';
  static String trainerClientCourseLog(String id) => '/api/trainer/client/$id/course-log';

  // ── Owner ───────────────────────────────────────────────
  // Dashboard / core
  static const ownerData = '/api/owner/data';
  static const ownerGymCode = '/api/owner/gym-code';
  static const ownerGymSettings = '/api/owner/gym-settings';
  static const ownerGymLogo = '/api/owner/gym-logo';
  static const ownerActivityFeed = '/api/owner/activity-feed';

  // Trainers & Commissions
  static const ownerPendingTrainers = '/api/owner/pending-trainers';
  static const ownerApprovedTrainers = '/api/owner/approved-trainers';
  static String ownerApproveTrainer(String id) => '/api/owner/approve-trainer/$id';
  static String ownerRejectTrainer(String id) => '/api/owner/reject-trainer/$id';
  static const ownerCommissions = '/api/owner/commissions';
  static String ownerTrainerCommission(String id) => '/api/owner/trainers/$id/commission';

  // Subscription Plans
  static const ownerSubscriptionPlans = '/api/owner/subscription-plans';
  static String ownerSubscriptionPlan(String id) => '/api/owner/subscription-plans/$id';

  // Offers
  static const ownerOffers = '/api/owner/offers';
  static String ownerOffer(String id) => '/api/owner/offers/$id';

  // Automated Messages
  static const ownerAutomatedMessages = '/api/owner/automated-messages';
  static String ownerAutomatedMessage(String id) => '/api/owner/automated-messages/$id';
  static String ownerAutomatedMessageToggle(String id) => '/api/owner/automated-messages/$id/toggle';
  static String ownerAutomatedMessagePreview(String id) => '/api/owner/automated-messages/$id/preview';
  static const ownerAutomatedMessagesLog = '/api/owner/automated-messages/log';
  static const ownerAutomatedMessagesTrigger = '/api/owner/automated-messages/trigger-check';

  // CRM
  static const ownerCrmPipeline = '/api/owner/crm/pipeline';
  static const ownerCrmAtRisk = '/api/owner/crm/at-risk';
  static const ownerCrmAnalytics = '/api/owner/crm/analytics';
  static const ownerCrmInteractions = '/api/owner/crm/interactions';
  static const ownerCrmExClients = '/api/owner/crm/ex-clients';
  static String ownerCrmPipelineClients(String status) => '/api/owner/crm/pipeline-clients?status=$status';
  static const ownerCrmWhatsappLink = '/api/owner/crm/whatsapp-link';

  // Multi-gym
  static const ownerGyms = '/api/owner/gyms';
  static String ownerGym(String id) => '/api/owner/gyms/$id';

  // Facilities
  static const ownerActivityTypes = '/api/owner/activity-types';
  static String ownerActivityType(String id) => '/api/owner/activity-types/$id';
  static String ownerFacilitiesForType(String typeId) => '/api/owner/facilities/$typeId';
  static const ownerFacilities = '/api/owner/facilities';
  static String ownerFacility(String id) => '/api/owner/facilities/$id';
  static String ownerFacilityAvailability(String id) => '/api/owner/facilities/$id/availability';
  static const ownerFacilityBookings = '/api/owner/facility-bookings';

  // Settings
  static const ownerShowerSettings = '/api/owner/shower-settings';
  static const ownerGenerateDeviceKey = '/api/owner/generate-device-key';
  static const ownerImportClients = '/api/owner/import-clients';

  // SMTP Email Settings
  static const ownerSmtpSettings = '/api/owner/smtp-settings';
  static const ownerSmtpTest = '/api/owner/smtp-settings/test';
  static String ownerSmtpOAuthAuthorize(String provider) => '/api/owner/smtp-oauth/$provider/authorize';
  static const ownerSmtpOAuthStatus = '/api/owner/smtp-oauth/status';
  static const ownerSmtpOAuthDisconnect = '/api/owner/smtp-oauth';

  // FCM Push Notification Settings
  static const ownerFcmSettings = '/api/owner/fcm-settings';
  static const registerDevice = '/api/notifications/register-device';
  static const unregisterDevice = '/api/notifications/unregister-device';

  // Stripe Connect
  static const ownerStripeOnboard = '/api/owner/stripe-connect/onboard';
  static const ownerStripeStatus = '/api/owner/stripe-connect/status';
  static const ownerStripeDashboard = '/api/owner/stripe-connect/dashboard';

  // POS Terminal
  static const terminalTestMode = '/api/terminal/test-mode';
  static const terminalCreateLocation = '/api/terminal/create-location';
  static const terminalRegisterReader = '/api/terminal/register-reader';
  static const terminalImportReader = '/api/terminal/import-reader';
  static const terminalReaders = '/api/terminal/readers';

  // ── Community ────────────────────────────────────────────
  static const communityFeed = '/api/community/feed';
  static const communityPosts = '/api/community/posts';
  static String communityPostDelete(String id) => '/api/community/posts/$id';
  static String communityPostLike(String id) => '/api/community/posts/$id/like';
  static String communityPostComments(String id) => '/api/community/posts/$id/comments';
  static String communityCommentDelete(int id) => '/api/community/comments/$id';
  static String communityCommentLike(int id) => '/api/community/comments/$id/like';
  static String communityPostPin(String id) => '/api/community/posts/$id/pin';

  // ── Staff ───────────────────────────────────────────────
  static const staffGymInfo = '/api/staff/gym-info';
  static const staffMembers = '/api/staff/members';
  static String staffMember(String id) => '/api/staff/member/$id';
  static const staffCheckin = '/api/staff/checkin';
  static const staffCheckinsToday = '/api/staff/checkins/today';
  static const staffAppointmentsToday = '/api/staff/appointments/today';
  static const staffTrainers = '/api/staff/trainers';
  static String staffTrainerSchedule(String id) => '/api/staff/trainer/$id/schedule';
  static const staffSubscriptionPlans = '/api/staff/subscription-plans';
  static const staffSubscribeClient = '/api/staff/subscribe-client';
  static const staffCancelSubscription = '/api/staff/cancel-subscription';
  static const staffChangeSubscription = '/api/staff/change-subscription';
  static const staffChangeSubscriptionPreview = '/api/staff/change-subscription/preview';
  static const staffWaiverTemplate = '/api/staff/waiver-template';
  static const staffOnboardClient = '/api/staff/onboard-client';
  static const staffResetMemberPassword = '/api/staff/reset-member-password';
  static const staffChangeMemberUsername = '/api/staff/change-member-username';
  static const staffCreatePaymentIntent = '/api/staff/create-payment-intent';
  static const staffOnboardingCheckoutSession = '/api/staff/onboarding-checkout-session';
  static String staffCheckoutSessionStatus(String id) => '/api/staff/checkout-session-status/$id';
  static const staffNfcTags = '/api/staff/nfc-tags';
  static const staffRegisterNfc = '/api/staff/register-nfc';
  static String staffUnregisterNfc(String id) => '/api/staff/unregister-nfc/$id';
  static const staffShowerUsage = '/api/staff/shower-usage';
  static const staffVerifyAccess = '/api/staff/verify-access';
  static String staffUploadCertificate(String id) => '/api/staff/upload-certificate/$id';
  static String staffUpdateCertificate(String id) => '/api/staff/update-certificate/$id';
  static String staffDeleteCertificate(String id) => '/api/staff/delete-certificate/$id';
  static String medicalCertificate(String clientId) => '/api/medical/certificate?client_id=$clientId';

  // ── Terminal/POS ────────────────────────────────────────
  static const terminalProcessCustomPayment = '/api/terminal/process-custom-payment';
  static String terminalPaymentStatus(String id) => '/api/terminal/payment-status/$id';
  static const terminalCancelPayment = '/api/terminal/cancel-payment';
  static const terminalSimulatePayment = '/api/terminal/simulate-payment';

  // ── Spotify ──────────────────────────────────────────────
  static const String spotifyStatus = '/api/spotify/status';
  static const String spotifyAuthorize = '/api/spotify/authorize';
  static const String spotifyRefresh = '/api/spotify/refresh';
  static const String spotifyDisconnect = '/api/spotify/disconnect';
}
