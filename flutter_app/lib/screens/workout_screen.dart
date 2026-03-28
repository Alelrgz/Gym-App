import 'dart:async';
import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../config/api_config.dart';
import '../providers/client_provider.dart';
import '../providers/trainer_provider.dart';
import '../providers/websocket_provider.dart';
import '../widgets/exercise_video.dart';
import '../services/client_service.dart';

// ─── Cardio Detection ────────────────────────────────────────────

bool _isCardio(String name) {
  final n = name.toLowerCase();
  const keywords = [
    'run', 'running', 'sprint', 'jog', 'jogging',
    'bike', 'cycling', 'cycle', 'hiit', 'cardio',
    'treadmill', 'elliptical', 'stairmaster', 'stepper',
    'rowing', 'rower', 'jump rope', 'jumping',
    'swimming', 'swim', 'walk', 'walking',
  ];
  return keywords.any((k) => n.contains(k));
}

// ─── Exercise video URL builder ──────────────────────────────────

String _exerciseVideoUrl(String? videoId) {
  if (videoId == null || videoId.isEmpty) return '';
  final src = videoId.trim();
  if (src.startsWith('http')) return src;
  if (src.startsWith('/')) return '${ApiConfig.baseUrl}$src';
  return '${ApiConfig.baseUrl}/static/videos/$src.mp4';
}

// ─── Main Workout Screen (Tab) ────────────────────────────────────

class WorkoutScreen extends ConsumerWidget {
  final String? coopPartnerId;
  final String? coopPartnerName;
  final String? coopPartnerPicture;
  final bool isTrainer;
  final Map<String, dynamic>? initialWorkout;

  const WorkoutScreen({
    super.key,
    this.coopPartnerId,
    this.coopPartnerName,
    this.coopPartnerPicture,
    this.isTrainer = false,
    this.initialWorkout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If workout data passed directly (trainer mode), use it
    if (initialWorkout != null) {
      return _WorkoutView(
        workout: initialWorkout!,
        isTrainer: isTrainer,
        coopPartnerId: coopPartnerId,
        coopPartnerName: coopPartnerName,
        coopPartnerPicture: coopPartnerPicture,
      );
    }

    return _WorkoutListView(
      coopPartnerId: coopPartnerId,
      coopPartnerName: coopPartnerName,
      coopPartnerPicture: coopPartnerPicture,
    );
  }
}

// ─── Workout List View ───────────────────────────────────────────

class _WorkoutListView extends ConsumerStatefulWidget {
  final String? coopPartnerId;
  final String? coopPartnerName;
  final String? coopPartnerPicture;

  const _WorkoutListView({
    this.coopPartnerId,
    this.coopPartnerName,
    this.coopPartnerPicture,
  });

