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
import '../services/client_service.dart';
import '../widgets/exercise_video.dart';

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

    final clientData = ref.watch(clientDataProvider);

    return clientData.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Errore: $e', style: const TextStyle(color: AppColors.textSecondary))),
      ),
      data: (data) {
        final workout = data.todayWorkout;
        if (workout == null) {
          return const _NoWorkoutView();
        }
        return _WorkoutView(
          workout: workout,
          coopPartnerId: coopPartnerId,
          coopPartnerName: coopPartnerName,
          coopPartnerPicture: coopPartnerPicture,
        );
      },
    );
  }
}

// ─── No Workout Assigned ──────────────────────────────────────────

class _NoWorkoutView extends StatelessWidget {
  const _NoWorkoutView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
              ],
            ),
          ),
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
              // ─── Hero Section (Exercise Video — expandable) ─────
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

