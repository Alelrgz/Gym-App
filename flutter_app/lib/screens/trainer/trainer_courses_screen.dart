import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trainer_provider.dart';
import '../../utils/web_helper.dart' as web_helper;
import '../../widgets/glass_card.dart';

// ═══════════════════════════════════════════════════════════
//  COURSE TYPE DEFINITIONS
// ═══════════════════════════════════════════════════════════

class _CourseType {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final Color gradientEnd;

  const _CourseType({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.gradientEnd,
  });
}

const _courseTypes = [
  _CourseType(key: 'yoga', label: 'Yoga', icon: Icons.favorite_rounded, color: Color(0xFF9333EA), gradientEnd: Color(0xFFEC4899)),
  _CourseType(key: 'pilates', label: 'Pilates', icon: Icons.accessibility_new_rounded, color: Color(0xFFEC4899), gradientEnd: Color(0xFFF43F5E)),
  _CourseType(key: 'hiit', label: 'HIIT', icon: Icons.local_fire_department_rounded, color: Color(0xFFF97316), gradientEnd: Color(0xFFEF4444)),
  _CourseType(key: 'dance', label: 'Dance', icon: Icons.music_note_rounded, color: Color(0xFF06B6D4), gradientEnd: Color(0xFF3B82F6)),
  _CourseType(key: 'spin', label: 'Spinning', icon: Icons.directions_bike_rounded, color: Color(0xFF22C55E), gradientEnd: Color(0xFF10B981)),
  _CourseType(key: 'strength', label: 'Forza', icon: Icons.fitness_center_rounded, color: Color(0xFFEF4444), gradientEnd: Color(0xFFF97316)),
  _CourseType(key: 'stretch', label: 'Stretching', icon: Icons.self_improvement_rounded, color: Color(0xFF14B8A6), gradientEnd: Color(0xFF06B6D4)),
  _CourseType(key: 'cardio', label: 'Cardio', icon: Icons.directions_run_rounded, color: Color(0xFFEAB308), gradientEnd: Color(0xFFF97316)),
];

// Exercise library category filters
const _exCategories = [
  ('all', 'Tutti'),
  ('yoga', 'Yoga'),
  ('pilates', 'Pilates'),
  ('stretch', 'Stretch'),
  ('cardio', 'Cardio'),
  ('warmup', 'Warmup'),
  ('cooldown', 'Cooldown'),
];

_CourseType _getType(String? key) =>
    _courseTypes.firstWhere((t) => t.key == key, orElse: () => _courseTypes[0]);

const _dayLabels = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
const _dayLabelsFull = ['Lunedi', 'Martedi', 'Mercoledi', 'Giovedi', 'Venerdi', 'Sabato', 'Domenica'];

const double _kDesktopBreakpoint = 900;

// ═══════════════════════════════════════════════════════════
//  MAIN SCREEN
// ═══════════════════════════════════════════════════════════

class TrainerCoursesScreen extends ConsumerStatefulWidget {
  const TrainerCoursesScreen({super.key});

  @override
  ConsumerState<TrainerCoursesScreen> createState() => _TrainerCoursesScreenState();
}

