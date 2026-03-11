import 'calendar_event.dart';
import 'diet_data.dart';

class ClientProfile {
  final String userId;
  final String? name;
  final String? email;
  final int streak;
  final int gems;
  final double? healthScore;
  final bool isPremium;
  final double? weight;
  final double? bodyFatPct;
  final String? fitnessGoal;
  final int? gymId;
  final String? gymName;
  final int? trainerId;
  final String? trainerName;
  final String? trainerBio;
  final String? trainerSpecialties;
  final String? trainerPicture;
  final int? nutritionistId;
  final String? nutritionistName;
  final double? caloriesTarget;
  final double? proteinTarget;
  final double? carbsTarget;
  final double? fatTarget;
  final String? privacyMode;
  final String? profilePicture;
  final String? bio;

  // Workout info
  final Map<String, dynamic>? todayWorkout;
  final List<dynamic>? upcomingAppointments;

  // Calendar
  final List<CalendarEvent> calendarEvents;

  // Diet / Progress
  final DietProgress? dietProgress;

  ClientProfile({
    required this.userId,
    this.name,
    this.email,
    this.streak = 0,
    this.gems = 0,
    this.healthScore,
    this.isPremium = false,
    this.weight,
    this.bodyFatPct,
    this.fitnessGoal,
    this.gymId,
    this.gymName,
    this.trainerId,
    this.trainerName,
    this.trainerBio,
    this.trainerSpecialties,
    this.trainerPicture,
    this.nutritionistId,
    this.nutritionistName,
    this.caloriesTarget,
    this.proteinTarget,
    this.carbsTarget,
    this.fatTarget,
    this.privacyMode,
    this.profilePicture,
    this.bio,
    this.todayWorkout,
    this.upcomingAppointments,
    this.calendarEvents = const [],
    this.dietProgress,
  });

  factory ClientProfile.fromJson(Map<String, dynamic> json) {
    // The /api/client/data endpoint returns nested data
    final profile = json['profile'] as Map<String, dynamic>? ?? json;
    final trainer = json['trainer'] as Map<String, dynamic>?;
    final gym = json['gym'] as Map<String, dynamic>?;
    final nutritionist = json['nutritionist'] as Map<String, dynamic>?;

    return ClientProfile(
      userId: (profile['user_id'] ?? json['user_id'] ?? '').toString(),
      name: profile['name'] as String? ?? json['name'] as String?,
      email: profile['email'] as String? ?? json['email'] as String?,
      streak: profile['streak'] as int? ?? json['streak'] as int? ?? 0,
      gems: profile['gems'] as int? ?? json['gems'] as int? ?? 0,
      healthScore: _toDouble(profile['health_score'] ?? json['health_score']),
      isPremium: profile['is_premium'] as bool? ?? json['is_premium'] as bool? ?? false,
      weight: _toDouble(profile['weight'] ?? json['weight']),
      bodyFatPct: _toDouble(profile['body_fat_pct'] ?? json['body_fat_pct']),
      fitnessGoal: profile['fitness_goal'] as String? ?? json['fitness_goal'] as String?,
      gymId: gym?['id'] as int? ?? profile['gym_id'] as int?,
      gymName: gym?['name'] as String? ?? json['gym_name'] as String?,
      trainerId: trainer?['id'] as int? ?? profile['trainer_id'] as int?,
      trainerName: trainer?['name'] as String? ?? json['trainer_name'] as String?,
      trainerBio: trainer?['bio'] as String?,
      trainerSpecialties: trainer?['specialties'] as String?,
      trainerPicture: trainer?['profile_picture'] as String?,
      nutritionistId: nutritionist?['id'] as int?,
      nutritionistName: nutritionist?['name'] as String?,
      caloriesTarget: _toDouble(profile['calories_target'] ?? json['calories_target']),
      proteinTarget: _toDouble(profile['protein_target'] ?? json['protein_target']),
      carbsTarget: _toDouble(profile['carbs_target'] ?? json['carbs_target']),
      fatTarget: _toDouble(profile['fat_target'] ?? json['fat_target']),
      privacyMode: profile['privacy_mode'] as String? ?? json['privacy_mode'] as String?,
      profilePicture: profile['profile_picture'] as String? ?? json['profile_picture'] as String?,
      bio: profile['bio'] as String? ?? json['bio'] as String?,
      todayWorkout: json['todays_workout'] as Map<String, dynamic>?,
      upcomingAppointments: json['upcoming_appointments'] as List<dynamic>?,
      calendarEvents: _parseCalendarEvents(json),
      dietProgress: DietProgress.fromJson(json['progress'] as Map<String, dynamic>?),
    );
  }

  static List<CalendarEvent> _parseCalendarEvents(Map<String, dynamic> json) {
    final calendar = json['calendar'] as Map<String, dynamic>?;
    if (calendar == null) return const [];
    final events = calendar['events'] as List<dynamic>?;
    if (events == null) return const [];
    return events
        .whereType<Map<String, dynamic>>()
        .map((e) => CalendarEvent.fromJson(e))
        .toList();
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
