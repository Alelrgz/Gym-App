class TrainerProfile {
  final String id;
  final String name;
  final String? profilePicture;
  final String? bio;
  final String? specialties;
  final List<TrainerClient> clients;
  final int activeClients;
  final int atRiskClients;
  final List<TrainerEvent> schedule;
  final Map<String, dynamic>? todaysWorkout;
  final List<Map<String, dynamic>> workouts;
  final List<Map<String, dynamic>> splits;
  final int streak;

  const TrainerProfile({
    required this.id,
    required this.name,
    this.profilePicture,
    this.bio,
    this.specialties,
    this.clients = const [],
    this.activeClients = 0,
    this.atRiskClients = 0,
    this.schedule = const [],
    this.todaysWorkout,
    this.workouts = const [],
    this.splits = const [],
    this.streak = 0,
  });

  factory TrainerProfile.fromJson(Map<String, dynamic> json) {
    return TrainerProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      profilePicture: json['profile_picture'] as String?,
      bio: json['bio'] as String?,
      specialties: json['specialties'] as String?,
      clients: (json['clients'] as List<dynamic>?)
              ?.map((c) => TrainerClient.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      activeClients: json['active_clients'] as int? ?? 0,
      atRiskClients: json['at_risk_clients'] as int? ?? 0,
      schedule: (json['schedule'] as List<dynamic>?)
              ?.map((e) => TrainerEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      todaysWorkout: json['todays_workout'] as Map<String, dynamic>?,
      workouts: (json['workouts'] as List<dynamic>?)
              ?.map((w) => Map<String, dynamic>.from(w as Map))
              .toList() ??
          [],
      splits: (json['splits'] as List<dynamic>?)
              ?.map((s) => Map<String, dynamic>.from(s as Map))
              .toList() ??
          [],
      streak: json['streak'] as int? ?? 0,
    );
  }
}

class TrainerClient {
  final String id;
  final String name;
  final String status;
  final String lastSeen;
  final String plan;
  final bool isPremium;
  final String? profilePicture;
  final String? assignedSplit;
  final String? planExpiry;
  final int upcomingWorkouts;
  final double? weight;
  final double? heightCm;
  final String? gender;
  final String? fitnessGoal;

  const TrainerClient({
    required this.id,
    required this.name,
    required this.status,
    required this.lastSeen,
    required this.plan,
    this.isPremium = false,
    this.profilePicture,
    this.assignedSplit,
    this.planExpiry,
    this.upcomingWorkouts = 0,
    this.weight,
    this.heightCm,
    this.gender,
    this.fitnessGoal,
  });

  factory TrainerClient.fromJson(Map<String, dynamic> json) {
    return TrainerClient(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      lastSeen: json['last_seen'] as String? ?? '',
      plan: json['plan'] as String? ?? 'Nessuna scheda',
      isPremium: json['is_premium'] as bool? ?? false,
      profilePicture: json['profile_picture'] as String?,
      assignedSplit: json['assigned_split'] as String?,
      planExpiry: json['plan_expiry'] as String?,
      upcomingWorkouts: json['upcoming_workouts'] as int? ?? 0,
      weight: (json['weight'] as num?)?.toDouble(),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      gender: json['gender'] as String?,
      fitnessGoal: json['fitness_goal'] as String?,
    );
  }
}

class TrainerEvent {
  final String id;
  final String date;
  final String time;
  final String title;
  final String subtitle;
  final String type;
  final int duration;
  final bool completed;
  final String? courseId;
  final String? clientId;

  const TrainerEvent({
    required this.id,
    required this.date,
    required this.time,
    required this.title,
    required this.subtitle,
    required this.type,
    this.duration = 60,
    this.completed = false,
    this.courseId,
    this.clientId,
  });

  /// Whether this event involves other people (client appointment or course).
  bool get involvesOthers => clientId != null || courseId != null;

  factory TrainerEvent.fromJson(Map<String, dynamic> json) {
    return TrainerEvent(
      id: json['id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      type: json['type'] as String? ?? 'personal',
      duration: json['duration'] as int? ?? 60,
      completed: json['completed'] as bool? ?? false,
      courseId: json['course_id'] as String?,
      clientId: json['client_id'] as String?,
    );
  }
}