class _TrainerCoursesScreenState extends ConsumerState<TrainerCoursesScreen> {
  String _search = '';
  int _courseTab = 0; // 0 = my courses, 1 = shared
  int _mobilePanel = 0; // 0 = courses, 1 = participants, 2 = exercises
  String? _selectedCourseId;
  String _exFilter = 'all';
  String _exSearch = '';

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(trainerCoursesProvider);
    final exercisesAsync = ref.watch(courseExercisesProvider);
    final isDesktop = MediaQuery.of(context).size.width > _kDesktopBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Errore: $e', style: TextStyle(color: Colors.grey[500]))),
        data: (courses) => _buildPage(courses, exercisesAsync, isDesktop),
      ),
    );
  }

  Widget _buildPage(List<Map<String, dynamic>> courses, AsyncValue<List<Map<String, dynamic>>> exercisesAsync, bool isDesktop) {
    // "I miei corsi" = courses you own, "Corsi condivisi" = shared courses from other trainers
    final currentUserId = ref.read(authProvider).user?.id;
    final myCourses = courses.where((c) => c['owner_id'] == currentUserId).toList();
    final sharedCourses = courses.where((c) => c['is_shared'] == true && c['owner_id'] != currentUserId).toList();
    final activeCourses = _courseTab == 0 ? myCourses : sharedCourses;

    // Filter by search
    final filtered = activeCourses.where((c) {
      if (_search.isEmpty) return true;
      return (c['name'] as String? ?? '').toLowerCase().contains(_search.toLowerCase());
    }).toList();

    // Weekly lessons count
    int weeklyLessons = 0;
    for (final c in courses) {
      final days = c['days_of_week'];
      if (days is List) {
        weeklyLessons += days.length;
      } else if (c['day_of_week'] != null) {
        weeklyLessons += 1;
      }
    }

    return Column(
      children: [
        // ── Header ──────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 20, isDesktop ? 24 : 16, isDesktop ? 24 : 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop) ...[
                const Text('Corsi', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('Gestisci i tuoi corsi di gruppo', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                const SizedBox(height: 16),
              ],
              // Stats row + Create button
              Row(
                children: [
                  // Stats pills
                  _StatPill(
                    value: '${courses.length}',
                    label: 'Corsi',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _StatPill(
                    value: '$weeklyLessons',
                    label: 'Questa settimana',
                    color: const Color(0xFF3B82F6),
                    icon: Icons.calendar_today_rounded,
                  ),
                  const Spacer(),
                  // Create button
                  GestureDetector(
                    onTap: _openCreateCourseModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Crea corso',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // ── Mobile panel tabs (only on mobile) ──────────
        if (!isDesktop) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  _PanelTab(label: 'Corsi', isActive: _mobilePanel == 0, onTap: () => setState(() => _mobilePanel = 0)),
                  _PanelTab(label: 'Partecipanti', isActive: _mobilePanel == 1, onTap: () => setState(() => _mobilePanel = 1)),
                  _PanelTab(label: 'Esercizi', isActive: _mobilePanel == 2, onTap: () => setState(() => _mobilePanel = 2)),
                ],
              ),
            ),
          ),
        ],

        // ── Main content ────────────────────────────────
        Expanded(
          child: isDesktop
              ? _buildDesktopGrid(filtered, courses, sharedCourses, exercisesAsync, courses)
              : _buildMobilePanel(filtered, courses, sharedCourses, exercisesAsync, courses),
        ),
      ],
    );
  }

  // ── Desktop: 3-panel grid ───────────────────────────────
  Widget _buildDesktopGrid(
    List<Map<String, dynamic>> filtered,
    List<Map<String, dynamic>> courses,
    List<Map<String, dynamic>> sharedCourses,
    AsyncValue<List<Map<String, dynamic>>> exercisesAsync,
    List<Map<String, dynamic>> allCourses,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left panel: courses (1.2fr)
          Expanded(
            flex: 12,
            child: _buildCoursesPanel(filtered, courses, sharedCourses),
          ),
          const SizedBox(width: 16),
          // Middle panel: participants (1fr)
          Expanded(
            flex: 10,
            child: _buildParticipantsPanel(allCourses),
          ),
          const SizedBox(width: 16),
          // Right panel: exercise library (1fr)
          Expanded(
            flex: 10,
            child: _buildExerciseLibraryPanel(exercisesAsync),
          ),
        ],
      ),
    );
  }

  // ── Mobile: single panel ────────────────────────────────
  Widget _buildMobilePanel(
    List<Map<String, dynamic>> filtered,
    List<Map<String, dynamic>> courses,
    List<Map<String, dynamic>> sharedCourses,
    AsyncValue<List<Map<String, dynamic>>> exercisesAsync,
    List<Map<String, dynamic>> allCourses,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          border: Border(
            left: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: switch (_mobilePanel) {
          0 => _buildCoursesPanel(filtered, courses, sharedCourses),
          1 => _buildParticipantsPanel(allCourses),
          2 => _buildExerciseLibraryPanel(ref.watch(courseExercisesProvider)),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  LEFT PANEL: COURSES LIST
  // ═══════════════════════════════════════════════════════════

  Widget _buildCoursesPanel(
    List<Map<String, dynamic>> filtered,
    List<Map<String, dynamic>> courses,
    List<Map<String, dynamic>> sharedCourses,
  ) {
    return Column(
      children: [
        // Tab bar: I miei corsi | Corsi condivisi
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _courseTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: _courseTab == 0 ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'I miei corsi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _courseTab == 0 ? Colors.white : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _courseTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: _courseTab == 1 ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Corsi condivisi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _courseTab == 1 ? Colors.white : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Course list
        Expanded(
          child: _buildCourseList(filtered),
        ),
      ],
    );
  }

  Widget _buildCourseList(List<Map<String, dynamic>> filtered) {
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.school_rounded, size: 48, color: Colors.grey[700]),
              const SizedBox(height: 10),
              Text(
                _courseTab == 0 ? 'Nessun corso creato' : 'Nessun corso condiviso',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    // Group by type
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final c in filtered) {
      final type = c['course_type'] as String? ?? 'yoga';
      grouped.putIfAbsent(type, () => []).add(c);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final entry in grouped.entries) ...[
          // Type section header
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Row(
              children: [
                Icon(_getType(entry.key).icon, size: 18, color: _getType(entry.key).color.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                Text(
                  _getType(entry.key).label.toUpperCase(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8), letterSpacing: 0.8),
                ),
                const SizedBox(width: 6),
                Text('(${entry.value.length})', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
              ],
            ),
          ),
          // Course cards
          ...entry.value.map((course) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CourseCard(
              course: course,
              isOwner: _courseTab == 0,
              isSelected: course['id'].toString() == _selectedCourseId,
              onTap: () => setState(() => _selectedCourseId = course['id'].toString()),
              onSchedule: () => _openScheduleLessonModal(course),
              onEdit: () => _openEditCourseModal(course),
              onDelete: () => _deleteCourse(course),
              onDetail: () => _openCourseDetail(course),
            ),
          )),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  MIDDLE PANEL: PARTICIPANTS
  // ═══════════════════════════════════════════════════════════

  Widget _buildParticipantsPanel(List<Map<String, dynamic>> allCourses) {
    return Column(
      children: [
        // Panel header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
          ),
          child: Row(
            children: [
              Text(
                'PARTECIPANTI',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0.5),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _selectedCourseId == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Seleziona un corso', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.25))),
                        const SizedBox(height: 4),
                        Text('per vedere i partecipanti', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.2))),
                      ],
                    ),
                  ),
                )
              : _buildParticipantsList(allCourses),
        ),
      ],
    );
  }

  Widget _buildParticipantsList(List<Map<String, dynamic>> allCourses) {
    final course = allCourses.firstWhere(
      (c) => c['id'].toString() == _selectedCourseId,
      orElse: () => <String, dynamic>{},
    );
    if (course.isEmpty) {
      return Center(child: Text('Corso non trovato', style: TextStyle(fontSize: 13, color: Colors.grey[500])));
    }

    final participants = course['participants'] as List? ?? [];
    final courseName = course['name'] as String? ?? '';

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Course name header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(courseName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ),
        if (participants.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text('Nessun partecipante iscritto', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
          )
        else
          ...participants.map((p) {
            final participant = p is Map ? p : {};
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    child: Text(
                      (participant['name'] as String? ?? '?')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      participant['name'] as String? ?? 'Utente',
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  RIGHT PANEL: EXERCISE LIBRARY
  // ═══════════════════════════════════════════════════════════

  Widget _buildExerciseLibraryPanel(AsyncValue<List<Map<String, dynamic>>> exercisesAsync) {
    return Column(
      children: [
        // Panel header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
          ),
          child: Row(
            children: [
              Text(
                'LIBRERIA ESERCIZI',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0.5),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  // TODO: open create exercise modal
                },
                child: const Text(
                  '+ Nuovo',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),

        // Category filter pills
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _exCategories.map((cat) {
              final isActive = _exFilter == cat.$1;
              return GestureDetector(
                onTap: () => setState(() => _exFilter = cat.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isActive ? AppColors.primary.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    cat.$2,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppColors.primary : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Search input
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _exSearch = v),
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Cerca esercizi...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.3)),
                prefixIcon: Icon(Icons.search_rounded, size: 16, color: Colors.white.withValues(alpha: 0.3)),
                prefixIconConstraints: const BoxConstraints(minWidth: 36),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),

        // Exercise grid
        Expanded(
          child: exercisesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Errore', style: TextStyle(fontSize: 12, color: Colors.grey[500]))),
            data: (exercises) {
              var filtered = exercises.where((ex) {
                // Filter by category
                if (_exFilter != 'all') {
                  final group = (ex['muscle_group'] as String? ?? '').toLowerCase();
                  if (group != _exFilter) return false;
                }
                // Filter by search
                if (_exSearch.isNotEmpty) {
                  final name = (ex['name'] as String? ?? '').toLowerCase();
                  if (!name.contains(_exSearch.toLowerCase())) return false;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text('Nessun esercizio trovato', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) => _ExerciseLibraryCard(exercise: filtered[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── CRUD Actions ───────────────────────────────────────

  void _openCreateCourseModal() {
    final exercises = ref.read(courseExercisesProvider).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CourseFormModal(
        availableExercises: exercises,
        onSave: (data) async {
          await ref.read(trainerServiceProvider).createCourse(data);
          ref.invalidate(trainerCoursesProvider);
        },
      ),
    );
  }

  void _openEditCourseModal(Map<String, dynamic> course) {
    final exercises = ref.read(courseExercisesProvider).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CourseFormModal(
        course: course,
        availableExercises: exercises,
        onSave: (data) async {
          await ref.read(trainerServiceProvider).updateCourse(course['id'].toString(), data);
          ref.invalidate(trainerCoursesProvider);
        },
      ),
    );
  }

  Future<void> _deleteCourse(Map<String, dynamic> course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Elimina Corso', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Eliminare "${course['name']}"? Questa azione non puo essere annullata.', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(trainerServiceProvider).deleteCourse(course['id'].toString());
        ref.invalidate(trainerCoursesProvider);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  void _openCourseDetail(Map<String, dynamic> course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CourseDetailModal(
        course: course,
        service: ref.read(trainerServiceProvider),
        onRefresh: () => ref.invalidate(trainerCoursesProvider),
        onEdit: () {
          Navigator.pop(ctx);
          _openEditCourseModal(course);
        },
      ),
    );
  }

  void _openScheduleLessonModal(Map<String, dynamic> course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _ScheduleLessonModal(
        course: course,
        onSchedule: (data) async {
          await ref.read(trainerServiceProvider).scheduleLesson(course['id'].toString(), data);
          ref.invalidate(trainerCoursesProvider);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  STAT PILL (inline badge)
// ═══════════════════════════════════════════════════════════

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData? icon;

  const _StatPill({required this.value, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  PANEL TAB (mobile)
// ═══════════════════════════════════════════════════════════

class _PanelTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _PanelTab({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? AppColors.primary : Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  COURSE CARD (webapp-style)
// ═══════════════════════════════════════════════════════════

class _CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final bool isOwner;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onSchedule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDetail;

  const _CourseCard({
    required this.course,
    required this.isOwner,
    required this.isSelected,
    required this.onTap,
    required this.onSchedule,
    required this.onEdit,
    required this.onDelete,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final name = course['name'] as String? ?? '';
    final desc = course['description'] as String? ?? '';
    final timeSlot = course['time_slot'] as String? ?? '';
    final duration = course['duration'] as int? ?? 60;
    final exercises = course['exercises'] as List? ?? [];
    final musicLinks = course['music_links'] as List? ?? [];
    final daysOfWeek = course['days_of_week'] as List?;
    final dayOfWeek = course['day_of_week'] as int?;
    final isShared = course['is_shared'] as bool? ?? false;

    // Schedule text
    String scheduleText = 'Non programmato';
    if (daysOfWeek != null && daysOfWeek.isNotEmpty) {
      final dayNames = daysOfWeek.map((d) => _dayLabelsFull[(d as int) % 7]).join(', ');
      scheduleText = timeSlot.isNotEmpty ? '$dayNames @ $timeSlot' : dayNames;
    } else if (dayOfWeek != null) {
      scheduleText = timeSlot.isNotEmpty
          ? '${_dayLabelsFull[dayOfWeek % 7]} @ $timeSlot'
          : _dayLabelsFull[dayOfWeek % 7];
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: name + shared badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(scheduleText, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                if (isShared)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'CONDIVISO',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.3),
                    ),
                  ),
              ],
            ),

            // Description
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],

            // Metadata tags
            const SizedBox(height: 10),
            Row(
              children: [
                _MetaTag(icon: Icons.timer_outlined, text: '$duration min'),
                const SizedBox(width: 12),
                _MetaTag(icon: Icons.fitness_center_rounded, text: '${exercises.length} esercizi'),
                const SizedBox(width: 12),
                _MetaTag(icon: Icons.music_note_rounded, text: '${musicLinks.length} playlist'),
              ],
            ),

            // Action buttons
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              child: isOwner
                  ? Row(
                      children: [
                        // Programma Lezione (primary, flex-1)
                        Expanded(
                          child: GestureDetector(
                            onTap: onSchedule,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Programma Lezione',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Modifica
                        GestureDetector(
                          onTap: onEdit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Modifica',
                              style: TextStyle(fontSize: 11, color: Colors.grey[300]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Elimina
                        GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Elimina',
                              style: TextStyle(fontSize: 11, color: Color(0xFFF87171)),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: onDetail,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Dettagli',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  METADATA TAG (small icon + text)
// ═══════════════════════════════════════════════════════════

class _MetaTag extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaTag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  EXERCISE LIBRARY CARD
// ═══════════════════════════════════════════════════════════

class _ExerciseLibraryCard extends StatelessWidget {
  final Map<String, dynamic> exercise;

  const _ExerciseLibraryCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final name = exercise['name'] as String? ?? '';
    final category = exercise['muscle_group'] as String? ?? 'general';
    final duration = exercise['default_duration'] as int?;
    final thumbnailUrl = exercise['thumbnail_url'] as String?;

    // Category info
    final catType = _courseTypes.where((t) => t.key == category.toLowerCase()).firstOrNull;
    final catLabel = catType?.label ?? category;
    final catIcon = catType?.icon ?? Icons.fitness_center_rounded;

    final durationText = duration != null ? '${duration}s' : 'No timer';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail area
          Container(
            width: double.infinity,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(thumbnailUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Icon(catIcon, size: 28, color: Colors.white.withValues(alpha: 0.3)))),
                  )
                : Center(child: Icon(catIcon, size: 28, color: Colors.white.withValues(alpha: 0.3))),
          ),
          const SizedBox(height: 8),
          // Name
          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          // Category + duration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(catLabel, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.6))),
              ),
              Text(durationText, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.4))),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  CREATE / EDIT COURSE FORM MODAL
// ═══════════════════════════════════════════════════════════

class _CourseFormModal extends StatefulWidget {
  final Map<String, dynamic>? course;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final List<Map<String, dynamic>> availableExercises;

  const _CourseFormModal({this.course, required this.onSave, this.availableExercises = const []});

  @override
  State<_CourseFormModal> createState() => _CourseFormModalState();
}

class _CourseFormModalState extends State<_CourseFormModal> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _timeCtrl;
  late final TextEditingController _trailerCtrl;

  late String _courseType;
  late List<int> _selectedDays;
  late int _duration;
  late bool _isShared;
  late int? _maxCapacity;
  late bool _waitlistEnabled;
  late List<Map<String, dynamic>> _musicLinks;
  late List<Map<String, dynamic>> _exercises;
  bool _isSaving = false;

  bool get _isEditing => widget.course != null;

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _nameCtrl = TextEditingController(text: c?['name'] as String? ?? '');
    _descCtrl = TextEditingController(text: c?['description'] as String? ?? '');
    _timeCtrl = TextEditingController(text: c?['time_slot'] as String? ?? '09:00');
    _trailerCtrl = TextEditingController(text: c?['trailer_url'] as String? ?? '');
    _courseType = c?['course_type'] as String? ?? 'yoga';

    if (c?['days_of_week'] is List) {
      _selectedDays = List<int>.from(c!['days_of_week'] as List);
    } else if (c?['day_of_week'] != null) {
      _selectedDays = [c!['day_of_week'] as int];
    } else {
      _selectedDays = [];
    }

    _duration = c?['duration'] as int? ?? 60;
    _isShared = c?['is_shared'] as bool? ?? false;
    _maxCapacity = c?['max_capacity'] as int?;
    _waitlistEnabled = c?['waitlist_enabled'] as bool? ?? true;

    if (c?['music_links'] is List) {
      _musicLinks = (c!['music_links'] as List).map((m) => Map<String, dynamic>.from(m as Map)).toList();
    } else {
      _musicLinks = [];
    }

    if (c?['exercises'] is List) {
      _exercises = (c!['exercises'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else {
      _exercises = [];
    }

    // Rebuild when name changes so the save button enables/disables
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _timeCtrl.dispose();
    _trailerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = _getType(_courseType);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header with gradient
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [type.color.withValues(alpha: 0.2), type.gradientEnd.withValues(alpha: 0.08)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(type.icon, color: type.color, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      _isEditing ? 'Modifica Corso' : 'Crea Nuovo Corso',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Course Type Selector ───────────────
                  const Text('Tipo di Corso', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _courseTypes.map((t) {
                      final isSelected = t.key == _courseType;
                      return GestureDetector(
                        onTap: () => setState(() => _courseType = t.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? t.color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSelected ? t.color.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(t.icon, size: 14, color: isSelected ? t.color : Colors.grey[500]),
                              const SizedBox(width: 5),
                              Text(t.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? t.color : Colors.grey[500])),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── Name ───────────────────────────────
                  _FormField(controller: _nameCtrl, label: 'Nome Corso', hint: 'es. Yoga Mattutino'),
                  const SizedBox(height: 12),

                  // ── Description ────────────────────────
                  _FormField(controller: _descCtrl, label: 'Descrizione', hint: 'Cosa sperimenteranno i partecipanti?', maxLines: 2),
                  const SizedBox(height: 20),

                  // ── Schedule Section ───────────────────
                  _SectionBox(
                    title: 'Programmazione',
                    icon: Icons.calendar_month_rounded,
                    children: [
                      const Text('Giorni della Settimana', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(7, (i) {
                          final isSelected = _selectedDays.contains(i);
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedDays.remove(i);
                                  } else {
                                    _selectedDays.add(i);
                                  }
                                });
                              },
                              child: Container(
                                margin: EdgeInsets.only(right: i < 6 ? 4 : 0),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFEF4444) : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isSelected ? const Color(0xFFEF4444) : Colors.white.withValues(alpha: 0.08)),
                                ),
                                child: Center(
                                  child: Text(
                                    _dayLabels[i][0],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.white : Colors.grey[500],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Orario', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: TextField(
                                    controller: _timeCtrl,
                                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      hintText: '09:00',
                                      hintStyle: TextStyle(color: Color(0xFF6B7280)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Durata', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => setState(() => _duration = (_duration - 15).clamp(15, 180)),
                                        child: Container(
                                          width: 36, height: 44,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.06),
                                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                                          ),
                                          child: const Icon(Icons.remove, size: 16, color: Colors.white),
                                        ),
                                      ),
                                      Expanded(
                                        child: Center(
                                          child: Text('$_duration min', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(() => _duration = (_duration + 15).clamp(15, 180)),
                                        child: Container(
                                          width: 36, height: 44,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.06),
                                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                          ),
                                          child: const Icon(Icons.add, size: 16, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Visibility Toggle ──────────────────
                  _SectionBox(
                    title: _isShared ? 'Condiviso con la Palestra' : 'Corso Privato',
                    icon: _isShared ? Icons.people_rounded : Icons.lock_rounded,
                    trailing: Switch(
                      value: _isShared,
                      onChanged: (v) => setState(() => _isShared = v),
                      activeColor: const Color(0xFF22C55E),
                    ),
                    children: [
                      Text(
                        _isShared ? 'Gli altri trainer possono vederlo' : 'Visibile solo a te',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Capacity & Waitlist ────────────────
                  _SectionBox(
                    title: 'Capacita e Lista d\'Attesa',
                    icon: Icons.group_rounded,
                    children: [
                      Row(
                        children: [
                          const Text('Posti massimi', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _maxCapacity = _maxCapacity == null ? 20 : null),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _maxCapacity == null ? const Color(0xFF22C55E).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _maxCapacity == null ? 'Illimitato' : 'Limitato',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _maxCapacity == null ? const Color(0xFF22C55E) : Colors.grey[500]),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_maxCapacity != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _maxCapacity = ((_maxCapacity ?? 20) - 5).clamp(1, 500)),
                                child: Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                                  ),
                                  child: const Icon(Icons.remove, size: 16, color: Colors.white),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text('$_maxCapacity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _maxCapacity = ((_maxCapacity ?? 20) + 5).clamp(1, 500)),
                                child: Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                  ),
                                  child: const Icon(Icons.add, size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('Lista d\'attesa', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const Spacer(),
                          Switch(
                            value: _waitlistEnabled,
                            onChanged: (v) => setState(() => _waitlistEnabled = v),
                            activeColor: const Color(0xFF22C55E),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Music Playlists ────────────────────
                  _SectionBox(
                    title: 'Playlists Musicali',
                    icon: Icons.music_note_rounded,
                    trailing: GestureDetector(
                      onTap: () => setState(() => _musicLinks.add({'title': '', 'url': '', 'type': 'spotify'})),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: type.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('+ Aggiungi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: type.color)),
                      ),
                    ),
                    children: [
                      if (_musicLinks.isEmpty)
                        Text('Nessuna playlist aggiunta', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ..._musicLinks.asMap().entries.map((entry) {
                        final i = entry.key;
                        final ml = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      color: ml['type'] == 'spotify' ? const Color(0xFF1DB954) : const Color(0xFFFF0000),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SizedBox(
                                      height: 36,
                                      child: TextField(
                                        controller: TextEditingController(text: ml['title'] as String? ?? ''),
                                        onChanged: (v) => _musicLinks[i]['title'] = v,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                        decoration: const InputDecoration(hintText: 'Titolo playlist', hintStyle: TextStyle(fontSize: 12, color: Color(0xFF6B7280)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => _musicLinks[i]['type'] = ml['type'] == 'spotify' ? 'youtube' : 'spotify'),
                                    child: Text(ml['type'] == 'spotify' ? 'Spotify' : 'YouTube', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ml['type'] == 'spotify' ? const Color(0xFF1DB954) : const Color(0xFFFF0000))),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => setState(() => _musicLinks.removeAt(i)),
                                    child: Icon(Icons.close_rounded, size: 16, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: TextEditingController(text: ml['url'] as String? ?? ''),
                                  onChanged: (v) => _musicLinks[i]['url'] = v,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                  decoration: const InputDecoration(hintText: 'URL', hintStyle: TextStyle(fontSize: 12, color: Color(0xFF6B7280)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Exercises ──────────────────────────
                  _SectionBox(
                    title: 'Esercizi',
                    icon: Icons.fitness_center_rounded,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: type.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${_exercises.length} selezionati', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: type.color)),
                    ),
                    children: [
                      if (_exercises.isEmpty)
                        Text('Nessun esercizio aggiunto', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ..._exercises.asMap().entries.map((entry) {
                        final i = entry.key;
                        final ex = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(color: type.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: type.color))),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(ex['name'] as String? ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
                              GestureDetector(
                                onTap: () => setState(() => _exercises.removeAt(i)),
                                child: Icon(Icons.close_rounded, size: 14, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      // ── Gestisci Esercizi Button ──
                      GestureDetector(
                        onTap: () => _openExercisePicker(type),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              type.color.withValues(alpha: 0.15),
                              type.gradientEnd.withValues(alpha: 0.15),
                            ]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: type.color.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_rounded, size: 18, color: type.color),
                              const SizedBox(width: 6),
                              Text('Gestisci Esercizi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: type.color)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Trailer URL ────────────────────────
                  _FormField(controller: _trailerCtrl, label: 'Trailer Video URL', hint: 'YouTube o Vimeo URL (opzionale)'),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Save button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: type.color,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: type.color.withValues(alpha: 0.3),
                ),
                onPressed: _isSaving || _nameCtrl.text.isEmpty ? null : _save,
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        _isEditing ? 'SALVA MODIFICHE' : 'CREA CORSO',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openExercisePicker(_CourseType type) async {
    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _ExercisePickerDialog(
        courseType: _courseType,
        type: type,
        initialExercises: List<Map<String, dynamic>>.from(_exercises),
        availableExercises: widget.availableExercises,
      ),
    );
    if (result != null) {
      setState(() => _exercises = result);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final data = <String, dynamic>{
        'name': _nameCtrl.text,
        'description': _descCtrl.text,
        'course_type': _courseType,
        'days_of_week': _selectedDays,
        'time_slot': _timeCtrl.text,
        'duration': _duration,
        'is_shared': _isShared,
        'max_capacity': _maxCapacity,
        'waitlist_enabled': _waitlistEnabled,
        'music_links': _musicLinks,
        'exercises': _exercises,
        if (_trailerCtrl.text.isNotEmpty) 'trailer_url': _trailerCtrl.text,
      };
      await widget.onSave(data);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  EXERCISE PICKER DIALOG (Two-panel: Library + Drag-and-Drop)
// ═══════════════════════════════════════════════════════════

class _ExercisePickerDialog extends StatefulWidget {
  final String courseType;
  final _CourseType type;
  final List<Map<String, dynamic>> initialExercises;
  final List<Map<String, dynamic>> availableExercises;

  const _ExercisePickerDialog({
    required this.courseType,
    required this.type,
    required this.initialExercises,
    required this.availableExercises,
  });

  @override
  State<_ExercisePickerDialog> createState() => _ExercisePickerDialogState();
}

class _ExercisePickerDialogState extends State<_ExercisePickerDialog> {
  late List<Map<String, dynamic>> _selected;
  late List<Map<String, dynamic>> _library;
  String _search = '';
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _selected = List<Map<String, dynamic>>.from(widget.initialExercises);
    _library = widget.availableExercises;
  }

  List<Map<String, dynamic>> get _filteredLibrary {
    return _library.where((ex) {
      if (_filter != 'all') {
        final group = (ex['muscle_group'] as String? ?? '').toLowerCase();
        if (group != _filter) return false;
      }
      if (_search.isNotEmpty) {
        final name = (ex['name'] as String? ?? '').toLowerCase();
        if (!name.contains(_search.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  void _addExercise(Map<String, dynamic> ex) {
    setState(() {
      _selected.add({
        'name': ex['name'],
        'sets': 3,
        'reps': 10,
        'duration': 60,
        'video_id': ex['video_id'] ?? '',
      });
    });
  }

  void _removeExercise(int index) {
    setState(() => _selected.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: isDesktop ? 700 : double.infinity,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: Row(
                children: [
                  Icon(Icons.fitness_center_rounded, size: 20, color: type.color),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Gestisci Esercizi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: type.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: Text('${_selected.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: type.color)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

            // ── Body (two panels) ──
            Expanded(
              child: isDesktop
                  ? Row(
                      children: [
                        Expanded(child: _buildLibraryPanel(type)),
                        Container(width: 1, color: Colors.white.withValues(alpha: 0.08)),
                        Expanded(child: _buildSelectedPanel(type)),
                      ],
                    )
                  : Column(
                      children: [
                        // Mobile: tabs
                        _MobilePickerTabs(
                          selectedCount: _selected.length,
                          type: type,
                          onLibrary: () => setState(() {}),
                          onSelected: () => setState(() {}),
                        ),
                        Expanded(child: _buildLibraryPanel(type)),
                      ],
                    ),
            ),

            // ── Footer ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: type.color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context, _selected),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('Conferma (${_selected.length})', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryPanel(_CourseType type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Text('LIBRERIA ESERCIZI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[600], letterSpacing: 0.5)),
        ),
        // Category filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: _exCategories.map((cat) {
              final isActive = _filter == cat.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _filter = cat.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isActive ? type.color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: isActive ? type.color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(cat.$2, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isActive ? type.color : Colors.white.withValues(alpha: 0.6))),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Cerca...',
                hintStyle: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3)),
                prefixIcon: Icon(Icons.search_rounded, size: 16, color: Colors.white.withValues(alpha: 0.3)),
                prefixIconConstraints: const BoxConstraints(minWidth: 36),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        // Exercise list
        Expanded(
          child: _filteredLibrary.isEmpty
                  ? Center(child: Text('Nessun esercizio trovato', style: TextStyle(fontSize: 12, color: Colors.grey[600])))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: _filteredLibrary.length,
                      itemBuilder: (ctx, i) {
                        final ex = _filteredLibrary[i];
                        return GestureDetector(
                          onTap: () => _addExercise(ex),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(ex['name'] as String? ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                      Text(ex['muscle_group'] as String? ?? '', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                                Icon(Icons.add_circle_outline_rounded, size: 20, color: type.color),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSelectedPanel(_CourseType type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: [
              Text('ESERCIZI SELEZIONATI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[600], letterSpacing: 0.5)),
              const Spacer(),
              Text('Trascina per riordinare', style: TextStyle(fontSize: 9, color: Colors.grey[700])),
            ],
          ),
        ),
        Expanded(
          child: _selected.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 24, color: Colors.white.withValues(alpha: 0.1)),
                      const SizedBox(height: 8),
                      Text('Seleziona esercizi dalla libreria', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: _selected.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _selected.removeAt(oldIndex);
                      _selected.insert(newIndex, item);
                    });
                  },
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      color: Colors.transparent,
                      elevation: 6,
                      shadowColor: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                      child: child,
                    );
                  },
                  itemBuilder: (ctx, i) {
                    final ex = _selected[i];
                    return Container(
                      key: ValueKey('exercise_${i}_${ex['name']}'),
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Drag handle
                              Icon(Icons.drag_indicator_rounded, size: 18, color: Colors.white.withValues(alpha: 0.2)),
                              const SizedBox(width: 6),
                              // Number
                              Container(
                                width: 20, height: 20,
                                decoration: BoxDecoration(color: type.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(5)),
                                child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: type.color))),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(ex['name'] as String? ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                              GestureDetector(
                                onTap: () => _removeExercise(i),
                                child: Icon(Icons.close_rounded, size: 16, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Sets / Reps / Duration inputs
                          Row(
                            children: [
                              const SizedBox(width: 44), // align with name
                              _MiniInput(label: 'Sets', value: '${ex['sets'] ?? 3}', onChanged: (v) => setState(() => ex['sets'] = int.tryParse(v) ?? 3)),
                              const SizedBox(width: 8),
                              _MiniInput(label: 'Reps', value: '${ex['reps'] ?? 10}', onChanged: (v) => setState(() => ex['reps'] = int.tryParse(v) ?? 10)),
                              const SizedBox(width: 8),
                              _MiniInput(label: 'Sec', value: '${ex['duration'] ?? 60}', onChanged: (v) => setState(() => ex['duration'] = int.tryParse(v) ?? 60)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MiniInput extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _MiniInput({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[600])),
          const SizedBox(height: 3),
          Container(
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: TextEditingController(text: value),
              onChanged: onChanged,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobilePickerTabs extends StatelessWidget {
  final int selectedCount;
  final _CourseType type;
  final VoidCallback onLibrary;
  final VoidCallback onSelected;

  const _MobilePickerTabs({required this.selectedCount, required this.type, required this.onLibrary, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Mobile uses single panel for now
  }
}

// ═══════════════════════════════════════════════════════════
//  COURSE DETAIL MODAL
// ═══════════════════════════════════════════════════════════

class _CourseDetailModal extends StatefulWidget {
  final Map<String, dynamic> course;
  final dynamic service;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;

  const _CourseDetailModal({required this.course, required this.service, required this.onRefresh, required this.onEdit});

  @override
  State<_CourseDetailModal> createState() => _CourseDetailModalState();
}

class _CourseDetailModalState extends State<_CourseDetailModal> {
  List<Map<String, dynamic>> _lessons = [];
  bool _loadingLessons = true;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    try {
      final lessons = await widget.service.getCourseLessons(widget.course['id'].toString());
      if (mounted) setState(() { _lessons = lessons; _loadingLessons = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingLessons = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    final type = _getType(c['course_type'] as String?);
    final name = c['name'] as String? ?? '';
    final desc = c['description'] as String? ?? '';
    final timeSlot = c['time_slot'] as String? ?? '';
    final duration = c['duration'] as int? ?? 60;
    final exercises = c['exercises'] as List? ?? [];
    final musicLinks = c['music_links'] as List? ?? [];
    final daysOfWeek = c['days_of_week'] as List?;
    final dayOfWeek = c['day_of_week'] as int?;

    String dayStr = '';
    if (daysOfWeek != null && daysOfWeek.isNotEmpty) {
      dayStr = daysOfWeek.map((d) => _dayLabels[(d as int) % 7]).join(', ');
    } else if (dayOfWeek != null) {
      dayStr = _dayLabels[dayOfWeek % 7];
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [type.color.withValues(alpha: 0.2), type.gradientEnd.withValues(alpha: 0.08)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Course info
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [type.color, type.gradientEnd]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(type.icon, size: 24, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            if (dayStr.isNotEmpty || timeSlot.isNotEmpty)
                              Text('$dayStr${timeSlot.isNotEmpty ? ' - $timeSlot' : ''} ($duration min)', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(desc, style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                  ],
                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'Inizia Lezione',
                          icon: Icons.play_arrow_rounded,
                          color: const Color(0xFF22C55E),
                          onTap: () {
                            Navigator.pop(context);
                            _startLiveClass(context, widget.course);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          label: 'Modifica',
                          icon: Icons.edit_rounded,
                          color: Colors.grey[600]!,
                          onTap: widget.onEdit,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Playlists
                  if (musicLinks.isNotEmpty) ...[
                    const Text('Playlists', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    ...musicLinks.map((ml) {
                      final m = ml is Map ? ml : {};
                      final isSpotify = m['type'] == 'spotify';
                      final url = m['url'] as String? ?? '';
                      return GestureDetector(
                        onTap: () async {
                          if (url.isNotEmpty) {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: (isSpotify ? const Color(0xFF1DB954) : const Color(0xFFFF0000)).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Icon(
                                  isSpotify ? Icons.music_note_rounded : Icons.play_circle_filled_rounded,
                                  size: 16,
                                  color: isSpotify ? const Color(0xFF1DB954) : const Color(0xFFFF0000),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m['title'] as String? ?? 'Playlist', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                                    Text(isSpotify ? 'Spotify' : 'YouTube', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                  ],
                                ),
                              ),
                              Icon(Icons.open_in_new_rounded, size: 16, color: isSpotify ? const Color(0xFF1DB954) : const Color(0xFFFF0000)),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  // Exercises
                  if (exercises.isNotEmpty) ...[
                    Text('Esercizi (${exercises.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    ...exercises.asMap().entries.map((entry) {
                      final i = entry.key;
                      final ex = entry.value is Map ? entry.value as Map : {};
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(color: type.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                              child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: type.color))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(ex['name'] as String? ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  // Lessons History
                  const Text('Lezioni', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  if (_loadingLessons)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
                  else if (_lessons.isEmpty)
                    Text('Nessuna lezione programmata', style: TextStyle(fontSize: 13, color: Colors.grey[600]))
                  else
                    ..._lessons.map((lesson) => _LessonCard(
                      lesson: lesson,
                      type: type,
                      service: widget.service,
                      onRefresh: () {
                        _loadLessons();
                        widget.onRefresh();
                      },
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startLiveClass(BuildContext context, Map<String, dynamic> course) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _LiveClassModal(course: course),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  LESSON CARD
// ═══════════════════════════════════════════════════════════

class _LessonCard extends StatelessWidget {
  final Map<String, dynamic> lesson;
  final _CourseType type;
  final dynamic service;
  final VoidCallback onRefresh;

  const _LessonCard({required this.lesson, required this.type, required this.service, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final date = lesson['date'] as String? ?? '';
    final time = lesson['time'] as String? ?? '';
    final completed = lesson['completed'] as bool? ?? false;
    final engagement = lesson['engagement_level'] as int?;
    final attendees = lesson['attendee_count'] as int?;
    final lessonId = lesson['id'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: completed ? const Color(0xFF22C55E).withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: completed ? const Color(0xFF22C55E).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: completed ? const Color(0xFF22C55E).withValues(alpha: 0.15) : type.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: completed
                ? const Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 22)
                : Icon(Icons.event_rounded, color: type.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text(
                  [
                    if (time.isNotEmpty) time,
                    if (engagement != null) '${'*' * engagement}',
                    if (attendees != null) '$attendees partecipanti',
                  ].join(' - '),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          if (!completed) ...[
            GestureDetector(
              onTap: () => _showCompleteModal(context, lessonId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Completa', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF22C55E))),
              ),
            ),
            const SizedBox(width: 6),
          ],
          GestureDetector(
            onTap: () => _deleteLesson(context, lessonId),
            child: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  void _showCompleteModal(BuildContext context, int lessonId) {
    int engagement = 3;
    final attendeeCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Completa Lezione', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              const Text('Engagement', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (i) {
                  final level = i + 1;
                  final isSelected = level <= engagement;
                  return GestureDetector(
                    onTap: () => setModalState(() => engagement = level),
                    child: Container(
                      width: 44, height: 44,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF22C55E).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? const Color(0xFF22C55E).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Icon(Icons.star_rounded, size: 22, color: isSelected ? const Color(0xFF22C55E) : Colors.grey[600]),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              _FormField(controller: attendeeCtrl, label: 'Partecipanti', hint: 'Numero (opzionale)', inputType: TextInputType.number),
              const SizedBox(height: 12),
              _FormField(controller: notesCtrl, label: 'Note', hint: 'Opzionale', maxLines: 2),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    try {
                      await service.completeLesson(lessonId, {
                        'engagement_level': engagement,
                        if (attendeeCtrl.text.isNotEmpty) 'attendee_count': int.tryParse(attendeeCtrl.text),
                        if (notesCtrl.text.isNotEmpty) 'notes': notesCtrl.text,
                      });
                      onRefresh();
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Errore: $e')));
                    }
                  },
                  child: const Text('COMPLETA', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteLesson(BuildContext context, int lessonId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Elimina Lezione', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Eliminare questa lezione?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await service.deleteLesson(lessonId);
        onRefresh();
      } catch (_) {}
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  SCHEDULE LESSON MODAL
// ═══════════════════════════════════════════════════════════

class _ScheduleLessonModal extends StatefulWidget {
  final Map<String, dynamic> course;
  final Future<void> Function(Map<String, dynamic>) onSchedule;

  const _ScheduleLessonModal({required this.course, required this.onSchedule});

  @override
  State<_ScheduleLessonModal> createState() => _ScheduleLessonModalState();
}

class _ScheduleLessonModalState extends State<_ScheduleLessonModal> {
  late final TextEditingController _dateCtrl;
  late final TextEditingController _timeCtrl;
  late final TextEditingController _durationCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
    _timeCtrl = TextEditingController(text: widget.course['time_slot'] as String? ?? '09:00');
    _durationCtrl = TextEditingController(text: (widget.course['duration'] as int? ?? 60).toString());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Programma Lezione: ${widget.course['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _FormField(controller: _dateCtrl, label: 'Data', hint: 'YYYY-MM-DD'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _FormField(controller: _timeCtrl, label: 'Orario', hint: '09:00')),
              const SizedBox(width: 12),
              Expanded(child: _FormField(controller: _durationCtrl, label: 'Durata (min)', hint: '60', inputType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: const Color(0xFF22C55E).withValues(alpha: 0.3),
              ),
              onPressed: _isSaving ? null : () async {
                setState(() => _isSaving = true);
                try {
                  await widget.onSchedule({
                    'date': _dateCtrl.text,
                    'time': _timeCtrl.text,
                    'duration': int.tryParse(_durationCtrl.text) ?? 60,
                  });
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
                } finally {
                  if (mounted) setState(() => _isSaving = false);
                }
              },
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('PROGRAMMA', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  LIVE CLASS MODAL
// ═══════════════════════════════════════════════════════════

class _LiveClassModal extends StatefulWidget {
  final Map<String, dynamic> course;

  const _LiveClassModal({required this.course});

  @override
  State<_LiveClassModal> createState() => _LiveClassModalState();
}

// Counter for unique iframe view IDs
int _iframeViewCounter = 0;

class _LiveClassModalState extends State<_LiveClassModal> {
  int _currentExerciseIndex = 0;
  int _timerSeconds = 60;
  bool _timerRunning = false;
  bool _autoAdvance = false;
  bool _musicPlayerVisible = true;
  Timer? _timer;

  List get _exercises => widget.course['exercises'] as List? ?? [];
  List<Map<String, dynamic>> get _musicLinks =>
      (widget.course['music_links'] as List? ?? []).map((m) => Map<String, dynamic>.from(m as Map)).toList();
  Map<String, dynamic> get _currentExercise =>
      _exercises.isNotEmpty ? Map<String, dynamic>.from(_exercises[_currentExerciseIndex] as Map) : {};

  String? _youtubeViewType;
  String? _spotifyViewType;
  dynamic _musicIframe;
  bool _isYouTubeEmbed = false;
  bool _isSpotifyEmbed = false;
  bool _spotifyNotConnected = false;

  @override
  void initState() {
    super.initState();
    if (_exercises.isNotEmpty) {
      _timerSeconds = (_currentExercise['duration'] as int?) ?? 60;
    }
    _registerMusicIframes();
    _checkSpotifyIfNeeded();
  }

  Future<void> _checkSpotifyIfNeeded() async {
    if (!_isSpotifyEmbed) return;
    // Wait for the Spotify embed to load and check if it shows the "Get Spotify" prompt
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    // If the Spotify controller wasn't created, the user likely doesn't have Premium
    _evalJs('''
      window._gymSpotifyCheckDone = true;
      if (!window._gymSpotifyCtrl) {
        window._gymSpotifyNotConnected = true;
      }
    ''');
    // We can't easily read JS vars from Dart, so just show the prompt
    // for Spotify embeds after a delay (the embed itself will show "Get Spotify" if not Premium)
    setState(() => _spotifyNotConnected = true);
  }

  void _registerMusicIframes() {
    if (_musicLinks.isEmpty) return;
    final first = _musicLinks.first;
    final embedUrl = _getMusicEmbedUrl(first['url'] as String? ?? '', first['type'] as String? ?? '');
    if (embedUrl == null) return;

    final isYouTube = first['type'] == 'youtube';
    _isYouTubeEmbed = isYouTube;
    _isSpotifyEmbed = !isYouTube;
    final viewId = 'music-iframe-${_iframeViewCounter++}';

    final registeredId = web_helper.registerIframe(
      viewId,
      embedUrl,
      allow: 'autoplay; encrypted-media; fullscreen; picture-in-picture',
      onCreated: (iframe) => _musicIframe = iframe,
    );

    if (registeredId == null) return; // native — no iframe support

    if (isYouTube) {
      _youtubeViewType = registeredId;
    } else {
      _spotifyViewType = registeredId;
      // Delay Spotify API init to ensure iframe is in DOM
      Future.delayed(const Duration(seconds: 1), _initSpotifyApi);
    }
  }

  void _evalJs(String code) {
    web_helper.evalJs(code);
  }

  void _initSpotifyApi() {
    // Store the Dart iframe reference on the JS window object
    // so the Spotify IFrame API can find it
    if (_musicIframe != null) {
      _evalJs('document.documentElement.setAttribute("data-spotify-iframe", "true");');
    }

    // Setup the Spotify IFrame API callback and controller
    _evalJs('''
      window._gymSpotifyPlaying = false;
      window._gymSpotifyCtrl = null;
      function _gymInitSpotify(IFrameAPI) {
        var iframe = window._gymSpotifyIframe;
        if (!iframe) {
          // Fallback: search DOM broadly
          var all = document.querySelectorAll('iframe');
          for (var i = 0; i < all.length; i++) {
            if (all[i].src && all[i].src.indexOf('spotify.com/embed') !== -1) {
              iframe = all[i]; break;
            }
          }
          if (!iframe) {
            // Also search inside shadow roots (Flutter platform views)
            var pvs = document.querySelectorAll('flt-platform-view');
            for (var j = 0; j < pvs.length; j++) {
              var sr = pvs[j].shadowRoot;
              if (sr) {
                var found = sr.querySelector('iframe[src*="spotify.com/embed"]');
                if (found) { iframe = found; break; }
              }
            }
          }
        }
        if (!iframe) {
          setTimeout(function() { _gymInitSpotify(IFrameAPI); }, 1000);
          return;
        }
        IFrameAPI.createController(iframe, {}, function(ctrl) {
          window._gymSpotifyCtrl = ctrl;
          ctrl.addListener('playback_update', function(e) {
            window._gymSpotifyPlaying = !e.data.isPaused;
          });
        });
      }
      window.onSpotifyIframeApiReady = _gymInitSpotify;
    ''');

    // Load the Spotify IFrame API script if not already loaded
    web_helper.loadScript('gym-spotify-iframe-api', 'https://open.spotify.com/embed/iframe-api/v1');
  }

  void _playMusic() {
    final iframe = _musicIframe;
    if (iframe == null) return;
    if (_isYouTubeEmbed) {
      web_helper.postMessageToIframe(iframe, '{"event":"command","func":"playVideo","args":""}', '*');
    } else if (_isSpotifyEmbed) {
      // Only toggle if not already playing
      _evalJs('if (window._gymSpotifyCtrl && !window._gymSpotifyPlaying) { window._gymSpotifyCtrl.togglePlay(); }');
    }
  }

  void _pauseMusic() {
    final iframe = _musicIframe;
    if (iframe == null) return;
    if (_isYouTubeEmbed) {
      web_helper.postMessageToIframe(iframe, '{"event":"command","func":"pauseVideo","args":""}', '*');
    } else if (_isSpotifyEmbed) {
      // Only toggle if currently playing
      _evalJs('if (window._gymSpotifyCtrl && window._gymSpotifyPlaying) { window._gymSpotifyCtrl.togglePlay(); }');
    }
  }

  String? _getMusicEmbedUrl(String url, String type) {
    if (url.isEmpty) return null;

    if (type == 'spotify') {
      final match = RegExp(r'spotify\.com/(playlist|album|track)/([a-zA-Z0-9]+)').firstMatch(url);
      if (match != null) {
        return 'https://open.spotify.com/embed/${match.group(1)}/${match.group(2)}?utm_source=generator&theme=0';
      }
    } else if (type == 'youtube') {
      String? videoId;
      String? playlistId;

      if (url.contains('list=')) {
        final m = RegExp(r'list=([a-zA-Z0-9_-]+)').firstMatch(url);
        if (m != null) playlistId = m.group(1);
      }
      if (url.contains('v=')) {
        final m = RegExp(r'[?&]v=([a-zA-Z0-9_-]+)').firstMatch(url);
        if (m != null) videoId = m.group(1);
      } else if (url.contains('youtu.be/')) {
        final m = RegExp(r'youtu\.be/([a-zA-Z0-9_-]+)').firstMatch(url);
        if (m != null) videoId = m.group(1);
      } else if (url.contains('music.youtube.com/watch')) {
        final m = RegExp(r'watch[?&]v=([a-zA-Z0-9_-]+)').firstMatch(url);
        if (m != null) videoId = m.group(1);
      }

      if (playlistId != null) {
        return 'https://www.youtube.com/embed/videoseries?list=$playlistId&autoplay=0&enablejsapi=1&origin=${Uri.base.origin}';
      } else if (videoId != null) {
        return 'https://www.youtube.com/embed/$videoId?autoplay=0&enablejsapi=1&origin=${Uri.base.origin}';
      }
    }
    return null;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pauseMusic();
    if (_isSpotifyEmbed) {
      _evalJs('if (window._gymSpotifyCtrl) { window._gymSpotifyCtrl.destroy(); window._gymSpotifyCtrl = null; }');
    }
    super.dispose();
  }

  void _toggleTimer() {
    if (_timerRunning) {
      _timer?.cancel();
      _pauseMusic();
      setState(() => _timerRunning = false);
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_timerSeconds <= 1) {
          t.cancel();
          _pauseMusic();
          setState(() { _timerSeconds = 0; _timerRunning = false; });
          if (_autoAdvance && _currentExerciseIndex < _exercises.length - 1) {
            _nextExercise();
          }
        } else {
          setState(() => _timerSeconds--);
        }
      });
      _playMusic();
      setState(() => _timerRunning = true);
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    _pauseMusic();
    setState(() {
      _timerSeconds = (_currentExercise['duration'] as int?) ?? 60;
      _timerRunning = false;
    });
  }

  void _setQuickTimer(int seconds) {
    _timer?.cancel();
    setState(() { _timerSeconds = seconds; _timerRunning = false; });
  }

  void _nextExercise() {
    if (_currentExerciseIndex < _exercises.length - 1) {
      _timer?.cancel();
      setState(() {
        _currentExerciseIndex++;
        _timerRunning = false;
        final ex = _currentExercise;
        _timerSeconds = (ex['duration'] as int?) ?? 60;
      });
    }
  }

  void _prevExercise() {
    if (_currentExerciseIndex > 0) {
      _timer?.cancel();
      setState(() {
        _currentExerciseIndex--;
        _timerRunning = false;
        final ex = _currentExercise;
        _timerSeconds = (ex['duration'] as int?) ?? 60;
      });
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildMusicPanel(_CourseType type) {
    if (_musicLinks.isEmpty) return const SizedBox.shrink();

    final first = _musicLinks.first;
    final isYouTube = first['type'] == 'youtube';
    final title = first['title'] as String? ?? 'Workout Mix';
    final url = first['url'] as String? ?? '';
    final viewType = isYouTube ? _youtubeViewType : _spotifyViewType;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFA855F7).withValues(alpha: 0.2), const Color(0xFFEC4899).withValues(alpha: 0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Header with title and toggle
          GestureDetector(
            onTap: () => setState(() => _musicPlayerVisible = !_musicPlayerVisible),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: isYouTube ? const Color(0xFFFF0000).withValues(alpha: 0.2) : const Color(0xFF1DB954).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isYouTube ? Icons.play_circle_filled_rounded : Icons.music_note_rounded,
                      size: 18,
                      color: isYouTube ? const Color(0xFFFF0000) : const Color(0xFF1DB954),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text(
                          isYouTube ? 'YouTube' : 'Spotify',
                          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _musicPlayerVisible ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey[400], size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Embedded player (collapsible)
          if (_musicPlayerVisible) ...[
            if (viewType != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                height: isYouTube ? 200 : 160,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: web_helper.iframeView(viewType),
              ),

            // Control buttons
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (_musicPlayerVisible && viewType != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _musicPlayerVisible = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.stop_rounded, size: 16, color: AppColors.danger),
                              SizedBox(width: 4),
                              Text('Nascondi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.danger)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (viewType != null) const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openUrl(url),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: (isYouTube ? const Color(0xFFFF0000) : const Color(0xFF1DB954)).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: (isYouTube ? const Color(0xFFFF0000) : const Color(0xFF1DB954)).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.open_in_new_rounded, size: 16, color: isYouTube ? const Color(0xFFFF0000) : const Color(0xFF1DB954)),
                            const SizedBox(width: 4),
                            Text(
                              'Apri in ${isYouTube ? 'YouTube' : 'Spotify'}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isYouTube ? const Color(0xFFFF0000) : const Color(0xFF1DB954)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Spotify connect prompt
            if (_isSpotifyEmbed && _spotifyNotConnected)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1DB954).withValues(alpha: 0.15), const Color(0xFF1ED760).withValues(alpha: 0.1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1DB954).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Connetti Spotify Premium per la riproduzione automatica con il timer',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.spotifyAuthorize}');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF1DB954), Color(0xFF1ED760)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.link_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Connetti Spotify', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Additional playlists
            if (_musicLinks.length > 1) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Altre Playlist', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[500], letterSpacing: 0.5)),
                ),
              ),
              ..._musicLinks.skip(1).map((link) {
                final linkIsYt = link['type'] == 'youtube';
                return GestureDetector(
                  onTap: () => _openUrl(link['url'] as String? ?? ''),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          linkIsYt ? Icons.play_circle_outline_rounded : Icons.music_note_rounded,
                          size: 16,
                          color: linkIsYt ? const Color(0xFFFF0000) : const Color(0xFF1DB954),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(link['title'] as String? ?? 'Playlist', style: const TextStyle(fontSize: 12, color: Colors.white))),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey[600]),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = _getType(widget.course['course_type'] as String?);
    final courseName = widget.course['name'] as String? ?? '';
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [type.color.withValues(alpha: 0.15), type.gradientEnd.withValues(alpha: 0.05)]),
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
              ),
              child: Row(
                children: [
                  Icon(type.icon, color: type.color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(courseName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        if (_exercises.isNotEmpty)
                          Text('Esercizio ${_currentExerciseIndex + 1}/${_exercises.length}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  if (_musicLinks.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _musicPlayerVisible = !_musicPlayerVisible),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _musicPlayerVisible
                              ? const Color(0xFFA855F7).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _musicPlayerVisible ? Icons.music_note_rounded : Icons.music_off_rounded,
                              size: 14,
                              color: _musicPlayerVisible ? const Color(0xFFA855F7) : Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _musicPlayerVisible ? 'Music' : 'Music',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _musicPlayerVisible ? const Color(0xFFA855F7) : Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      _pauseMusic();
                      _timer?.cancel();
                      Navigator.pop(context);
                    },
                    child: const Text('Fine Lezione', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: _exercises.isEmpty
                  ? Center(child: Text('Nessun esercizio nel corso', style: TextStyle(color: Colors.grey[500])))
                  : isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Exercise + Timer
                          Expanded(
                            flex: 3,
                            child: _buildExerciseArea(type),
                          ),
                          // Right: Music + Exercise list sidebar
                          SizedBox(
                            width: 320,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  _buildMusicPanel(type),
                                  _buildExerciseList(type),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildMusicPanel(type),
                            _buildExerciseContent(type),
                            const SizedBox(height: 20),
                            _buildExerciseList(type),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseArea(_CourseType type) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _buildExerciseContent(type),
    );
  }

  Widget _buildExerciseContent(_CourseType type) {
    return Column(
      children: [
        Text(
          _currentExercise['name'] as String? ?? 'Esercizio',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: type.color),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_currentExercise['sets'] != null)
              _TagChip(icon: Icons.repeat_rounded, text: '${_currentExercise['sets']} set', color: type.color),
            if (_currentExercise['reps'] != null) ...[
              const SizedBox(width: 8),
              _TagChip(icon: Icons.numbers_rounded, text: '${_currentExercise['reps']} reps', color: type.color),
            ],
            if (_currentExercise['rest'] != null) ...[
              const SizedBox(width: 8),
              _TagChip(icon: Icons.timer_outlined, text: '${_currentExercise['rest']}s rest', color: type.color),
            ],
          ],
        ),
        const SizedBox(height: 32),

        // Timer
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              Text(
                _formatTime(_timerSeconds),
                style: TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: type.color, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [30, 45, 60, 90].map((s) {
                  return GestureDetector(
                    onTap: () => _setQuickTimer(s),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${s}s', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400])),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _toggleTimer,
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [type.color, type.gradientEnd]),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_timerRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _resetTimer,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Auto-avanza', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(width: 8),
                  Switch(
                    value: _autoAdvance,
                    onChanged: (v) => setState(() => _autoAdvance = v),
                    activeColor: const Color(0xFF22C55E),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Navigation
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.03),
                ),
                onPressed: _currentExerciseIndex > 0 ? _prevExercise : null,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Precedente', style: TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: type.color,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: type.color.withValues(alpha: 0.3),
                ),
                onPressed: _currentExerciseIndex < _exercises.length - 1 ? _nextExercise : null,
                icon: const Text('Successivo', style: TextStyle(fontSize: 13, color: Colors.white)),
                label: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExerciseList(_CourseType type) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sequenza Esercizi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          ..._exercises.asMap().entries.map((entry) {
            final i = entry.key;
            final ex = Map<String, dynamic>.from(entry.value as Map);
            final isCurrent = i == _currentExerciseIndex;
            final isDone = i < _currentExerciseIndex;
            return GestureDetector(
              onTap: () {
                _timer?.cancel();
                setState(() {
                  _currentExerciseIndex = i;
                  _timerRunning = false;
                  _timerSeconds = (ex['duration'] as int?) ?? 60;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isCurrent ? type.color.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isCurrent ? Border.all(color: type.color.withValues(alpha: 0.3)) : null,
                ),
                child: Row(
                  children: [
                    if (isDone)
                      Icon(Icons.check_circle_rounded, size: 18, color: const Color(0xFF22C55E).withValues(alpha: 0.7))
                    else
                      Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          color: isCurrent ? type.color : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isCurrent ? Colors.white : Colors.grey[500]))),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ex['name'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                          color: isCurrent ? type.color : isDone ? Colors.grey[600] : AppColors.textPrimary,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ACTION BUTTON
// ═══════════════════════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  TAG CHIP (used in live class)
// ═══════════════════════════════════════════════════════════

class _TagChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _TagChip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════════════

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final TextInputType inputType;

  const _FormField({required this.controller, required this.label, required this.hint, this.maxLines = 1, this.inputType = TextInputType.text});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: inputType,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.grey[500]),
        hintStyle: TextStyle(color: Colors.grey[700]),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

class _SectionBox extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionBox({required this.title, required this.icon, this.trailing, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
