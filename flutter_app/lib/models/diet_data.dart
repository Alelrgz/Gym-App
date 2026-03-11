class MacroValue {
  final double current;
  final double target;

  const MacroValue({required this.current, required this.target});

  double get percentage => target > 0 ? (current / target).clamp(0.0, 2.0) : 0.0;
  double get remaining => (target - current).clamp(0, double.infinity);

  factory MacroValue.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MacroValue(current: 0, target: 0);
    return MacroValue(
      current: _toDouble(json['current']),
      target: _toDouble(json['target']),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}

class DietItem {
  final String meal;
  final int cals;
  final String time;

  const DietItem({required this.meal, required this.cals, required this.time});

  factory DietItem.fromJson(Map<String, dynamic> json) {
    return DietItem(
      meal: json['meal'] as String? ?? '',
      cals: (json['cals'] as num?)?.toInt() ?? 0,
      time: json['time'] as String? ?? '',
    );
  }
}

class DietProgress {
  final MacroValue calories;
  final MacroValue protein;
  final MacroValue carbs;
  final MacroValue fat;
  final MacroValue hydration;
  final List<int> weeklyHealthScores;
  final int consistencyTarget;
  final Map<String, List<DietItem>> dietLog;
  final List<String> photos;

  const DietProgress({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.hydration,
    this.weeklyHealthScores = const [],
    this.consistencyTarget = 80,
    this.dietLog = const {},
    this.photos = const [],
  });

  int get totalMealsToday =>
      dietLog.values.fold(0, (sum, meals) => sum + meals.length);

  int get totalCaloriesToday =>
      dietLog.values.fold(0, (sum, meals) =>
          sum + meals.fold(0, (s, item) => s + item.cals));

  factory DietProgress.fromJson(Map<String, dynamic>? json) {
    if (json == null) return _empty;

    final macros = json['macros'] as Map<String, dynamic>? ?? {};
    final dietLogRaw = json['diet_log'] as Map<String, dynamic>? ?? {};

    final dietLog = <String, List<DietItem>>{};
    for (final entry in dietLogRaw.entries) {
      final items = entry.value;
      if (items is List) {
        dietLog[entry.key] = items
            .whereType<Map<String, dynamic>>()
            .map((e) => DietItem.fromJson(e))
            .toList();
      }
    }

    final photosRaw = json['photos'] as List<dynamic>? ?? [];

    return DietProgress(
      calories: MacroValue.fromJson(macros['calories'] as Map<String, dynamic>?),
      protein: MacroValue.fromJson(macros['protein'] as Map<String, dynamic>?),
      carbs: MacroValue.fromJson(macros['carbs'] as Map<String, dynamic>?),
      fat: MacroValue.fromJson(macros['fat'] as Map<String, dynamic>?),
      hydration: MacroValue.fromJson(json['hydration'] as Map<String, dynamic>?),
      weeklyHealthScores: (json['weekly_health_scores'] as List<dynamic>?)
              ?.map((e) => (e as num?)?.toInt() ?? 0)
              .toList() ??
          const [],
      consistencyTarget: (json['consistency_target'] as num?)?.toInt() ?? 80,
      dietLog: dietLog,
      photos: photosRaw.whereType<String>().toList(),
    );
  }

  static const _empty = DietProgress(
    calories: MacroValue(current: 0, target: 0),
    protein: MacroValue(current: 0, target: 0),
    carbs: MacroValue(current: 0, target: 0),
    fat: MacroValue(current: 0, target: 0),
    hydration: MacroValue(current: 0, target: 0),
  );
}
