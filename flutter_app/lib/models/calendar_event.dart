class CalendarEvent {
  final int? id;
  final String date; // YYYY-MM-DD
  final String title;
  final String type; // workout, rest, course, milestone, appointment
  final bool completed;
  final String? workoutId;
  final String? details;
  final String? courseId;

  const CalendarEvent({
    this.id,
    required this.date,
    required this.title,
    required this.type,
    this.completed = false,
    this.workoutId,
    this.details,
    this.courseId,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as int?,
      date: json['date'] as String? ?? '',
      title: json['title'] as String? ?? 'Senza titolo',
      type: json['type'] as String? ?? 'event',
      completed: json['completed'] as bool? ?? false,
      workoutId: json['workout_id'] as String?,
      details: json['details'] as String?,
      courseId: json['course_id'] as String?,
    );
  }
}