  @override
  ConsumerState<_WorkoutListView> createState() => _WorkoutListViewState();
}

class _WorkoutListViewState extends ConsumerState<_WorkoutListView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openBuilder({Map<String, dynamic>? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutBuilderPage(
          existingWorkout: existing,
          onSaved: () {
            ref.invalidate(clientWorkoutsProvider);
            ref.invalidate(clientDataProvider);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _startWorkout(Map<String, dynamic> workout) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _WorkoutView(
          workout: workout,
          coopPartnerId: widget.coopPartnerId,
          coopPartnerName: widget.coopPartnerName,
          coopPartnerPicture: widget.coopPartnerPicture,
        ),
      ),
    );
  }

  void _previewWorkout(Map<String, dynamic> workout) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _WorkoutPreviewPage(
          workout: workout,
          onStart: () => _startWorkout(workout),
          onEdit: () => _openBuilder(existing: workout),
        ),
      ),
    );
  }

  Future<void> _deleteWorkout(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Elimina Allenamento', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Sei sicuro di voler eliminare questo allenamento?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Annulla')),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: const Text('Elimina', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(clientServiceProvider).deleteClientWorkout(id);
      ref.invalidate(clientWorkoutsProvider);
      ref.invalidate(clientDataProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workoutsAsync = ref.watch(clientWorkoutsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                    onPressed: () => context.go('/home'),
                  ),
                  const Expanded(
                    child: Text(
                      'I Miei Allenamenti',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (_tabController.index == 0)
                    IconButton(
                      icon: const Icon(Icons.add_rounded, color: AppColors.primary),
                      onPressed: () => _openBuilder(),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey[500],
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              dividerHeight: 0.5,
              dividerColor: Colors.white.withValues(alpha: 0.06),
              tabs: const [
                Tab(text: 'Workout'),
                Tab(text: 'Split'),
              ],
            ),

            // Content
            Expanded(
              child: workoutsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => Center(child: Text('Errore: $e', style: const TextStyle(color: AppColors.textSecondary))),
                data: (data) {
                  final workouts = (data['workouts'] as List<dynamic>?)
                      ?.map((e) => e as Map<String, dynamic>)
                      .toList() ?? [];
                  final todayId = data['today_workout_id'] as String?;
                  final splits = data['splits'] as List<dynamic>?;

                  if (_tabController.index == 1) {
                    return _buildSplitView(workouts, splits);
                  }

                  if (workouts.isEmpty) {
                    return _buildEmptyState();
                  }

                  // Sort: today's workout first
                  if (todayId != null) {
                    workouts.sort((a, b) {
                      if (a['id'] == todayId) return -1;
                      if (b['id'] == todayId) return 1;
                      return 0;
                    });
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: workouts.length,
                    itemBuilder: (ctx, i) {
                      final w = workouts[i];
                      final isToday = w['id'] == todayId;
                      return _buildWorkoutCard(w, isToday);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitView(List<Map<String, dynamic>> workouts, List<dynamic>? splits) {
    final splitsList = (splits ?? []).cast<Map<String, dynamic>>();

    if (splitsList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.view_week_rounded, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              const Text('Nessuna Split',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Organizza i tuoi allenamenti\nin una programmazione settimanale.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: workouts.isEmpty ? null : () => _openSplitEditor(workouts: workouts),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Crea Split', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[800],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              if (workouts.isEmpty) ...[
                const SizedBox(height: 12),
                Text('Crea prima un allenamento nella tab Workout',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]), textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          itemCount: splitsList.length,
          itemBuilder: (ctx, i) {
            final s = splitsList[i];
            final schedule = s['schedule'] as Map<String, dynamic>? ?? {};
            final daysUsed = schedule.values.where((v) => v != null && v.toString().isNotEmpty).length;
            final dayNames = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openSplitEditor(workouts: workouts, existing: s),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(s['name'] ?? 'Split',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textTertiary),
                              onPressed: () => _deleteSplit(s['id']),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          _chip('$daysUsed giorni', Icons.calendar_today_rounded),
                        ]),
                        const SizedBox(height: 10),
                        // Mini week preview
                        Row(
                          children: List.generate(7, (d) {
                            final hasWorkout = schedule[d.toString()] != null && schedule[d.toString()].toString().isNotEmpty;
                            return Expanded(
                              child: Container(
                                margin: EdgeInsets.only(right: d < 6 ? 4 : 0),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: hasWorkout ? AppColors.primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(dayNames[d],
                                    style: TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.w600,
                                      color: hasWorkout ? AppColors.primary : Colors.grey[600],
                                    )),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // FAB
        Positioned(
          right: 16, bottom: 16,
          child: FloatingActionButton(
            backgroundColor: AppColors.primary,
            onPressed: workouts.isEmpty ? null : () => _openSplitEditor(workouts: workouts),
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _openSplitEditor({required List<Map<String, dynamic>> workouts, Map<String, dynamic>? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SplitEditorPage(
          workouts: workouts,
          existing: existing,
          onSaved: () {
            ref.invalidate(clientWorkoutsProvider);
            Navigator.of(context).pop();
          },
          clientService: ref.read(clientServiceProvider),
        ),
      ),
    );
  }

  Future<void> _deleteSplit(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Elimina Split', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Sei sicuro di voler eliminare questa split?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Annulla')),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: const Text('Elimina', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(clientServiceProvider).deleteSplit(id);
      ref.invalidate(clientWorkoutsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.fitness_center_rounded, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nessun Allenamento',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea il tuo primo allenamento\nper iniziare ad allenarti.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openBuilder(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crea Allenamento', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> w, bool isToday) {
    final exercises = w['exercises'] as List<dynamic>? ?? [];
    final title = w['title'] ?? 'Allenamento';
    final duration = w['duration'] ?? '';
    final difficulty = w['difficulty'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: isToday ? Border.all(color: AppColors.primary, width: 1.5) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _previewWorkout(w),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isToday) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('OGGI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textTertiary),
                      onPressed: () => _openBuilder(existing: w),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textTertiary),
                      onPressed: () => _deleteWorkout(w['id'].toString()),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (duration.isNotEmpty) _chip(duration, Icons.timer_outlined),
                    if (difficulty.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _chip(difficulty, Icons.speed_rounded),
                    ],
                    const SizedBox(width: 8),
                    _chip('${exercises.length} esercizi', Icons.fitness_center_rounded),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _previewWorkout(w),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isToday ? AppColors.primary : Colors.white.withValues(alpha: 0.06),
                      foregroundColor: isToday ? Colors.white : AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text(isToday ? 'Inizia Allenamento' : 'Inizia', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ─── No Workout Assigned ──────────────────────────────────────────

class _NoWorkoutView extends ConsumerWidget {
  const _NoWorkoutView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with back button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                    onPressed: () => context.go('/home'),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.fitness_center_rounded, size: 40, color: AppColors.primary),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Nessun Allenamento',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Il tuo trainer non ha ancora assegnato\nun allenamento per oggi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showWorkoutBuilder(context, ref),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Crea Allenamento', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
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

  void _showWorkoutBuilder(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutBuilderPage(
          onSaved: () {
            ref.invalidate(clientDataProvider);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

// ─── Active Workout View ──────────────────────────────────────────

class _WorkoutView extends ConsumerStatefulWidget {
  final Map<String, dynamic> workout;
  final String? coopPartnerId;
  final String? coopPartnerName;
  final String? coopPartnerPicture;
  final bool isTrainer;

  const _WorkoutView({
    required this.workout,
    this.coopPartnerId,
    this.coopPartnerName,
    this.coopPartnerPicture,
    this.isTrainer = false,
  });

  @override
  ConsumerState<_WorkoutView> createState() => _WorkoutViewState();
}

class _WorkoutViewState extends ConsumerState<_WorkoutView> {
  late List<Map<String, dynamic>> exercises;
  int currentExerciseIdx = 0;
  int currentSet = 0; // 0-indexed
  int currentReps = 10;
  bool isCompleted = false;
  bool isResting = false;
  int restSeconds = 0;
  bool videoExpanded = false;
  Timer? _restTimer;

  // CO-OP state
  bool get isCoopMode => widget.coopPartnerId != null;
  int coopTab = 0; // 0 = user ("Tu"), 1 = partner
  late List<Map<String, dynamic>> partnerExercises;
  int partnerExerciseIdx = 0;
  int partnerSet = 0;
  int partnerReps = 10;
  StreamSubscription? _coopCompletedSub;

  @override
  void initState() {
    super.initState();
    _initWorkout();
    if (isCoopMode) {
      final ws = ref.read(websocketServiceProvider);
      _coopCompletedSub = ws.coopCompleted.listen((msg) {
        if (mounted && !isCompleted) {
          setState(() => isCompleted = true);
          ref.read(coopProvider.notifier).reset();
          ref.invalidate(clientDataProvider);
          _showCoopCompletionOverlay(75);
        }
      });
    }
  }

  void _initWorkout() {
    final rawExercises = (widget.workout['exercises'] as List<dynamic>?) ?? [];
    isCompleted = widget.workout['completed'] == true;

    exercises = rawExercises.map((e) {
      final ex = Map<String, dynamic>.from(e as Map);
      final sets = (ex['sets'] as num?)?.toInt() ?? 3;
      if (ex['performance'] == null || (ex['performance'] as List).isEmpty) {
        ex['performance'] = List.generate(sets, (_) => {
          'reps': '', 'weight': '', 'duration': '', 'distance': '', 'completed': false,
        });
      } else {
        ex['performance'] = (ex['performance'] as List).map((p) => Map<String, dynamic>.from(p as Map)).toList();
      }
      return ex;
    }).toList();

    // Initialize partner exercises for CO-OP mode
    if (isCoopMode) {
      partnerExercises = exercises.map((ex) {
        final clone = Map<String, dynamic>.from(ex);
        final sets = (clone['sets'] as num?)?.toInt() ?? 3;
        clone['performance'] = List.generate(sets, (_) => {
          'reps': '', 'weight': '', 'duration': '', 'distance': '', 'completed': false,
        });
        return clone;
      }).toList();
    } else {
      partnerExercises = [];
    }

    // Find first incomplete exercise
    if (!isCompleted) {
      for (int i = 0; i < exercises.length; i++) {
        final perf = exercises[i]['performance'] as List;
        final allDone = perf.every((p) => p['completed'] == true);
        if (!allDone) {
          currentExerciseIdx = i;
          for (int s = 0; s < perf.length; s++) {
            if (perf[s]['completed'] != true) {
              currentSet = s;
              break;
            }
          }
          break;
        }
      }
      _syncReps();
    }
  }

  void _syncReps() {
    final exList = isCoopMode ? activeExercises : exercises;
    final idx = isCoopMode ? activeExerciseIdx : currentExerciseIdx;
    if (exList.isEmpty || idx >= exList.length) return;
    final ex = exList[idx];
    final repsStr = ex['reps']?.toString() ?? '10';
    final parts = repsStr.split('-');
    final reps = int.tryParse(parts.last.trim()) ?? 10;
    if (coopTab == 1) {
      partnerReps = reps;
    } else {
      currentReps = reps;
    }
  }

  @override
  @override
  void dispose() {
    _coopCompletedSub?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  void _adjustReps(int delta) {
    setState(() {
      if (isCoopMode && coopTab == 1) {
        partnerReps = max(0, partnerReps + delta);
      } else {
        currentReps = max(0, currentReps + delta);
      }
    });
  }

  void _completeSet() {
    final exList = isCoopMode ? activeExercises : exercises;
    final exIdx = isCoopMode ? activeExerciseIdx : currentExerciseIdx;
    final setIdx = isCoopMode ? activeSet : currentSet;
    final reps = isCoopMode ? activeReps : currentReps;

    final ex = exList[exIdx];
    final perf = ex['performance'] as List;
    final isCardio = _isCardio(ex['name'] ?? '');

    final setPerf = perf[setIdx] as Map<String, dynamic>;

    // Auto-fill reps from the circular counter
    if (!isCardio) {
      setPerf['reps'] = reps.toString();
    }

    // Validate
    if (isCardio) {
      if ((setPerf['duration'] ?? '').toString().isEmpty && (setPerf['distance'] ?? '').toString().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inserisci durata o distanza')));
        return;
      }
    } else {
      if (reps <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inserisci le ripetizioni')));
        return;
      }
      final weightStr = (setPerf['weight'] ?? '').toString().trim();
      if (weightStr.isEmpty || (double.tryParse(weightStr) ?? 0) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inserisci il peso (kg)')));
        return;
      }
    }

    int? restTimeToStart;

    setState(() {
      setPerf['completed'] = true;

      // Auto-fill next set's weight
      if (!isCardio && setIdx < perf.length - 1) {
        final nextPerf = perf[setIdx + 1] as Map<String, dynamic>;
        if ((nextPerf['weight'] ?? '').toString().isEmpty) {
          nextPerf['weight'] = setPerf['weight'];
        }
      }

      // Move to next set or exercise
      if (setIdx < perf.length - 1) {
        if (isCoopMode && coopTab == 1) {
          partnerSet++;
        } else {
          currentSet++;
        }
        restTimeToStart = (ex['rest'] as num?)?.toInt() ?? 60;
      } else {
        if (exIdx < exList.length - 1) {
          if (isCoopMode && coopTab == 1) {
            partnerExerciseIdx++;
            partnerSet = 0;
          } else {
            currentExerciseIdx++;
            currentSet = 0;
          }
          _syncReps();
          restTimeToStart = (ex['rest'] as num?)?.toInt() ?? 60;
        }
      }
    });

    // Start rest timer AFTER setState completes to avoid nested setState
    if (restTimeToStart != null) {
      _startRestTimer(restTimeToStart!);
    }
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    setState(() { isResting = true; restSeconds = seconds; });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (restSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => isResting = false);
      } else {
        if (mounted) setState(() => restSeconds--);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() => isResting = false);
  }

  void _switchExercise(int idx) {
    if (isCompleted) return;
    final exList = isCoopMode ? activeExercises : exercises;
    setState(() {
      if (isCoopMode && coopTab == 1) {
        partnerExerciseIdx = idx;
        final perf = exList[idx]['performance'] as List;
        partnerSet = 0;
        for (int s = 0; s < perf.length; s++) {
          if (perf[s]['completed'] != true) { partnerSet = s; break; }
        }
      } else {
        currentExerciseIdx = idx;
        final perf = exList[idx]['performance'] as List;
        currentSet = 0;
        for (int s = 0; s < perf.length; s++) {
          if (perf[s]['completed'] != true) { currentSet = s; break; }
        }
      }
      _syncReps();
    });
  }

  bool _allCompleteFor(List<Map<String, dynamic>> exList) {
    return exList.every((ex) {
      final perf = ex['performance'] as List;
      return perf.every((p) => (p as Map)['completed'] == true);
    });
  }

  bool get _allComplete {
    if (isCoopMode) {
      return _allCompleteFor(exercises) && _allCompleteFor(partnerExercises);
    }
    return _allCompleteFor(exercises);
  }

  int get _totalSets {
    int total = 0;
    for (final ex in activeExercises) {
      total += ((ex['sets'] as num?)?.toInt() ?? 3);
    }
    return total;
  }

  int get _completedSets {
    int done = 0;
    for (final ex in activeExercises) {
      final perf = ex['performance'] as List;
      done += perf.where((p) => (p as Map)['completed'] == true).length;
    }
    return done;
  }

  double get _progressPct => _totalSets > 0 ? (_completedSets / _totalSets * 100) : 0;

  List<Map<String, dynamic>> _buildExercisePayload(List<Map<String, dynamic>> exList) {
    return exList.map((ex) => {
      'name': ex['name'],
      'sets': ex['sets'],
      'reps': ex['reps'],
      'performance': ex['performance'],
    }).toList();
  }

  Future<void> _finishWorkout() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      if (widget.isTrainer) {
        // Trainer mode: use trainer service
        final service = ref.read(trainerServiceProvider);
        await service.completeScheduleEntry({
          'date': today,
          'exercises': _buildExercisePayload(exercises),
        });
        if (mounted) {
          setState(() => isCompleted = true);
          ref.invalidate(trainerDataProvider);
          _showCompletionOverlay(isTrainer: true);
        }
      } else if (isCoopMode) {
        final service = ref.read(clientServiceProvider);
        final result = await service.completeCoopWorkout({
          'date': today,
          'partner_id': widget.coopPartnerId,
          'exercises': _buildExercisePayload(exercises),
          'partner_exercises': _buildExercisePayload(partnerExercises),
        });
        if (mounted) {
          setState(() => isCompleted = true);
          ref.read(coopProvider.notifier).reset();
          ref.invalidate(clientDataProvider);
          // Notify partner via WebSocket
          final ws = ref.read(websocketServiceProvider);
          ws.sendCoopCompleted(widget.coopPartnerId!);
          _showCoopCompletionOverlay(result['gems_awarded'] as int? ?? 75);
        }
      } else {
        final service = ref.read(clientServiceProvider);
        await service.completeWorkout({
          'date': today,
          'exercises': _buildExercisePayload(exercises),
        });
        if (mounted) {
          setState(() => isCompleted = true);
          ref.invalidate(clientDataProvider);
          _showCompletionOverlay();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  void _showCompletionOverlay({bool isTrainer = false}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, size: 48, color: Color(0xFF4ADE80)),
              ),
              const SizedBox(height: 20),
              const Text('Allenamento Completato!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              if (!isTrainer) ...[
                const SizedBox(height: 8),
                const Text('+50 Gems', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ],
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  context.go(isTrainer ? '/trainer/schedule' : '/home');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                  child: const Text('CONTINUA', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCoopCompletionOverlay(int gems) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.handshake_rounded, size: 44, color: Color(0xFF7C3AED)),
              ),
              const SizedBox(height: 20),
              const Text('CO-OP Completato!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(
                'con ${widget.coopPartnerName ?? "Partner"}',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
              const SizedBox(height: 12),
              Text('+$gems Gems', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
              const SizedBox(height: 4),
              Text('Bonus CO-OP: +25 Gems extra!', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  context.go(widget.isTrainer ? '/trainer/schedule' : '/home');
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(12)),
                  child: const Text('CONTINUA', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // CO-OP helpers
  List<Map<String, dynamic>> get activeExercises => coopTab == 0 ? exercises : partnerExercises;
  int get activeExerciseIdx => coopTab == 0 ? currentExerciseIdx : partnerExerciseIdx;
  int get activeSet => coopTab == 0 ? currentSet : partnerSet;
  int get activeReps => coopTab == 0 ? currentReps : partnerReps;

  void _switchCoopTab(int tab) {
    setState(() => coopTab = tab);
    _syncReps();
  }

  Widget _coopTabBtn(String label, int tab, Color color) {
    final active = coopTab == tab;
    return GestureDetector(
      onTap: () => _switchCoopTab(tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? LinearGradient(colors: [color, color.withValues(alpha: 0.8)]) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (exercises.isEmpty) return const _NoWorkoutView();

    final exList = activeExercises;
    final exIdx = activeExerciseIdx;
    final currentEx = exList[exIdx];
    final currentName = currentEx['name'] ?? 'Exercise';
    final totalSetsForEx = (currentEx['sets'] as num?)?.toInt() ?? 3;
    final targetReps = currentEx['reps']?.toString() ?? '10';
    final isCardio = _isCardio(currentName);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              // ─── CO-OP Tab Bar ─────
              if (isCoopMode) ...[
                SafeArea(
                  bottom: false,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 8),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _coopTabBtn('Tu', 0, const Color(0xFFF97316))),
                        const SizedBox(width: 4),
                        Expanded(child: _coopTabBtn(widget.coopPartnerName ?? 'Partner', 1, const Color(0xFF7C3AED))),
                      ],
                    ),
                  ),
                ),
              ],
              // ─── Hero Section ─────
              if (isCompleted)
                // Completed: show workout title instead of video
                SizedBox(
                  height: 160,
                  child: Stack(
                    children: [
                      // Workout title centered
                      Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 36),
                              const SizedBox(height: 12),
                              Text(
                                widget.workout['title'] ?? 'Workout',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Completato',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Close button
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 12,
                        child: GestureDetector(
                          onTap: () => context.go(widget.isTrainer ? '/trainer/schedule' : '/home'),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Active: show exercise video
                GestureDetector(
                  onTap: () => setState(() => videoExpanded = !videoExpanded),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: videoExpanded ? 400 : 220,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Exercise video from backend
                        ExerciseVideoView(
                          videoUrl: _exerciseVideoUrl(currentEx['video_id']?.toString()),
                          key: ValueKey('video_${currentEx['video_id']}'),
                        ),
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.3),
                                Colors.black.withValues(alpha: 0.2),
                                AppColors.background,
                              ],
                              stops: const [0.0, 0.7, 1.0],
                            ),
                          ),
                        ),
                        // Top controls
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 8,
                          left: 12,
                          child: GestureDetector(
                            onTap: () => context.go(widget.isTrainer ? '/trainer/schedule' : '/home'),
                            child: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                        // IN DIRETTA badge
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'IN DIRETTA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Expand/collapse hint
                        Positioned(
                          bottom: 8,
                          left: 0, right: 0,
                          child: Center(
                            child: AnimatedRotation(
                              turns: videoExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ─── Active Exercise Card ──────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Exercise name
                    Text(
                      currentName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    // Set X/Y • Target
                    Text(
                      isCardio
                          ? 'Sessione ${activeSet + 1}/$totalSetsForEx'
                          : 'Serie ${activeSet + 1}/$totalSetsForEx  •  Obiettivo: $targetReps Ripetizioni',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // ─── Circular Rep Counter ────────────────
                    if (!isCardio && !isCompleted)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Minus button
                          GestureDetector(
                            onTap: () => _adjustReps(-1),
                            child: Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: const Icon(Icons.remove_rounded, color: Colors.white, size: 28),
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Counter circle
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer glow
                              Container(
                                width: 120, height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.2),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                              // Main circle
                              Container(
                                width: 112, height: 112,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.05),
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 4,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$activeReps',
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'RIPETIZIONI',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 24),
                          // Plus button
                          GestureDetector(
                            onTap: () => _adjustReps(1),
                            child: Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                            ),
                          ),
                        ],
                      ),

                    // Cardio inputs (inline for active set)
                    if (isCardio && !isCompleted) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _CardioInput(
                              label: 'Durata (min)',
                              value: ((exList[exIdx]['performance'] as List)[activeSet] as Map)['duration']?.toString() ?? '',
                              onChanged: (v) => setState(() {
                                (exList[exIdx]['performance'] as List)[activeSet]['duration'] = v;
                              }),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _CardioInput(
                              label: 'Distanza (km)',
                              value: ((exList[exIdx]['performance'] as List)[activeSet] as Map)['distance']?.toString() ?? '',
                              onChanged: (v) => setState(() {
                                (exList[exIdx]['performance'] as List)[activeSet]['distance'] = v;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ─── Completa Serie button ───────────────
                    if (!isCompleted)
                      GestureDetector(
                        onTap: _completeSet,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryHover],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Completa Serie',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                    // Complete workout button
                    if (!isCompleted && _allComplete)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: GestureDetector(
                          onTap: _finishWorkout,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF4ADE80), Color(0xFF22C55E)]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: const Color(0xFF4ADE80).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: const Text(
                              'COMPLETA ALLENAMENTO',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ─── Routine Header ────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'ROUTINE DI ALLENAMENTO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.4),
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_progressPct.round()}% Complete',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ─── Exercise List ─────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: exList.length,
                  itemBuilder: (context, index) {
                    final ex = exList[index];
                    final perf = ex['performance'] as List;
                    final completedCount = perf.where((p) => (p as Map)['completed'] == true).length;
                    final totalSets = (ex['sets'] as num?)?.toInt() ?? 3;
                    final allDone = completedCount == totalSets;
                    final isActive = index == exIdx && !isCompleted;
                    final name = ex['name'] ?? 'Exercise';
                    final reps = ex['reps']?.toString() ?? '10';
                    final isExCardio = _isCardio(name);

                    return GestureDetector(
                      onTap: () => _switchExercise(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.all(isActive ? 16 : 12),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary.withValues(alpha: 0.06)
                              : allDone
                                  ? const Color(0xFF4ADE80).withValues(alpha: 0.04)
                                  : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isActive
                                ? AppColors.primary.withValues(alpha: 0.3)
                                : allDone
                                    ? const Color(0xFF4ADE80).withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.06),
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Exercise header row
                            Row(
                              children: [
                                // Icon
                                Container(
                                  width: isActive ? 40 : 36,
                                  height: isActive ? 40 : 36,
                                  decoration: BoxDecoration(
                                    color: allDone
                                        ? const Color(0xFF4ADE80).withValues(alpha: 0.15)
                                        : isActive
                                            ? AppColors.primary.withValues(alpha: 0.15)
                                            : Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(isActive ? 12 : 10),
                                  ),
                                  child: allDone
                                      ? const Icon(Icons.check_rounded, size: 20, color: Color(0xFF4ADE80))
                                      : isActive
                                          ? const Icon(Icons.play_arrow_rounded, size: 22, color: AppColors.primary)
                                          : Icon(Icons.fitness_center_rounded, size: 18, color: Colors.grey[600]),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: isActive ? 16 : 14,
                                          fontWeight: FontWeight.w700,
                                          color: allDone ? const Color(0xFF4ADE80) : AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        isExCardio ? '$totalSets sessioni' : '$totalSets Sets  •  $reps Target',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isActive ? AppColors.primary : Colors.grey[500],
                                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Badge
                                if (isActive && !allDone)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6, height: 6,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        const Text(
                                          'ACTIVE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (allDone)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4ADE80).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF4ADE80)),
                                        SizedBox(width: 4),
                                        Text(
                                          'DONE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF4ADE80),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Text(
                                    '$completedCount/$totalSets',
                                    style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w700,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                              ],
                            ),

                            // Expanded set grid (when active)
                            if (isActive) ...[
                              const SizedBox(height: 14),
                              // Set header row
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 40),
                                    if (isExCardio) ...[
                                      Expanded(child: Text('Durata', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600]), textAlign: TextAlign.center)),
                                      Expanded(child: Text('Distanza', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600]), textAlign: TextAlign.center)),
                                    ] else ...[
                                      Expanded(child: Text('Reps', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600]), textAlign: TextAlign.center)),
                                      Expanded(child: Text('Peso (kg)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600]), textAlign: TextAlign.center)),
                                    ],
                                    const SizedBox(width: 36),
                                  ],
                                ),
                              ),
                              // Set rows
                              ...List.generate(perf.length, (setIdx) {
                                final setPerf = perf[setIdx] as Map<String, dynamic>;
                                final isDone = setPerf['completed'] == true;
                                final isCurrent = setIdx == activeSet && !isCompleted;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 5),
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: isDone
                                        ? const Color(0xFF4ADE80).withValues(alpha: 0.05)
                                        : isCurrent
                                            ? AppColors.primary.withValues(alpha: 0.05)
                                            : Colors.white.withValues(alpha: 0.02),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDone
                                          ? const Color(0xFF4ADE80).withValues(alpha: 0.1)
                                          : isCurrent
                                              ? AppColors.primary.withValues(alpha: 0.2)
                                              : Colors.white.withValues(alpha: 0.05),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Set number / icon
                                      SizedBox(
                                        width: 34,
                                        child: isDone
                                            ? const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF4ADE80))
                                            : isCurrent
                                                ? Icon(Icons.play_arrow_rounded, size: 18, color: AppColors.primary)
                                                : Text(
                                                    '${setIdx + 1}',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[600]),
                                                  ),
                                      ),
                                      if (isExCardio) ...[
                                        Expanded(child: _SetInput(
                                          value: setPerf['duration']?.toString() ?? '',
                                          hint: 'min',
                                          enabled: !isDone,
                                          onChanged: (v) => setState(() {
                                            (exList[index]['performance'] as List)[setIdx]['duration'] = v;
                                          }),
                                        )),
                                        const SizedBox(width: 6),
                                        Expanded(child: _SetInput(
                                          value: setPerf['distance']?.toString() ?? '',
                                          hint: 'km',
                                          enabled: !isDone,
                                          onChanged: (v) => setState(() {
                                            (exList[index]['performance'] as List)[setIdx]['distance'] = v;
                                          }),
                                        )),
                                      ] else ...[
                                        Expanded(child: _SetInput(
                                          value: isDone ? (setPerf['reps']?.toString() ?? '') : (setPerf['reps']?.toString() ?? ''),
                                          hint: reps,
                                          enabled: !isDone,
                                          onChanged: (v) => setState(() {
                                            (exList[index]['performance'] as List)[setIdx]['reps'] = v;
                                          }),
                                        )),
                                        const SizedBox(width: 6),
                                        Expanded(child: _SetInput(
                                          value: setPerf['weight']?.toString() ?? '',
                                          hint: 'kg',
                                          enabled: !isDone,
                                          onChanged: (v) => setState(() {
                                            (exList[index]['performance'] as List)[setIdx]['weight'] = v;
                                          }),
                                        )),
                                      ],
                                      const SizedBox(width: 4),
                                      // Status icon
                                      SizedBox(
                                        width: 28,
                                        child: isDone
                                            ? const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF4ADE80))
                                            : Icon(Icons.radio_button_unchecked_rounded, size: 18, color: Colors.grey[700]),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // ─── Rest Timer Overlay ────────────────────────────
          if (isResting)
            Positioned.fill(
              child: GestureDetector(
                onTap: _skipRest,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.95),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$restSeconds',
                        style: const TextStyle(
                          fontSize: 96,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Periodo di Riposo',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          'Salta Riposo',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Cardio Input ────────────────────────────────────────────────

class _CardioInput extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _CardioInput({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: TextField(
            controller: TextEditingController(text: value),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ─── Set Input Field ──────────────────────────────────────────────

class _SetInput extends StatefulWidget {
  final String value;
  final String hint;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _SetInput({
    required this.value,
    required this.hint,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_SetInput> createState() => _SetInputState();
}

class _SetInputState extends State<_SetInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_SetInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update from external value if the field isn't focused
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: _controller,
        enabled: widget.enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[700]),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// WORKOUT BUILDER PAGE — 3-Step Wizard (matches HTML version)
// ═══════════════════════════════════════════════════════════════

class WorkoutBuilderPage extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  final Map<String, dynamic>? existingWorkout;

  const WorkoutBuilderPage({super.key, required this.onSaved, this.existingWorkout});

  @override
  ConsumerState<WorkoutBuilderPage> createState() => _WorkoutBuilderPageState();
}

class _WorkoutBuilderPageState extends ConsumerState<WorkoutBuilderPage>
    with SingleTickerProviderStateMixin {
  int _step = 0; // 0=details, 1=select exercises, 2=configure
  bool _saving = false;

  // Validation
  bool _titleError = false;
  bool _exercisesError = false;
  late AnimationController _wiggleController;
  late Animation<double> _wiggleAnimation;

  // Step 1: Details
  late TextEditingController _titleCtrl;
  late TextEditingController _durationCtrl;
  String _difficulty = 'Intermedio';
  static const _difficulties = ['Principiante', 'Intermedio', 'Avanzato', 'Elite'];

  // Step 2: Exercise library
  List<Map<String, dynamic>> _library = [];
  bool _libraryLoading = true;
  String _searchQuery = '';
  String _filterMuscle = 'Tutti';
  String _filterType = 'Tutti';

  // Selected exercises (shared across step 2 & 3)
  final List<_ExerciseEntry> _selected = [];

  bool get _isEditing => widget.existingWorkout != null;

  @override
  void initState() {
    super.initState();
    final w = widget.existingWorkout;
    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _wiggleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: -3), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -3, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _wiggleController, curve: Curves.easeOut));
    _titleCtrl = TextEditingController(text: w?['title'] ?? '');
    _durationCtrl = TextEditingController(text: w?['duration']?.toString().replaceAll(' min', '') ?? '45');
    if (w != null) {
      _difficulty = w['difficulty'] ?? 'Intermedio';
      for (final e in (w['exercises'] as List<dynamic>? ?? [])) {
        if (e is Map<String, dynamic>) {
          _selected.add(_ExerciseEntry(
            name: e['name'] ?? '',
            muscle: e['muscle'] ?? '',
            type: e['type'] ?? '',
            videoId: e['video_id']?.toString(),
            sets: (e['sets'] as num?)?.toInt() ?? 3,
            reps: e['reps']?.toString() ?? '10',
            rest: (e['rest'] as num?)?.toInt() ?? 60,
          ));
        }
      }
    }
    _loadLibrary();
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    _titleCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary() async {
    try {
      final exercises = await ref.read(clientServiceProvider).getExerciseLibrary();
      if (mounted) setState(() { _library = exercises; _libraryLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _libraryLoading = false);
    }
  }

  void _triggerWiggle() {
    _wiggleController.reset();
    _wiggleController.forward();
  }

  void _nextStep() {
    if (_step == 0) {
      if (_titleCtrl.text.trim().isEmpty) {
        setState(() => _titleError = true);
        _triggerWiggle();
        return;
      }
      setState(() { _titleError = false; _step = 1; });
    } else if (_step == 1) {
      if (_selected.isEmpty) {
        setState(() => _exercisesError = true);
        _triggerWiggle();
        return;
      }
      setState(() { _exercisesError = false; _step = 2; });
    } else {
      _save();
    }
  }

  void _prevStep() {
    if (_step > 0) setState(() => _step -= 1);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF252525)),
    );
  }

  void _toggleExercise(Map<String, dynamic> ex) {
    final idx = _selected.indexWhere((e) => e.name == ex['name']);
    setState(() {
      if (idx >= 0) {
        _selected.removeAt(idx);
      } else {
        _selected.add(_ExerciseEntry(
          name: ex['name'] ?? '',
          muscle: ex['muscle'] ?? '',
          type: ex['type'] ?? '',
          videoId: ex['video_id']?.toString(),
        ));
        if (_exercisesError) _exercisesError = false;
      }
    });
  }

  bool _isSelected(String name) => _selected.any((e) => e.name == name);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final service = ref.read(clientServiceProvider);
      final duration = '${_durationCtrl.text.trim()} min';
      final exercises = _selected.map((e) => {
        'name': e.name,
        'muscle': e.muscle,
        'type': e.type,
        'video_id': e.videoId ?? '',
        'sets': e.sets,
        'reps': e.reps,
        'rest': e.rest,
      }).toList();

      if (_isEditing) {
        await service.updateClientWorkout(widget.existingWorkout!['id'].toString(), {
          'title': _titleCtrl.text.trim(),
          'duration': duration,
          'difficulty': _difficulty,
          'exercises': exercises,
        });
      } else {
        await service.createWorkout(
          title: _titleCtrl.text.trim(),
          duration: duration,
          difficulty: _difficulty,
          exercises: exercises,
        );
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) _showSnack('Errore: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> get _muscleFilters {
    final muscles = _library.map((e) => e['muscle']?.toString() ?? '').where((m) => m.isNotEmpty).toSet().toList()..sort();
    return ['Tutti', ...muscles];
  }

  List<String> get _typeFilters {
    final types = _library.map((e) => e['type']?.toString() ?? '').where((t) => t.isNotEmpty).toSet().toList()..sort();
    return ['Tutti', ...types];
  }

  List<Map<String, dynamic>> get _filteredLibrary {
    return _library.where((ex) {
      final name = (ex['name'] ?? '').toString().toLowerCase();
      final muscle = (ex['muscle'] ?? '').toString();
      final type = (ex['type'] ?? '').toString();
      if (_searchQuery.isNotEmpty && !name.contains(_searchQuery.toLowerCase())) return false;
      if (_filterMuscle != 'Tutti' && muscle != _filterMuscle) return false;
      if (_filterType != 'Tutti' && type != _filterType) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  // Step dots
                  Row(children: List.generate(3, (i) => _buildStepDot(i))),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Step content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _step == 0
                    ? _buildStep1()
                    : _step == 1
                        ? _buildStep2()
                        : _buildStep3(),
              ),
            ),

            // Bottom buttons
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
              ),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: _prevStep,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF252525),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Indietro', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: AnimatedBuilder(
                      animation: _wiggleAnimation,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(_wiggleAnimation.value, 0),
                        child: child,
                      ),
                      child: GestureDetector(
                        onTap: _saving ? null : _nextStep,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _saving
                              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                              : Text(
                                  _step < 2 ? 'Avanti' : (_isEditing ? 'Aggiorna Allenamento' : 'Crea Allenamento'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                                ),
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

  Widget _buildStepDot(int i) {
    final isActive = i == _step;
    final isCompleted = i < _step;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 24 : 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFF22C55E)
            : isActive
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // ── Step 1: Workout Details ──────────────────────────────────

  Widget _buildStep1() {
    return ListView(
      key: const ValueKey('step1'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        Text(
          _isEditing ? 'Modifica Allenamento' : 'Nuovo Allenamento',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text('Dettagli base', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        const SizedBox(height: 24),

        // Title
        _inputLabel('Titolo Allenamento', error: _titleError),
        const SizedBox(height: 6),
        _buildInput(_titleCtrl, 'es. Push Day, Full Body...', error: _titleError, onChanged: (_) {
          if (_titleError) setState(() => _titleError = false);
        }),
        const SizedBox(height: 18),

        // Duration
        _inputLabel('Durata (minuti)'),
        const SizedBox(height: 6),
        _buildInput(_durationCtrl, 'es. 45', keyboard: TextInputType.number),
        const SizedBox(height: 18),

        // Difficulty
        _inputLabel('Difficoltà'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _difficulties.map((d) {
            final active = _difficulty == d;
            return GestureDetector(
              onTap: () => setState(() => _difficulty = d),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary.withValues(alpha: 0.15) : const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(10),
                  border: active ? Border.all(color: AppColors.primary.withValues(alpha: 0.4)) : null,
                ),
                child: Text(d, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.primary : Colors.grey[500])),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _inputLabel(String text, {bool error = false}) => Text(
    text,
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: error ? AppColors.danger : Colors.grey[400]),
  );

  Widget _buildInput(TextEditingController ctrl, String hint, {TextInputType keyboard = TextInputType.text, bool error = false, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        filled: true,
        fillColor: error ? AppColors.danger.withValues(alpha: 0.08) : const Color(0xFF252525),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: error ? const BorderSide(color: AppColors.danger, width: 1.5) : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: error ? AppColors.danger : AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  // ── Step 2: Select Exercises ─────────────────────────────────

  Widget _buildStep2() {
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Seleziona Esercizi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _exercisesError ? AppColors.danger : AppColors.textPrimary)),
              const SizedBox(height: 4),
              if (_exercisesError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('Seleziona almeno un esercizio', style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w500)),
                ),
              if (_selected.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${_selected.length} esercizi selezionati', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              const SizedBox(height: 14),
              // Search
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cerca esercizi...',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[600], size: 20),
                  filled: true,
                  fillColor: const Color(0xFF252525),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              // Filters
              Row(
                children: [
                  Expanded(child: _buildDropdown(_filterMuscle, _muscleFilters, (v) => setState(() => _filterMuscle = v))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildDropdown(_filterType, _typeFilters, (v) => setState(() => _filterType = v))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Exercise list
        Expanded(
          child: _libraryLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: _filteredLibrary.length,
                  itemBuilder: (ctx, i) => _buildLibraryItem(_filteredLibrary[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String value, List<String> items, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          dropdownColor: const Color(0xFF252525),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[600], size: 18),
          items: items.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }

  Widget _buildLibraryItem(Map<String, dynamic> ex) {
    final name = ex['name'] ?? '';
    final muscle = ex['muscle'] ?? '';
    final type = ex['type'] ?? '';
    final selected = _isSelected(name);

    return GestureDetector(
      onTap: () => _toggleExercise(ex),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: AppColors.primary, width: 1.5) : null,
        ),
        child: Row(
          children: [
            // Muscle icon
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: selected ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.fitness_center_rounded, size: 18, color: selected ? AppColors.primary : Colors.grey[500]),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? AppColors.textPrimary : Colors.grey[300])),
                  if (muscle.isNotEmpty || type.isNotEmpty)
                    Text([muscle, type].where((s) => s.isNotEmpty).join(' • '), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            // Add indicator
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: selected ? null : Border.all(color: Colors.grey[700]!),
              ),
              child: Icon(
                selected ? Icons.check_rounded : Icons.add_rounded,
                size: 16,
                color: selected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 3: Configure Exercises ──────────────────────────────

  Widget _buildStep3() {
    return Column(
      key: const ValueKey('step3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Configura Esercizi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Serie, ripetizioni e riposo', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _selected.isEmpty
              ? Center(child: Text('Nessun esercizio selezionato.', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey[600])))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: _selected.length,
                  onReorder: (oldIdx, newIdx) {
                    setState(() {
                      if (newIdx > oldIdx) newIdx--;
                      final item = _selected.removeAt(oldIdx);
                      _selected.insert(newIdx, item);
                    });
                  },
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      color: Colors.transparent,
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      child: child,
                    );
                  },
                  itemBuilder: (ctx, i) => _buildConfigCard(i),
                ),
        ),
      ],
    );
  }

  Widget _buildConfigCard(int index) {
    final ex = _selected[index];
    return Container(
      key: ValueKey('ex_${ex.name}_$index'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(6, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // Drag handle
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.drag_indicator_rounded, size: 20, color: Colors.grey[700]),
            ),
          ),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ex.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          if (ex.muscle.isNotEmpty || ex.type.isNotEmpty)
                            Text([ex.muscle, ex.type].where((s) => s.isNotEmpty).join(' • '), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _selected.removeAt(index)),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Sets / Reps / Rest
                Row(
                  children: [
                    _configField('SERIE', ex.sets.toString(), (v) => setState(() => ex.sets = int.tryParse(v) ?? 3)),
                    const SizedBox(width: 8),
                    _configField('REPS', ex.reps, (v) => setState(() => ex.reps = v)),
                    const SizedBox(width: 8),
                    _configField('RIPOSO', ex.rest.toString(), (v) => setState(() => ex.rest = int.tryParse(v) ?? 60), suffix: 's'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _configField(String label, String value, ValueChanged<String> onChanged, {String suffix = ''}) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[600], letterSpacing: 0.5)),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: value),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              suffixText: suffix.isNotEmpty ? suffix : null,
              suffixStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ExerciseEntry {
  String name;
  String muscle;
  String type;
  String? videoId;
  int sets;
  String reps;
  int rest;

  _ExerciseEntry({
    this.name = '',
    this.muscle = '',
    this.type = '',
    this.videoId,
    this.sets = 3,
    this.reps = '10',
    this.rest = 60,
  });
}

class _WorkoutPreviewPage extends StatelessWidget {
  final Map<String, dynamic> workout;
  final VoidCallback onStart;
  final VoidCallback onEdit;

  const _WorkoutPreviewPage({
    required this.workout,
    required this.onStart,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final exercises = workout['exercises'] as List<dynamic>? ?? [];
    final title = workout['title'] ?? 'Allenamento';
    final duration = workout['duration'] ?? '';
    final difficulty = workout['difficulty'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.textTertiary, size: 20),
                    onPressed: () {
                      Navigator.pop(context);
                      onEdit();
                    },
                  ),
                ],
              ),
            ),

            // Workout info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  if (duration.toString().isNotEmpty)
                    _infoPill(Icons.timer_outlined, '$duration min'),
                  if (difficulty.toString().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _infoPill(Icons.speed_rounded, difficulty.toString()),
                  ],
                  const SizedBox(width: 8),
                  _infoPill(Icons.fitness_center_rounded, '${exercises.length} esercizi'),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Exercise list
            Expanded(
              child: exercises.isEmpty
                  ? Center(
                      child: Text(
                        'Nessun esercizio',
                        style: TextStyle(color: Colors.grey[500], fontSize: 15),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: exercises.length,
                      itemBuilder: (ctx, i) {
                        final ex = exercises[i] as Map<String, dynamic>;
                        final name = ex['name'] ?? ex['exercise_name'] ?? 'Esercizio';
                        final sets = ex['sets'] ?? 3;
                        final reps = ex['reps'] ?? ex['target_reps'] ?? '10';
                        final rest = ex['rest'] ?? ex['rest_seconds'] ?? 60;
                        final muscle = ex['muscle_group'] ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              // Number
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$sets serie × $reps rep  •  ${rest}s riposo${muscle.isNotEmpty ? '  •  $muscle' : ''}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            // Start button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onStart();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Inizia Allenamento',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }
}

class _SplitEditorPage extends StatefulWidget {
  final List<Map<String, dynamic>> workouts;
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  final ClientService clientService;

  const _SplitEditorPage({
    required this.workouts,
    this.existing,
    required this.onSaved,
    required this.clientService,
  });

  @override
  State<_SplitEditorPage> createState() => _SplitEditorPageState();
}

class _SplitEditorPageState extends State<_SplitEditorPage> {
  late final TextEditingController _nameCtrl;
  late final Map<String, String?> _schedule;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?['name'] ?? '');
    final existingSchedule = widget.existing?['schedule'] as Map<String, dynamic>? ?? {};
    _schedule = {};
    for (int i = 0; i < 7; i++) {
      final val = existingSchedule[i.toString()];
      _schedule[i.toString()] = (val != null && val.toString().isNotEmpty) ? val.toString() : null;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un nome per la split')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final scheduleClean = Map<String, dynamic>.from(_schedule)..removeWhere((_, v) => v == null);
      if (widget.existing != null) {
        await widget.clientService.updateSplit(widget.existing!['id'], name: name, schedule: scheduleClean);
      } else {
        await widget.clientService.createSplit(name, scheduleClean);
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final dayNames = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.existing != null ? 'Modifica Split' : 'Nuova Split',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Nome Split',
                        labelStyle: TextStyle(color: Colors.grey[500]),
                        hintText: 'es. Push/Pull/Legs',
                        hintStyle: TextStyle(color: Colors.grey[700]),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...List.generate(7, (i) {
                      final workoutId = _schedule[i.toString()];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(dayNames[i],
                                style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14,
                                  color: workoutId != null ? AppColors.primary : Colors.grey[500],
                                )),
                            ),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: workoutId,
                                  hint: Text('Riposo', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                  dropdownColor: AppColors.surface,
                                  isExpanded: true,
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                                  items: [
                                    DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('Riposo', style: TextStyle(color: Colors.grey[600])),
                                    ),
                                    ...widget.workouts.map((w) => DropdownMenuItem<String>(
                                      value: w['id'].toString(),
                                      child: Text(w['title'] ?? 'Allenamento'),
                                    )),
                                  ],
                                  onChanged: (val) => setState(() => _schedule[i.toString()] = val),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(widget.existing != null ? 'Salva Modifiche' : 'Crea Split',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
