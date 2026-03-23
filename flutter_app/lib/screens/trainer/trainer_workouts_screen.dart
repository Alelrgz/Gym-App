import 'dart:io' show Platform;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../providers/trainer_provider.dart';
import '../../providers/client_provider.dart';
import '../../widgets/dashboard_sheets.dart';
import '../../widgets/glass_card.dart';

const double _kDesktopBreakpoint = 1024;

class TrainerWorkoutsScreen extends ConsumerStatefulWidget {
  const TrainerWorkoutsScreen({super.key});

  @override
  ConsumerState<TrainerWorkoutsScreen> createState() => _TrainerWorkoutsScreenState();
}

class _TrainerWorkoutsScreenState extends ConsumerState<TrainerWorkoutsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _desktopCenterTabCtrl;
  String _exerciseSearch = '';
  String _workoutSearch = '';
  String _clientSearch = '';

  // Desktop workout builder state
  bool _isBuilderMode = false;
  String? _editingWorkoutId; // null = creating, non-null = editing
  final _builderTitleCtrl = TextEditingController();
  final _builderDurationCtrl = TextEditingController();
  String _builderDifficulty = 'intermediate';
  final List<_BuilderExercise> _builderExercises = [];
  bool _isDragOver = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _desktopCenterTabCtrl = TabController(length: 2, vsync: this);
    _desktopCenterTabCtrl.addListener(() => setState(() {}));
    _builderTitleCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _desktopCenterTabCtrl.dispose();
    _builderTitleCtrl.dispose();
    _builderDurationCtrl.dispose();
    super.dispose();
  }

  void _enterBuilderMode() {
    setState(() {
      _isBuilderMode = true;
      _editingWorkoutId = null;
      _builderTitleCtrl.clear();
      _builderDurationCtrl.clear();
      _builderDifficulty = 'intermediate';
      _builderExercises.clear();
    });
  }

  void _enterEditMode(Map<String, dynamic> workout) {
    final exercises = workout['exercises'] as List? ?? [];
    setState(() {
      _isBuilderMode = true;
      _editingWorkoutId = workout['id']?.toString();
      _builderTitleCtrl.text = workout['title'] as String? ?? '';
      _builderDurationCtrl.text = workout['duration']?.toString() ?? '';
      _builderDifficulty = workout['difficulty'] as String? ?? 'intermediate';
      _builderExercises.clear();
      for (final e in exercises) {
        final m = Map<String, dynamic>.from(e as Map);
        _builderExercises.add(_BuilderExercise(
          id: m['exercise_id']?.toString() ?? m['id']?.toString() ?? '',
          name: m['name'] as String? ?? '',
          muscle: (m['muscle_group'] ?? m['muscle'] ?? '').toString(),
          sets: (m['sets'] as num?)?.toInt() ?? 3,
          reps: (m['reps'] as num?)?.toInt() ?? 10,
          rest: (m['rest'] as num?)?.toInt() ?? 60,
        ));
      }
    });
  }

  void _exitBuilderMode() {
    setState(() {
      _isBuilderMode = false;
      _editingWorkoutId = null;
      _builderExercises.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final trainerAsync = ref.watch(trainerDataProvider);
    final isDesktop = MediaQuery.of(context).size.width > _kDesktopBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: trainerAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Text('Errore: $e', style: const TextStyle(color: AppColors.textSecondary))),
          data: (trainer) => isDesktop
              ? _buildDesktop(trainer)
              : _buildMobile(trainer),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  DESKTOP: 3-column grid with drag-and-drop workout builder
  // ═══════════════════════════════════════════════════════════
  Widget _buildDesktop(dynamic trainer) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Allenamenti',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Crea e assegna allenamenti ai tuoi clienti',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT: Exercises (draggable)
                Expanded(
                  flex: 10,
                  child: _DesktopColumn(
                    title: 'Esercizi',
                    icon: Icons.fitness_center_rounded,
                    iconColor: AppColors.primary,
                    onAdd: () => _showCreateExerciseModal(context),
                    child: _DraggableExerciseList(
                      exercises: ref.watch(trainerExercisesProvider).valueOrNull ?? [],
                      search: _exerciseSearch,
                      onSearchChanged: (v) => setState(() => _exerciseSearch = v),
                      isDraggable: _isBuilderMode,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // CENTER: Workouts & Splits (tabbed) or Builder
                Expanded(
                  flex: 12,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.05),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _isBuilderMode
                        ? KeyedSubtree(key: const ValueKey('builder'), child: _buildWorkoutBuilder())
                        : KeyedSubtree(key: const ValueKey('list'), child: _buildDesktopCenterColumn(trainer)),
                  ),
                ),
                const SizedBox(width: 16),

                // RIGHT: Clients
                Expanded(
                  flex: 10,
                  child: _DesktopColumn(
                    title: 'Clienti',
                    icon: Icons.people_rounded,
                    iconColor: const Color(0xFF22C55E),
                    child: _ClientDropList(
                      clients: trainer.clients,
                      clientSearch: _clientSearch,
                      onSearchChanged: (v) => setState(() => _clientSearch = v),
                      service: ref.read(trainerServiceProvider),
                      onRefresh: () => ref.invalidate(trainerDataProvider),
                      splits: trainer.splits,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  WORKOUT BUILDER (center column in builder mode)
  // ═══════════════════════════════════════════════════════════
  Widget _buildWorkoutBuilder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with close button
        Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.build_rounded, size: 18, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 10),
            Text(_editingWorkoutId != null ? 'Modifica Workout' : 'Crea Workout', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Spacer(),
            GestureDetector(
              onTap: _exitBuilderMode,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.close_rounded, size: 18, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Builder content
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + Duration row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _BuilderInput(controller: _builderTitleCtrl, hint: 'Titolo workout'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: _BuilderInput(controller: _builderDurationCtrl, hint: 'Min', inputType: TextInputType.number),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Difficulty pills
                Row(
                  children: [
                    _difficultyPill('beginner', 'Principiante', const Color(0xFF22C55E)),
                    const SizedBox(width: 6),
                    _difficultyPill('intermediate', 'Intermedio', const Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    _difficultyPill('advanced', 'Avanzato', AppColors.danger),
                  ],
                ),
                const SizedBox(height: 16),

                // Exercise list label + global rest
                Row(
                  children: [
                    Icon(Icons.list_rounded, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      'Esercizi (${_builderExercises.length})',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[400]),
                    ),
                    const Spacer(),
                    if (_builderExercises.isNotEmpty) ...[
                      Icon(Icons.timer_outlined, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text('Tutti:', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      const SizedBox(width: 4),
                      _MiniInput(
                        initialValue: '${_builderExercises.first.rest}',
                        label: 's',
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null) {
                            setState(() {
                              for (final ex in _builderExercises) {
                                ex.rest = n;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      Text('s', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.drag_indicator_rounded, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('Trascina dalla lista', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
                const SizedBox(height: 8),

                // Added exercises (reorderable)
                if (_builderExercises.isNotEmpty)
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    proxyDecorator: (child, index, animation) => Material(
                      color: Colors.transparent,
                      elevation: 4,
                      borderRadius: BorderRadius.circular(14),
                      child: child,
                    ),
                    itemCount: _builderExercises.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _builderExercises.removeAt(oldIndex);
                        _builderExercises.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, i) {
                      final ex = _builderExercises[i];
                      return _BuilderExerciseCard(
                        key: ValueKey('${ex.id}_${i}_${ex.rest}'),
                        exercise: ex,
                        index: i,
                        onRemove: () => setState(() => _builderExercises.removeAt(i)),
                        onChanged: () => setState(() {}),
                      );
                    },
                  ),

                // Drop zone
                DragTarget<Map<String, dynamic>>(
                  onWillAcceptWithDetails: (_) {
                    if (!_isDragOver) setState(() => _isDragOver = true);
                    return true;
                  },
                  onLeave: (_) {
                    if (_isDragOver) setState(() => _isDragOver = false);
                  },
                  onAcceptWithDetails: (details) {
                    setState(() {
                      _isDragOver = false;
                      _builderExercises.add(_BuilderExercise(
                        id: details.data['id']?.toString() ?? '',
                        name: details.data['name'] as String? ?? '',
                        muscle: (details.data['muscle'] ?? details.data['muscle_group'] ?? '').toString(),
                      ));
                    });
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isHovering = candidateData.isNotEmpty || _isDragOver;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: isHovering
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isHovering
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.08),
                          width: isHovering ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            isHovering ? Icons.add_circle_rounded : Icons.drag_indicator_rounded,
                            size: 28,
                            color: isHovering ? AppColors.primary : Colors.grey[600],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isHovering ? 'Rilascia per aggiungere' : 'Trascina esercizi qui',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isHovering ? AppColors.primary : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                      disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
                    ),
                    onPressed: _builderTitleCtrl.text.isEmpty || _isSaving ? null : _saveWorkout,
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_editingWorkoutId != null ? 'SALVA MODIFICHE' : 'CREA WORKOUT', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _difficultyPill(String value, String label, Color color) {
    final isSelected = _builderDifficulty == value;
    return GestureDetector(
      onTap: () => setState(() => _builderDifficulty = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? color : Colors.grey[500]),
        ),
      ),
    );
  }

  Future<void> _saveWorkout() async {
    if (_builderTitleCtrl.text.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final exercises = _builderExercises.map((e) => {
        'exercise_id': e.id,
        'name': e.name,
        'sets': e.sets,
        'reps': e.reps,
        'rest': e.rest,
        'set_reps': e.setReps,
      }).toList();

      final payload = {
        'title': _builderTitleCtrl.text,
        'duration': _builderDurationCtrl.text,
        'difficulty': _builderDifficulty,
        'exercises': exercises,
      };

      final svc = ref.read(trainerServiceProvider);
      if (_editingWorkoutId != null) {
        await svc.updateWorkout(_editingWorkoutId!, payload);
      } else {
        await svc.createWorkout(payload);
      }
      ref.invalidate(trainerDataProvider);
      _exitBuilderMode();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  DESKTOP CENTER COLUMN: Workout | Split tabs
  // ═══════════════════════════════════════════════════════════
  Widget _buildDesktopCenterColumn(dynamic trainer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.view_list_rounded, size: 18, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 10),
            const Text('Allenamenti', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Spacer(),
            GestureDetector(
              onTap: _isBuilderMode
                  ? _exitBuilderMode
                  : _desktopCenterTabCtrl.index == 0
                      ? _enterBuilderMode
                      : () => _showCreateSplitForm(context, trainer.workouts),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: _isBuilderMode
                      ? AppColors.danger.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AnimatedRotation(
                  turns: _isBuilderMode ? 0.125 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _isBuilderMode ? Icons.close_rounded : Icons.add_rounded,
                    color: _isBuilderMode ? AppColors.danger : Colors.grey[400],
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Workout | Split tab bar
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _desktopCenterTabCtrl,
            indicator: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[500],
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            dividerColor: Colors.transparent,
            tabs: const [Tab(text: 'Workout'), Tab(text: 'Split')],
          ),
        ),
        const SizedBox(height: 10),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _desktopCenterTabCtrl,
            children: [
              // Workout tab
              _WorkoutList(
                workouts: trainer.workouts,
                search: _workoutSearch,
                onSearchChanged: (v) => setState(() => _workoutSearch = v),
                clients: trainer.clients,
                service: ref.read(trainerServiceProvider),
                onRefresh: () => ref.invalidate(trainerDataProvider),
                onEdit: _enterEditMode,
              ),
              // Split tab
              _SplitList(
                splits: trainer.splits,
                service: ref.read(trainerServiceProvider),
                onRefresh: () => ref.invalidate(trainerDataProvider),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Searchable workout picker for split day assignment.
  /// Returns workout id, '__rest__' for rest, or null if dismissed.
  Future<String?> _showWorkoutPicker(BuildContext context, List<Map<String, dynamic>> workouts, String? currentId) async {
    String search = '';
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPickerState) {
          final filtered = workouts.where((w) {
            if (search.isEmpty) return true;
            return (w['title'] as String? ?? '').toLowerCase().contains(search.toLowerCase());
          }).toList();
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Cerca workout...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.grey[500]),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setPickerState(() => search = v),
                ),
                const SizedBox(height: 8),
                // Rest option
                ListTile(
                  dense: true,
                  leading: Icon(Icons.hotel_rounded, size: 20, color: Colors.grey[500]),
                  title: Text('— Riposo —', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                  selected: currentId == null,
                  selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onTap: () => Navigator.pop(ctx, '__rest__'),
                ),
                const Divider(height: 1),
                // Workout list
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.4),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final w = filtered[i];
                      final id = w['id']?.toString() ?? '';
                      final title = w['title'] as String? ?? '';
                      final exCount = (w['exercises'] as List?)?.length ?? 0;
                      final isSelected = id == currentId;
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.fitness_center_rounded, size: 18, color: isSelected ? AppColors.primary : Colors.grey[500]),
                        title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isSelected ? AppColors.primary : AppColors.textPrimary)),
                        subtitle: Text('$exCount esercizi', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        selected: isSelected,
                        selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onTap: () => Navigator.pop(ctx, id),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCreateSplitForm(BuildContext context, List<Map<String, dynamic>> workouts) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int daysPerWeek = 5;
    final Map<int, String?> schedule = {};

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
              const Text('Crea Split', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              // Name + Description
              Row(
                children: [
                  Expanded(child: _InputField(controller: nameCtrl, label: 'Nome', hint: 'Es. Push/Pull/Legs')),
                  const SizedBox(width: 8),
                  Expanded(child: _InputField(controller: descCtrl, label: 'Descrizione', hint: 'Opzionale')),
                ],
              ),
              const SizedBox(height: 12),
              // Days per week
              Row(
                children: [
                  Text('Giorni/settimana:', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    height: 36,
                    child: TextField(
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: '$daysPerWeek'),
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n >= 1 && n <= 7) {
                          setModalState(() => daysPerWeek = n);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Day rows
              ...List.generate(daysPerWeek, (i) {
                final day = i + 1;
                final selectedId = schedule[day];
                final selectedName = selectedId != null
                    ? (workouts.firstWhere((w) => w['id']?.toString() == selectedId, orElse: () => {})['title'] as String? ?? selectedId)
                    : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text('Giorno $day', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final result = await _showWorkoutPicker(ctx, workouts, selectedId);
                            if (result != null) {
                              setModalState(() => schedule[day] = result == '__rest__' ? null : result);
                            }
                          },
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    selectedName ?? '— Riposo —',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: selectedName != null ? AppColors.textPrimary : Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down_rounded, size: 20, color: Colors.grey[500]),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        if (nameCtrl.text.isEmpty) return;
                        try {
                          final scheduleMap = <String, String?>{};
                          for (var i = 1; i <= daysPerWeek; i++) {
                            scheduleMap['$i'] = schedule[i];
                          }
                          await ref.read(trainerServiceProvider).createSplit({
                            'name': nameCtrl.text,
                            'description': descCtrl.text,
                            'days_per_week': daysPerWeek,
                            'schedule': scheduleMap,
                          });
                          ref.invalidate(trainerDataProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Errore: $e')));
                          }
                        }
                      },
                      child: const Text('Crea Split', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Annulla', style: TextStyle(color: Colors.grey[500])),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  MOBILE: Tabbed layout (unchanged)
  // ═══════════════════════════════════════════════════════════
  Widget _buildMobile(dynamic trainer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Allenamenti',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Crea e assegna allenamenti ai tuoi clienti',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey[500],
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Esercizi'),
                Tab(text: 'Workout'),
                Tab(text: 'Split'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ExerciseTab(
                exercises: ref.watch(trainerExercisesProvider).valueOrNull ?? [],
                search: _exerciseSearch,
                onSearchChanged: (v) => setState(() => _exerciseSearch = v),
                onRefresh: () => ref.invalidate(trainerExercisesProvider),
                onCreateExercise: () => _showCreateExerciseModal(context),
              ),
              _WorkoutTab(
                workouts: trainer.workouts,
                search: _workoutSearch,
                onSearchChanged: (v) => setState(() => _workoutSearch = v),
                onCreateWorkout: () => _showCreateWorkoutModal(context),
                clients: trainer.clients,
                service: ref.read(trainerServiceProvider),
                onRefresh: () => ref.invalidate(trainerDataProvider),
              ),
              _SplitTab(
                splits: trainer.splits,
                service: ref.read(trainerServiceProvider),
                onRefresh: () => ref.invalidate(trainerDataProvider),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCreateExerciseModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final muscleCtrl = TextEditingController();
    final videoUrlCtrl = TextEditingController();
    String type = 'weight_reps';
    XFile? pickedVideo;
    bool creating = false;

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
              const Text('Crea Esercizio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              _InputField(controller: nameCtrl, label: 'Nome Esercizio', hint: 'es. Panca Piana'),
              const SizedBox(height: 12),
              _InputField(controller: muscleCtrl, label: 'Gruppo Muscolare', hint: 'es. Petto'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: type,
                dropdownColor: AppColors.surface,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Tipo',
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: const [
                  DropdownMenuItem(value: 'weight_reps', child: Text('Peso & Ripetizioni')),
                  DropdownMenuItem(value: 'cardio', child: Text('Cardio')),
                  DropdownMenuItem(value: 'bodyweight', child: Text('Corpo Libero')),
                ],
                onChanged: (v) => type = v ?? type,
              ),
              const SizedBox(height: 12),
              // Video section: URL or file pick
              Text('Video (opzionale)', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: videoUrlCtrl,
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'URL YouTube o link diretto',
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final video = await picker.pickVideo(source: ImageSource.gallery);
                      if (video != null) {
                        setModalState(() {
                          pickedVideo = video;
                          videoUrlCtrl.text = video.name;
                        });
                      }
                    },
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: pickedVideo != null
                            ? AppColors.primary.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: pickedVideo != null
                            ? Border.all(color: AppColors.primary.withValues(alpha: 0.5))
                            : null,
                      ),
                      child: Icon(
                        pickedVideo != null ? Icons.check_circle_rounded : Icons.video_library_rounded,
                        size: 22,
                        color: pickedVideo != null ? AppColors.primary : Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: creating ? null : () async {
                    if (nameCtrl.text.isEmpty) return;
                    setModalState(() => creating = true);
                    try {
                      final service = ref.read(trainerServiceProvider);
                      final data = <String, dynamic>{
                        'name': nameCtrl.text,
                        'muscle_group': muscleCtrl.text,
                        'type': type,
                      };
                      // If URL provided (and no file picked), include it
                      if (pickedVideo == null && videoUrlCtrl.text.trim().isNotEmpty) {
                        data['video_url'] = videoUrlCtrl.text.trim();
                      }
                      final created = await service.createExercise(data);
                      // If a video file was picked, upload it now
                      if (pickedVideo != null && created['id'] != null) {
                        try {
                          await service.uploadExerciseVideo(
                            created['id'].toString(),
                            pickedVideo!.path,
                            pickedVideo!.name,
                          );
                        } catch (_) {
                          // Exercise created but video upload failed — still close
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Esercizio creato, ma errore upload video'), backgroundColor: Colors.orange),
                            );
                          }
                        }
                      }
                      ref.invalidate(trainerExercisesProvider);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Errore: $e')));
                      }
                    }
                    if (ctx.mounted) setModalState(() => creating = false);
                  },
                  child: creating
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('CREA ESERCIZIO', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateWorkoutModal(BuildContext context) {
    final titleCtrl = TextEditingController();
    final durationCtrl = TextEditingController();
    String difficulty = 'intermediate';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Crea Workout', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _InputField(controller: titleCtrl, label: 'Titolo', hint: 'es. Upper Body A'),
            const SizedBox(height: 12),
            _InputField(controller: durationCtrl, label: 'Durata (min)', hint: 'es. 45', inputType: TextInputType.number),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: difficulty,
              dropdownColor: AppColors.surface,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Difficolta',
                labelStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: const [
                DropdownMenuItem(value: 'beginner', child: Text('Principiante')),
                DropdownMenuItem(value: 'intermediate', child: Text('Intermedio')),
                DropdownMenuItem(value: 'advanced', child: Text('Avanzato')),
              ],
              onChanged: (v) => difficulty = v ?? difficulty,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (titleCtrl.text.isEmpty) return;
                  try {
                    await ref.read(trainerServiceProvider).createWorkout({
                      'title': titleCtrl.text,
                      'duration': durationCtrl.text,
                      'difficulty': difficulty,
                      'exercises': [],
                    });
                    ref.invalidate(trainerDataProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Errore: $e')));
                    }
                  }
                },
                child: const Text('CREA WORKOUT', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  BUILDER DATA MODEL
// ═══════════════════════════════════════════════════════════
class _BuilderExercise {
  final String id;
  final String name;
  final String muscle;
  List<int> setReps; // reps per set, length = number of sets
  int rest;

  _BuilderExercise({
    required this.id,
    required this.name,
    required this.muscle,
    int sets = 3,
    int reps = 10,
    this.rest = 60,
    List<int>? setReps,
  }) : setReps = setReps ?? List.filled(sets, reps, growable: true);

  int get sets => setReps.length;
  int get reps => setReps.isNotEmpty ? setReps[0] : 10;
}

// ═══════════════════════════════════════════════════════════
//  BUILDER EXERCISE CARD (with sets/reps inline edit)
// ═══════════════════════════════════════════════════════════
class _BuilderExerciseCard extends StatefulWidget {
  final _BuilderExercise exercise;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _BuilderExerciseCard({
    super.key,
    required this.exercise,
    required this.index,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_BuilderExerciseCard> createState() => _BuilderExerciseCardState();
}

class _BuilderExerciseCardState extends State<_BuilderExerciseCard> {
  bool _expanded = false;
  int _repsVersion = 0; // bump to force _MiniInput rebuild after "Tutti"

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: _expanded ? 0.25 : 0.12)),
        ),
        child: Column(
          children: [
            // Header row — tap to expand, drag handle on the right
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    // Index badge
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${widget.index + 1}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Name + muscle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ex.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          if (ex.muscle.isNotEmpty)
                            Text(ex.muscle, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    // Summary: sets x reps · rest
                    Text(
                      '${ex.sets}x${ex.reps}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400]),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.timer_outlined, size: 11, color: Colors.grey[600]),
                    Text(
                      '${ex.rest}s',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 4),
                    // Expand indicator
                    Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 18, color: Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    // Remove button
                    GestureDetector(
                      onTap: widget.onRemove,
                      child: Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(Icons.close_rounded, size: 15, color: AppColors.danger),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Drag handle
                    ReorderableDragStartListener(
                      index: widget.index,
                      child: Icon(Icons.drag_indicator_rounded, size: 20, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),

            // Expanded: per-set reps + rest + add set
            if (_expanded) ...[
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Row(
                  children: [
                    Text('Recupero', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const SizedBox(width: 8),
                    _MiniInput(
                      initialValue: '${ex.rest}',
                      label: 's',
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null) setState(() => ex.rest = n);
                      },
                    ),
                    Text(' sec', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ),
              // Per-set rows
              ...ex.setReps.asMap().entries.map((entry) {
                final si = entry.key;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                  child: Row(
                    children: [
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${si + 1}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Rep', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      const SizedBox(width: 6),
                      _MiniInput(
                        key: ValueKey('rep_${si}_$_repsVersion'),
                        initialValue: '${entry.value}',
                        label: '',
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null) ex.setReps[si] = n;
                        },
                      ),
                      // Copy first set reps to all — only show on first row when multiple sets
                      if (si == 0 && ex.setReps.length > 1) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              final val = ex.setReps[0];
                              for (int i = 1; i < ex.setReps.length; i++) {
                                ex.setReps[i] = val;
                              }
                              _repsVersion++;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy_rounded, size: 12, color: AppColors.primary),
                                const SizedBox(width: 3),
                                Text('Tutti', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (ex.setReps.length > 1)
                        GestureDetector(
                          onTap: () {
                            setState(() => ex.setReps.removeAt(si));
                          },
                          child: Icon(Icons.remove_circle_outline_rounded, size: 16, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                );
              }),
              // Add set button
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      ex.setReps.add(ex.setReps.isNotEmpty ? ex.setReps.last : 10);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text('Aggiungi Set', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniInput extends StatefulWidget {
  final String initialValue;
  final String label;
  final ValueChanged<String> onChanged;

  const _MiniInput({super.key, required this.initialValue, required this.label, required this.onChanged});

  @override
  State<_MiniInput> createState() => _MiniInputState();
}

class _MiniInputState extends State<_MiniInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 32,
      child: TextField(
        controller: _ctrl,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

class _BuilderInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType inputType;

  const _BuilderInput({required this.controller, required this.hint, this.inputType = TextInputType.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  DESKTOP COLUMN WRAPPER
// ═══════════════════════════════════════════════════════════
class _DesktopColumn extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onAdd;
  final Widget child;

  const _DesktopColumn({
    required this.title,
    required this.icon,
    required this.iconColor,
    this.onAdd,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[400])),
            const Spacer(),
            if (onAdd != null)
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.add_rounded, color: Colors.grey[400], size: 18),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(child: child),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  DRAGGABLE EXERCISE LIST (desktop — items are draggable)
// ═══════════════════════════════════════════════════════════
class _DraggableExerciseList extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final bool isDraggable;

  const _DraggableExerciseList({
    required this.exercises,
    required this.search,
    required this.onSearchChanged,
    required this.isDraggable,
  });

  @override
  State<_DraggableExerciseList> createState() => _DraggableExerciseListState();
}

class _DraggableExerciseListState extends State<_DraggableExerciseList> {
  String _muscleFilter = '';

  Widget _filterChip(String label, String value) {
    final selected = _muscleFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _muscleFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: selected ? AppColors.primary : Colors.grey[500],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Collect unique muscle groups
    final muscles = <String>{};
    for (final e in widget.exercises) {
      final m = (e['muscle'] ?? e['muscle_group'] ?? '').toString();
      if (m.isNotEmpty) muscles.add(m);
    }
    final sortedMuscles = muscles.toList()..sort();

    final filtered = widget.exercises.where((e) {
      final name = (e['name'] as String? ?? '').toLowerCase();
      final muscle = (e['muscle'] ?? e['muscle_group'] ?? '').toString();
      if (widget.search.isNotEmpty && !name.contains(widget.search.toLowerCase())) return false;
      if (_muscleFilter.isNotEmpty && muscle != _muscleFilter) return false;
      return true;
    }).toList();

    return Column(
      children: [
        _SearchBar(hint: 'Cerca esercizi...', onChanged: widget.onSearchChanged),
        const SizedBox(height: 6),
        SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip('Tutti', ''),
              ...sortedMuscles.map((m) => _filterChip(m, m)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('Nessun esercizio', style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final ex = filtered[index];
                    final muscle = ex['muscle'] ?? ex['muscle_group'] ?? '';
                    final card = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ex['name'] as String? ?? '',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                                if (muscle.toString().isNotEmpty)
                                  Text(muscle.toString(), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                          if (widget.isDraggable)
                            Icon(Icons.drag_indicator_rounded, size: 16, color: Colors.grey[700])
                          else
                            Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey[700]),
                        ],
                      ),
                    );

                    if (!widget.isDraggable) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: GestureDetector(
                          onTap: () => _showExerciseDetail(context, ex),
                          child: card,
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Draggable<Map<String, dynamic>>(
                        data: ex,
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: 280,
                            child: Opacity(
                              opacity: 0.85,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.fitness_center_rounded, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        ex['name'] as String? ?? '',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(opacity: 0.3, child: card),
                        child: card,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  DESKTOP WORKOUT LIST
// ═══════════════════════════════════════════════════════════
class _WorkoutList extends StatelessWidget {
  final List<Map<String, dynamic>> workouts;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final List clients;
  final dynamic service;
  final VoidCallback onRefresh;
  final void Function(Map<String, dynamic>)? onEdit;

  const _WorkoutList({
    required this.workouts,
    required this.search,
    required this.onSearchChanged,
    required this.clients,
    required this.service,
    required this.onRefresh,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = workouts.where((w) {
      if (search.isEmpty) return true;
      return (w['title'] as String? ?? '').toLowerCase().contains(search.toLowerCase());
    }).toList();

    return Column(
      children: [
        _SearchBar(hint: 'Cerca workout...', onChanged: onSearchChanged),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('Nessun workout', style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final w = filtered[index];
                    final exercises = w['exercises'] as List? ?? [];
                    final difficulty = w['difficulty'] as String? ?? '';
                    final diffColor = switch (difficulty) {
                      'beginner' => const Color(0xFF22C55E),
                      'intermediate' => const Color(0xFFF59E0B),
                      'advanced' => AppColors.danger,
                      _ => Colors.grey,
                    };
                    final diffLabel = switch (difficulty) {
                      'beginner' => 'Principiante',
                      'intermediate' => 'Intermedio',
                      'advanced' => 'Avanzato',
                      _ => difficulty,
                    };

                    final workoutCard = GlassCard(
                      padding: const EdgeInsets.all(14),
                      borderRadius: 16,
                      onTap: () => _showWorkoutActions(context, w),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.primary.withValues(alpha: 0.05)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.fitness_center_rounded, size: 18, color: AppColors.primary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w['title'] as String? ?? '',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (w['duration'] != null && w['duration'].toString().isNotEmpty)
                                      _MetaChip(icon: Icons.timer_outlined, text: '${w['duration']} min'),
                                    if (exercises.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      _MetaChip(icon: Icons.list_rounded, text: '${exercises.length} es.'),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (difficulty.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: diffColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                diffLabel,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: diffColor),
                              ),
                            ),
                        ],
                      ),
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Draggable<Map<String, dynamic>>(
                        data: {'type': 'workout', 'id': w['id'], 'title': w['title'] ?? ''},
                        feedback: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: 260,
                            child: Opacity(
                              opacity: 0.85,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.fitness_center_rounded, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        w['title'] as String? ?? '',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(opacity: 0.3, child: workoutCard),
                        child: workoutCard,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showWorkoutActions(BuildContext context, Map<String, dynamic> workout) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              workout['title'] as String? ?? 'Workout',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            _ActionRow(
              icon: Icons.edit_rounded,
              label: 'Modifica',
              onTap: () {
                Navigator.pop(ctx);
                if (onEdit != null) {
                  onEdit!(workout);
                } else {
                  _showEditWorkoutSheet(context, workout, service, onRefresh);
                }
              },
            ),
            _ActionRow(
              icon: Icons.person_add_rounded,
              label: 'Assegna a un cliente',
              onTap: () {
                Navigator.pop(ctx);
                _showAssignModal(context, workout);
              },
            ),
            _ActionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Elimina',
              color: AppColors.danger,
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await service.deleteWorkout(workout['id'].toString());
                  onRefresh();
                } catch (_) {}
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAssignModal(BuildContext context, Map<String, dynamic> workout) {
    final dateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assegna "${workout['title']}"',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            _InputField(controller: dateCtrl, label: 'Data di inizio', hint: 'YYYY-MM-DD'),
            const SizedBox(height: 12),
            const Text('Seleziona cliente:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...clients.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await service.assignWorkout({
                      'workout_id': workout['id'],
                      'client_id': c.id,
                      'start_date': dateCtrl.text,
                    });
                    onRefresh();
                  } catch (_) {}
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text(c.name[0].toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ),
                      const SizedBox(width: 10),
                      Text(c.name, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _SplitList extends StatelessWidget {
  final List<Map<String, dynamic>> splits;
  final dynamic service;
  final VoidCallback onRefresh;

  const _SplitList({required this.splits, required this.service, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (splits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_week_rounded, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text('Nessuno split creato', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: splits.length,
      itemBuilder: (context, index) {
        final s = splits[index];
        final splitCard = GlassCard(
          padding: const EdgeInsets.all(14),
          borderRadius: 16,
          onTap: () => _showSplitActions(context, s),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.view_week_rounded, size: 18, color: Color(0xFF8B5CF6)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s['name'] as String? ?? 'Split',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    if (s['description'] != null && (s['description'] as String).isNotEmpty)
                      Text(s['description'] as String, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    if (s['days_per_week'] != null)
                      Text('${s['days_per_week']} giorni/sett.', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Draggable<Map<String, dynamic>>(
            data: {'type': 'split', 'id': s['id'], 'name': s['name'] ?? 'Split'},
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 260,
                child: Opacity(
                  opacity: 0.85,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.view_week_rounded, size: 18, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            s['name'] as String? ?? 'Split',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: splitCard),
            child: splitCard,
          ),
        );
      },
    );
  }

  void _showSplitActions(BuildContext context, Map<String, dynamic> split) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              split['name'] as String? ?? 'Split',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            _ActionRow(
              icon: Icons.edit_rounded,
              label: 'Modifica',
              onTap: () {
                Navigator.pop(ctx);
                _showEditSplitModal(context, split);
              },
            ),
            _ActionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Elimina',
              color: AppColors.danger,
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await service.deleteSplit(split['id'].toString());
                  onRefresh();
                } catch (_) {}
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditSplitModal(BuildContext context, Map<String, dynamic> split) {
    final nameCtrl = TextEditingController(text: split['name'] as String? ?? '');
    final descCtrl = TextEditingController(text: split['description'] as String? ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Modifica Split', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _InputField(controller: nameCtrl, label: 'Nome', hint: 'Es. Push/Pull/Legs'),
            const SizedBox(height: 12),
            _InputField(controller: descCtrl, label: 'Descrizione', hint: 'Opzionale'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  try {
                    await service.updateSplit(split['id'].toString(), {
                      'name': nameCtrl.text,
                      'description': descCtrl.text,
                    });
                    onRefresh();
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Errore: $e')));
                    }
                  }
                },
                child: const Text('SALVA', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  CLIENT DROP LIST (right column on desktop)
// ═══════════════════════════════════════════════════════════
class _ClientDropList extends StatelessWidget {
  final List clients;
  final String clientSearch;
  final ValueChanged<String> onSearchChanged;
  final dynamic service;
  final VoidCallback onRefresh;
  final List<Map<String, dynamic>> splits;

  const _ClientDropList({
    required this.clients,
    required this.clientSearch,
    required this.onSearchChanged,
    required this.service,
    required this.onRefresh,
    required this.splits,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = clients.where((c) {
      if (clientSearch.isEmpty) return true;
      return c.name.toLowerCase().contains(clientSearch.toLowerCase());
    }).toList();

    return Column(
      children: [
        _SearchBar(hint: 'Cerca clienti...', onChanged: onSearchChanged),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('Nessun cliente', style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final c = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _ClientCard(
                        client: c,
                        service: service,
                        onRefresh: onRefresh,
                        splits: splits,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ClientCard extends ConsumerStatefulWidget {
  final dynamic client;
  final dynamic service;
  final VoidCallback onRefresh;
  final List<Map<String, dynamic>> splits;

  const _ClientCard({required this.client, required this.service, required this.onRefresh, required this.splits});

  @override
  ConsumerState<_ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends ConsumerState<_ClientCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final client = widget.client;

    // Determine badge
    Widget badge;
    if (client.assignedSplit != null && client.assignedSplit.toString().isNotEmpty) {
      final expiry = client.planExpiry;
      final expiryText = expiry != null ? ' · scade $expiry' : '';
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
        ),
        child: Text(
          '${client.assignedSplit}$expiryText',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFA5B4FC)),
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else if (client.upcomingWorkouts != null && client.upcomingWorkouts > 0) {
      final count = client.upcomingWorkouts;
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.25)),
        ),
        child: Text(
          '$count allenament${count == 1 ? 'o' : 'i'}',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF86EFAC)),
        ),
      );
    } else {
      badge = Text(
        'Nessun programma',
        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white.withValues(alpha: 0.25)),
      );
    }

    final cardContent = GestureDetector(
      onTap: () => _showClientModal(context, client),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _isHovering
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovering
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
            width: _isHovering ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  _isHovering
                      ? Text(
                          'Rilascia per assegnare',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary.withValues(alpha: 0.8)),
                        )
                      : badge,
                ],
              ),
            ),
            if (_isHovering)
              Icon(Icons.add_circle_rounded, size: 20, color: AppColors.primary.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) {
        final type = details.data['type'];
        if (type == 'workout' || type == 'split') {
          if (!_isHovering) setState(() => _isHovering = true);
          return true;
        }
        return false;
      },
      onLeave: (_) {
        if (_isHovering) setState(() => _isHovering = false);
      },
      onAcceptWithDetails: (details) async {
        setState(() => _isHovering = false);
        final data = details.data;
        final type = data['type'] as String;
        final itemName = type == 'workout' ? data['title'] : data['name'];

        try {
          if (type == 'workout') {
            await widget.service.assignWorkout({
              'workout_id': data['id'],
              'client_id': client.id,
              'date': DateTime.now().toIso8601String().substring(0, 10),
            });
          } else {
            await widget.service.assignSplit({
              'split_id': data['id'],
              'client_id': client.id,
            });
          }
          widget.onRefresh();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$itemName assegnato a ${client.name}'),
                backgroundColor: const Color(0xFF22C55E),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Errore: $e')),
            );
          }
        }
      },
      builder: (context, candidateData, rejectedData) {
        if (candidateData.isNotEmpty && !_isHovering) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isHovering = true);
          });
        }
        return cardContent;
      },
    );
  }

  void _showClientModal(BuildContext context, dynamic client) {
    final isAtRisk = client.status == 'A Rischio' || client.status == 'at_risk';
    final statusColor = isAtRisk ? AppColors.danger : const Color(0xFF22C55E);
    final statusText = isAtRisk ? 'A Rischio' : 'Attivo';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.80),
      transitionDuration: const Duration(milliseconds: 600),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: const Cubic(0.16, 1, 0.3, 1),
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 320,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    color: const Color(0xFF252525),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            client.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Text('✕', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.5))),
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Status card
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            _showMetricsModal(context, client);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF252525),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'STATO',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0.5),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      statusText,
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: statusColor),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.bar_chart_rounded, size: 16, color: Colors.white.withValues(alpha: 0.35)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Statistiche',
                                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Vedi Programma
                        _WebAppModalBtn(
                          icon: Icons.assignment_rounded,
                          label: 'Vedi Programma',
                          onTap: () {
                            Navigator.pop(ctx);
                            context.go('/trainer/schedule');
                          },
                        ),
                        const SizedBox(height: 8),

                        // Prenota Appuntamento
                        _WebAppModalBtn(
                          icon: Icons.calendar_today_rounded,
                          label: 'Prenota Appuntamento',
                          onTap: () {
                            Navigator.pop(ctx);
                            context.go('/trainer/schedule');
                          },
                        ),
                        const SizedBox(height: 8),

                        // Gestisci Dieta (only for premium)
                        if (client.isPremium) ...[
                          _WebAppModalBtn(
                            icon: Icons.restaurant_rounded,
                            label: 'Gestisci Dieta',
                            onTap: () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Gestione dieta - Prossimamente')),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Assegna Scheda Settimanale
                        _WebAppModalBtn(
                          icon: Icons.layers_rounded,
                          label: 'Assegna Scheda Settimanale',
                          onTap: () {
                            Navigator.pop(ctx);
                            _showAssignSplitModal(context, client);
                          },
                        ),
                        const SizedBox(height: 8),

                        // Messaggia Cliente (primary - orange)
                        _WebAppModalBtn(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Messaggia Cliente',
                          isPrimary: true,
                          onTap: () {
                            Navigator.pop(ctx);
                            _openChatWithClient(context, client);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMetricsModal(BuildContext context, dynamic client) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.90),
      transitionDuration: const Duration(milliseconds: 600),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: const Cubic(0.16, 1, 0.3, 1),
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: _ClientMetricsContent(
              clientId: client.id,
              clientName: client.name,
              service: widget.service,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openChatWithClient(BuildContext context, dynamic client) async {
    try {
      final service = ref.read(clientServiceProvider);
      final conversations = await service.getConversations();
      // Find existing conversation with this client
      Map<String, dynamic>? conv;
      for (final c in conversations) {
        if (c['other_user_id']?.toString() == client.id) {
          conv = Map<String, dynamic>.from(c);
          break;
        }
      }
      // If no existing conversation, create a minimal one to open the chat
      conv ??= {
        'id': '',
        'other_user_id': client.id,
        'other_user_name': client.name,
        'other_user_profile_picture': client.profilePicture,
      };
      if (mounted) {
        showChatSheet(context, ref, conv);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore apertura chat: $e')),
        );
      }
    }
  }

  void _showAssignSplitModal(BuildContext context, dynamic client) {
    final splits = widget.splits;
    if (splits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessuno split disponibile. Creane uno prima.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assegna Split a ${client.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Seleziona uno split da assegnare',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            ...splits.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await widget.service.assignSplit({
                      'split_id': s['id'],
                      'client_id': client.id,
                    });
                    widget.onRefresh();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${s['name']} assegnato a ${client.name}'),
                          backgroundColor: const Color(0xFF22C55E),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Errore: $e')),
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.view_week_rounded, size: 18, color: Color(0xFF8B5CF6)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['name'] as String? ?? 'Split',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            if (s['days_per_week'] != null)
                              Text('${s['days_per_week']} giorni/sett.', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.grey[500]),
                    ],
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _WebAppModalBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _WebAppModalBtn({
    required this.icon,
    required this.label,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFFF15A24) : const Color(0xFF252525),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? Colors.transparent : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.85)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  MOBILE TAB WIDGETS (unchanged)
// ═══════════════════════════════════════════════════════════
class _ExerciseTab extends StatelessWidget {
  final List<Map<String, dynamic>> exercises;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;
  final VoidCallback onCreateExercise;

  const _ExerciseTab({
    required this.exercises,
    required this.search,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onCreateExercise,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = exercises.where((e) {
      if (search.isEmpty) return true;
      return (e['name'] as String? ?? '').toLowerCase().contains(search.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Expanded(child: _SearchBar(hint: 'Cerca esercizi...', onChanged: onSearchChanged)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onCreateExercise,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 22),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('Nessun esercizio', style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final ex = filtered[index];
                    final muscle = ex['muscle'] ?? ex['muscle_group'] ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GestureDetector(
                        onTap: () => _showExerciseDetail(context, ex),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ex['name'] as String? ?? '',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                    ),
                                    if (muscle.toString().isNotEmpty)
                                      Text(muscle.toString(), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey[700]),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

}

void _showExerciseDetail(BuildContext context, Map<String, dynamic> ex) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => _ExerciseDetailSheet(exercise: ex, scrollController: scrollCtrl),
    ),
  );
}

class _ExerciseDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> exercise;
  final ScrollController scrollController;

  const _ExerciseDetailSheet({required this.exercise, required this.scrollController});

  @override
  ConsumerState<_ExerciseDetailSheet> createState() => _ExerciseDetailSheetState();
}

class _ExerciseDetailSheetState extends ConsumerState<_ExerciseDetailSheet> {
  late Map<String, dynamic> _exercise;
  Player? _player;
  VideoController? _videoCtrl;
  bool _hasVideo = false;

  @override
  void initState() {
    super.initState();
    _exercise = Map<String, dynamic>.from(widget.exercise);
    _initVideo();
  }

  void _initVideo() {
    final ex = _exercise;
    final videoUrl = ex['video_url']?.toString();
    final videoId = ex['video_id']?.toString();

    String? url;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      url = videoUrl.startsWith('http') ? videoUrl : '${ApiConfig.baseUrl}$videoUrl';
    } else if (videoId != null && videoId.isNotEmpty) {
      url = '${ApiConfig.baseUrl}/static/videos/$videoId.mp4';
    }

    if (url != null) {
      _hasVideo = true;
      _player = Player();
      _videoCtrl = VideoController(_player!);
      _player!.setPlaylistMode(PlaylistMode.loop);
      _player!.open(Media(url)).catchError((_) {
        if (mounted) setState(() => _hasVideo = false);
      });
      // Listen for errors and stop showing spinner if video fails
      _player!.stream.error.listen((error) {
        if (mounted && error.isNotEmpty) {
          setState(() => _hasVideo = false);
          _player?.dispose();
          _player = null;
          _videoCtrl = null;
        }
      });
    }
  }

  void _reloadVideo() {
    _player?.dispose();
    _player = null;
    _videoCtrl = null;
    _hasVideo = false;
    _initVideo();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ex = _exercise;
    final name = ex['name'] as String? ?? '';
    final muscle = (ex['muscle'] ?? ex['muscle_group'] ?? '') as String;
    final type = ex['type'] as String? ?? '';
    final difficulty = ex['difficulty'] as String? ?? '';
    final description = ex['description'] as String? ?? '';
    final steps = ex['steps'] as List<dynamic>? ?? [];
    final defaultDuration = ex['default_duration'];

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // Drag handle
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
          ),
        ),

        // Video
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildVideoWidget(),
          ),
        ),
        const SizedBox(height: 16),

        // Name & muscle + edit button
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  if (muscle.isNotEmpty)
                    Text(muscle, style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showEditModal(context),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.edit_rounded, size: 20, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: const Text('Elimina Esercizio', style: TextStyle(color: AppColors.textPrimary)),
                    content: Text('Vuoi eliminare "${_exercise['name']}"?', style: TextStyle(color: Colors.grey[400])),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annulla', style: TextStyle(color: Colors.grey[500]))),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina', style: TextStyle(color: AppColors.danger))),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  try {
                    final id = _exercise['id']?.toString() ?? '';
                    await ref.read(trainerServiceProvider).deleteExercise(id);
                    ref.invalidate(trainerExercisesProvider);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
                    }
                  }
                }
              },
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.delete_rounded, size: 20, color: AppColors.danger),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Info chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (type.isNotEmpty) _infoChip(Icons.category_rounded, _formatType(type)),
            if (difficulty.isNotEmpty) _infoChip(Icons.speed_rounded, _formatDifficulty(difficulty)),
            if (defaultDuration != null) _infoChip(Icons.timer_outlined, '${defaultDuration}s'),
          ],
        ),

        // Description
        if (description.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Descrizione', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(description, style: TextStyle(fontSize: 14, color: Colors.grey[400], height: 1.5)),
        ],

        // Steps
        if (steps.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Passaggi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          ...steps.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(entry.value.toString(), style: TextStyle(fontSize: 13, color: Colors.grey[400], height: 1.4))),
              ],
            ),
          )),
        ],

        // No extra info placeholder
        if (description.isEmpty && steps.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.info_outline_rounded, size: 32, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text('Nessuna descrizione disponibile', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showEditModal(BuildContext context) {
    final nameCtrl = TextEditingController(text: _exercise['name'] as String? ?? '');
    final muscleCtrl = TextEditingController(text: (_exercise['muscle'] ?? _exercise['muscle_group'] ?? '') as String);
    final descCtrl = TextEditingController(text: _exercise['description'] as String? ?? '');
    final videoUrlCtrl = TextEditingController(text: _exercise['video_url'] as String? ?? '');
    final durationCtrl = TextEditingController(text: '${_exercise['default_duration'] ?? 60}');
    String type = _exercise['type'] as String? ?? 'weight_reps';
    String difficulty = _exercise['difficulty'] as String? ?? 'intermediate';
    final stepsCtrl = TextEditingController(
      text: (_exercise['steps'] as List<dynamic>? ?? []).join('\n'),
    );
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Modifica Esercizio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(Icons.close_rounded, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _EditField(controller: nameCtrl, label: 'Nome'),
                const SizedBox(height: 12),
                _EditField(controller: muscleCtrl, label: 'Gruppo Muscolare'),
                const SizedBox(height: 12),
                _EditField(controller: descCtrl, label: 'Descrizione', maxLines: 3),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _EditField(controller: videoUrlCtrl, label: 'Video URL (opzionale)')),
                    const SizedBox(width: 8),
                    _VideoUploadButton(
                      exerciseId: _exercise['id'].toString(),
                      onUploaded: (updatedEx) {
                        setModalState(() => videoUrlCtrl.text = '');
                        _exercise = {..._exercise, 'video_id': updatedEx['video_id']};
                        setState(() {});
                        _reloadVideo();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: type,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        decoration: _editInputDecoration('Tipo'),
                        items: const [
                          DropdownMenuItem(value: 'weight_reps', child: Text('Peso & Ripetizioni')),
                          DropdownMenuItem(value: 'cardio', child: Text('Cardio')),
                          DropdownMenuItem(value: 'bodyweight', child: Text('Corpo Libero')),
                          DropdownMenuItem(value: 'Compound', child: Text('Compound')),
                        ],
                        onChanged: (v) => setModalState(() => type = v ?? type),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: difficulty,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        decoration: _editInputDecoration('Difficoltà'),
                        items: const [
                          DropdownMenuItem(value: 'beginner', child: Text('Principiante')),
                          DropdownMenuItem(value: 'intermediate', child: Text('Intermedio')),
                          DropdownMenuItem(value: 'advanced', child: Text('Avanzato')),
                        ],
                        onChanged: (v) => setModalState(() => difficulty = v ?? difficulty),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _EditField(controller: durationCtrl, label: 'Durata Default (secondi)', keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _EditField(controller: stepsCtrl, label: 'Passaggi (uno per riga)', maxLines: 4),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: saving ? null : () async {
                      setModalState(() => saving = true);
                      final steps = stepsCtrl.text.split('\n').where((s) => s.trim().isNotEmpty).toList();
                      final data = {
                        'name': nameCtrl.text.trim(),
                        'muscle_group': muscleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'video_url': videoUrlCtrl.text.trim().isEmpty ? null : videoUrlCtrl.text.trim(),
                        'type': type,
                        'difficulty': difficulty,
                        'default_duration': int.tryParse(durationCtrl.text) ?? 60,
                        'steps': steps,
                      };
                      try {
                        final service = ref.read(trainerServiceProvider);
                        await service.updateExercise(_exercise['id'].toString(), data);
                        if (ctx.mounted) Navigator.pop(ctx);
                        // Update local state
                        _exercise = {..._exercise, ...data, 'muscle': muscleCtrl.text.trim()};
                        setState(() {});
                        _reloadVideo();
                        ref.invalidate(trainerExercisesProvider);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Errore: $e'), backgroundColor: AppColors.danger),
                          );
                        }
                      }
                      setModalState(() => saving = false);
                    },
                    child: saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Salva Modifiche', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _editInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[500]),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildVideoWidget() {
    if (!_hasVideo || _videoCtrl == null) {
      return Container(
        color: Colors.grey[900],
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded, size: 40, color: Colors.grey[600]),
              const SizedBox(height: 8),
              Text('Nessun video', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    return Video(
      controller: _videoCtrl!,
      controls: AdaptiveVideoControls,
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }

  String _formatType(String type) {
    switch (type) {
      case 'weight_reps': return 'Peso & Rip.';
      case 'cardio': return 'Cardio';
      case 'bodyweight': return 'Corpo Libero';
      default: return type;
    }
  }

  String _formatDifficulty(String diff) {
    switch (diff) {
      case 'beginner': return 'Principiante';
      case 'intermediate': return 'Intermedio';
      case 'advanced': return 'Avanzato';
      default: return diff;
    }
  }
}

class _WorkoutTab extends StatelessWidget {
  final List<Map<String, dynamic>> workouts;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreateWorkout;
  final List clients;
  final dynamic service;
  final VoidCallback onRefresh;

  const _WorkoutTab({
    required this.workouts,
    required this.search,
    required this.onSearchChanged,
    required this.onCreateWorkout,
    required this.clients,
    required this.service,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = workouts.where((w) {
      if (search.isEmpty) return true;
      return (w['title'] as String? ?? '').toLowerCase().contains(search.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Expanded(child: _SearchBar(hint: 'Cerca workout...', onChanged: onSearchChanged)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onCreateWorkout,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 22),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('Nessun workout', style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final w = filtered[index];
                    final exercises = w['exercises'] as List? ?? [];
                    final difficulty = w['difficulty'] as String? ?? '';
                    final diffColor = switch (difficulty) {
                      'beginner' => const Color(0xFF22C55E),
                      'intermediate' => const Color(0xFFF59E0B),
                      'advanced' => AppColors.danger,
                      _ => Colors.grey,
                    };
                    final diffLabel = switch (difficulty) {
                      'beginner' => 'Principiante',
                      'intermediate' => 'Intermedio',
                      'advanced' => 'Avanzato',
                      _ => difficulty,
                    };

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        padding: const EdgeInsets.all(14),
                        borderRadius: 16,
                        onTap: () => _showWorkoutActions(context, w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.primary.withValues(alpha: 0.05)],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.fitness_center_rounded, size: 20, color: AppColors.primary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        w['title'] as String? ?? '',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          if (w['duration'] != null && w['duration'].toString().isNotEmpty)
                                            _MetaChip(icon: Icons.timer_outlined, text: '${w['duration']} min'),
                                          if (exercises.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            _MetaChip(icon: Icons.list_rounded, text: '${exercises.length} es.'),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (difficulty.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: diffColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      diffLabel,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: diffColor),
                                    ),
                                  ),
                              ],
                            ),
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

  void _showWorkoutActions(BuildContext context, Map<String, dynamic> workout) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              workout['title'] as String? ?? 'Workout',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            _ActionRow(
              icon: Icons.edit_rounded,
              label: 'Modifica',
              onTap: () {
                Navigator.pop(ctx);
                _showEditWorkoutSheet(context, workout, service, onRefresh);
              },
            ),
            _ActionRow(
              icon: Icons.person_add_rounded,
              label: 'Assegna a un cliente',
              onTap: () {
                Navigator.pop(ctx);
                _showAssignModal(context, workout);
              },
            ),
            _ActionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Elimina',
              color: AppColors.danger,
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await service.deleteWorkout(workout['id'].toString());
                  onRefresh();
                } catch (_) {}
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAssignModal(BuildContext context, Map<String, dynamic> workout) {
    final dateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assegna "${workout['title']}"',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            _InputField(controller: dateCtrl, label: 'Data di inizio', hint: 'YYYY-MM-DD'),
            const SizedBox(height: 12),
            const Text('Seleziona cliente:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            ...clients.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await service.assignWorkout({
                      'workout_id': workout['id'],
                      'client_id': c.id,
                      'start_date': dateCtrl.text,
                    });
                    onRefresh();
                  } catch (_) {}
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text(c.name[0].toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ),
                      const SizedBox(width: 10),
                      Text(c.name, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _SplitTab extends StatelessWidget {
  final List<Map<String, dynamic>> splits;
  final dynamic service;
  final VoidCallback onRefresh;

  const _SplitTab({required this.splits, required this.service, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (splits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_week_rounded, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text('Nessuno split creato', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      itemCount: splits.length,
      itemBuilder: (context, index) {
        final s = splits[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            borderRadius: 16,
            onTap: () => _showSplitActions(context, s),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.view_week_rounded, size: 20, color: Color(0xFF8B5CF6)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['name'] as String? ?? 'Split',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      if (s['description'] != null && (s['description'] as String).isNotEmpty)
                        Text(s['description'] as String, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      if (s['days_per_week'] != null)
                        Text('${s['days_per_week']} giorni/settimana', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey[600]),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSplitActions(BuildContext context, Map<String, dynamic> split) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              split['name'] as String? ?? 'Split',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            _ActionRow(
              icon: Icons.edit_rounded,
              label: 'Modifica',
              onTap: () {
                Navigator.pop(ctx);
                _showEditSplitModal(context, split);
              },
            ),
            _ActionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Elimina',
              color: AppColors.danger,
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await service.deleteSplit(split['id'].toString());
                  onRefresh();
                } catch (_) {}
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditSplitModal(BuildContext context, Map<String, dynamic> split) {
    final nameCtrl = TextEditingController(text: split['name'] as String? ?? '');
    final descCtrl = TextEditingController(text: split['description'] as String? ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Modifica Split', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _InputField(controller: nameCtrl, label: 'Nome', hint: 'Es. Push/Pull/Legs'),
            const SizedBox(height: 12),
            _InputField(controller: descCtrl, label: 'Descrizione', hint: 'Opzionale'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  try {
                    await service.updateSplit(split['id'].toString(), {
                      'name': nameCtrl.text,
                      'description': descCtrl.text,
                    });
                    onRefresh();
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Errore: $e')));
                    }
                  }
                },
                child: const Text('SALVA', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.grey[600]),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType inputType;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.inputType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
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
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey[500]),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SHARED EDIT WORKOUT SHEET (used by desktop + mobile)
// ═══════════════════════════════════════════════════════════

class _EditExercise {
  String id;
  String name;
  String muscle;
  int sets;
  int reps;
  int rest;

  _EditExercise({
    required this.id,
    required this.name,
    this.muscle = '',
    this.sets = 3,
    this.reps = 10,
    this.rest = 60,
  });

  factory _EditExercise.fromMap(Map<String, dynamic> m) => _EditExercise(
    id: m['exercise_id']?.toString() ?? m['id']?.toString() ?? '',
    name: m['name'] as String? ?? '',
    muscle: m['muscle_group'] as String? ?? m['muscle'] as String? ?? '',
    sets: (m['sets'] as num?)?.toInt() ?? 3,
    reps: (m['reps'] as num?)?.toInt() ?? 10,
    rest: (m['rest'] as num?)?.toInt() ?? 60,
  );

  Map<String, dynamic> toMap() => {
    'exercise_id': id,
    'name': name,
    'sets': sets,
    'reps': reps,
    'rest': rest,
  };
}

void _showEditWorkoutSheet(
  BuildContext context,
  Map<String, dynamic> workout,
  dynamic service,
  VoidCallback onRefresh,
) {
  final titleCtrl = TextEditingController(text: workout['title'] as String? ?? '');
  final durationCtrl = TextEditingController(text: workout['duration']?.toString() ?? '');
  String difficulty = workout['difficulty'] as String? ?? 'intermediate';
  final rawExercises = workout['exercises'] as List? ?? [];
  final exercises = rawExercises.map((e) => _EditExercise.fromMap(Map<String, dynamic>.from(e as Map))).toList();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (ctx, scrollCtrl) => Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const Text('Modifica Workout', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                _InputField(controller: titleCtrl, label: 'Titolo', hint: 'es. Upper Body A'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _InputField(controller: durationCtrl, label: 'Durata (min)', hint: '45', inputType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: difficulty,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Difficolta',
                          labelStyle: TextStyle(color: Colors.grey[500]),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'beginner', child: Text('Principiante')),
                          DropdownMenuItem(value: 'intermediate', child: Text('Intermedio')),
                          DropdownMenuItem(value: 'advanced', child: Text('Avanzato')),
                        ],
                        onChanged: (v) => difficulty = v ?? difficulty,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Esercizi (${exercises.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Expanded(
                  child: exercises.isEmpty
                      ? Center(child: Text('Nessun esercizio', style: TextStyle(color: Colors.grey[600])))
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: exercises.length,
                          itemBuilder: (ctx, i) {
                            final ex = exercises[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24, height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(ex.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                        if (ex.muscle.isNotEmpty)
                                          Text(ex.muscle, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                      ],
                                    ),
                                  ),
                                  _MiniInput(
                                    initialValue: '${ex.sets}',
                                    label: 'Set',
                                    onChanged: (v) => ex.sets = int.tryParse(v) ?? ex.sets,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('x', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                  const SizedBox(width: 4),
                                  _MiniInput(
                                    initialValue: '${ex.reps}',
                                    label: 'Rep',
                                    onChanged: (v) => ex.reps = int.tryParse(v) ?? ex.reps,
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.timer_outlined, size: 12, color: Colors.grey[600]),
                                  const SizedBox(width: 2),
                                  _MiniInput(
                                    initialValue: '${ex.rest}',
                                    label: 's',
                                    onChanged: (v) => ex.rest = int.tryParse(v) ?? ex.rest,
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => setModalState(() => exercises.removeAt(i)),
                                    child: Icon(Icons.close_rounded, size: 16, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (titleCtrl.text.isEmpty) return;
                      try {
                        await service.updateWorkout(workout['id'].toString(), {
                          'title': titleCtrl.text,
                          'duration': durationCtrl.text,
                          'difficulty': difficulty,
                          'exercises': exercises.map((e) => e.toMap()).toList(),
                        });
                        onRefresh();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Errore: $e')));
                        }
                      }
                    },
                    child: const Text('SALVA', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionRow({required this.icon, required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: c),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  CLIENT METRICS MODAL CONTENT
// ═══════════════════════════════════════════════════════════

class _ClientMetricsContent extends StatefulWidget {
  final String clientId;
  final String clientName;
  final dynamic service;

  const _ClientMetricsContent({
    required this.clientId,
    required this.clientName,
    required this.service,
  });

  @override
  State<_ClientMetricsContent> createState() => _ClientMetricsContentState();
}

class _ClientMetricsContentState extends State<_ClientMetricsContent> {
  bool _loading = true;

  // Weight data
  List<dynamic> _weightData = [];
  double? _currentWeight;
  double? _weightChange;
  dynamic _goalWeight;

  // Diet data
  int _dietStreak = 0;
  int _dietAvg = 0;
  int _dietDays = 0;
  List<dynamic> _dietData = [];

  // Strength data
  Map<String, dynamic> _strengthData = {};

  // Streak data
  int _dayStreak = 0;
  List<dynamic> _days = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadWeight(),
      _loadDiet(),
      _loadStrength(),
      _loadStreak(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadWeight() async {
    try {
      final data = await widget.service.getClientWeightHistory(widget.clientId);
      final list = data['data'] as List<dynamic>? ?? [];
      if (list.isNotEmpty) {
        final current = (list.last['weight'] as num).toDouble();
        final first = (list.first['weight'] as num).toDouble();
        _weightData = list;
        _currentWeight = current;
        _weightChange = current - first;
        _goalWeight = data['goal_weight'];
      }
    } catch (_) {}
  }

  Future<void> _loadDiet() async {
    try {
      final data = await widget.service.getClientDietConsistency(widget.clientId);
      _dietStreak = data['current_streak'] as int? ?? 0;
      _dietAvg = data['average_score'] as int? ?? 0;
      _dietDays = data['total_days'] as int? ?? 0;
      _dietData = data['data'] as List<dynamic>? ?? [];
    } catch (_) {}
  }

  Future<void> _loadStrength() async {
    try {
      _strengthData = await widget.service.getClientStrengthProgress(widget.clientId);
    } catch (_) {}
  }

  Future<void> _loadStreak() async {
    try {
      final data = await widget.service.getClientWeekStreak(widget.clientId);
      _dayStreak = data['current_streak'] as int? ?? 0;
      _days = data['days'] as List<dynamic>? ?? [];
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isDesktop = screenW > 700;
    final modalWidth = isDesktop ? 700.0 : screenW * 0.95;

    return Container(
      width: modalWidth,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Metriche Cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text('Analisi Prestazioni per ${widget.clientName}',
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text('✕', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.5))),
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFFF97316))),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Column(
                      children: [
                        // Quick Stats Row
                        _buildQuickStats(),
                        const SizedBox(height: 12),
                        // Charts
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildWeightCard()),
                              const SizedBox(width: 12),
                              Expanded(child: _buildDietCard()),
                            ],
                          )
                        else ...[
                          _buildWeightCard(),
                          const SizedBox(height: 12),
                          _buildDietCard(),
                        ],
                        const SizedBox(height: 12),
                        _buildStrengthCard(),
                        const SizedBox(height: 12),
                        _buildDaysGrid(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        _quickStat(_currentWeight?.toStringAsFixed(1) ?? '--', 'Peso (kg)', Colors.white),
        const SizedBox(width: 8),
        _quickStat('$_dayStreak', 'Serie Giorni', const Color(0xFFF97316)),
        const SizedBox(width: 8),
        _quickStat('$_dietAvg', 'Dieta %', const Color(0xFF22C55E)),
        const SizedBox(width: 8),
        _quickStat(
          _strengthData.isNotEmpty ? '${_strengthData['total_workouts'] ?? '--'}' : '--',
          'Forza',
          const Color(0xFF60A5FA),
        ),
      ],
    );
  }

  Widget _quickStat(String value, String label, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: valueColor)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.35), letterSpacing: 0.3),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightCard() {
    final hasData = _weightData.isNotEmpty;
    final changeText = _weightChange != null
        ? '${_weightChange! >= 0 ? '+' : ''}${_weightChange!.toStringAsFixed(1)} kg'
        : '--';
    final changeColor = (_weightChange ?? 0) >= 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return _chartCard(
      title: 'Progresso Peso',
      trailing: Text(changeText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: changeColor)),
      height: 200,
      child: hasData
          ? _buildWeightBars()
          : _emptyChart('Nessun dato peso'),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Attuale: ${_currentWeight?.toStringAsFixed(1) ?? '--'} kg',
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.35))),
          Text('Obiettivo: ${_goalWeight ?? '--'} kg',
              style: const TextStyle(fontSize: 10, color: Color(0xFFF97316))),
        ],
      ),
    );
  }

  Widget _buildWeightBars() {
    if (_weightData.isEmpty) return _emptyChart('Nessun dato');
    final weights = _weightData.map((d) => (d['weight'] as num).toDouble()).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b) - 1;
    final maxW = weights.reduce((a, b) => a > b ? a : b) + 1;
    final range = maxW - minW;

    return LayoutBuilder(builder: (_, constraints) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(weights.length, (i) {
          final pct = range > 0 ? (weights[i] - minW) / range : 0.5;
          final barW = (constraints.maxWidth / weights.length) - 2;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: barW.clamp(2, 12),
                    height: (pct * constraints.maxHeight * 0.85).clamp(4, constraints.maxHeight),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      );
    });
  }

  Widget _buildDietCard() {
    return _chartCard(
      title: 'Costanza Dieta',
      trailing: Text('$_dietStreak giorni', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF22C55E))),
      height: 200,
      child: _dietData.isNotEmpty ? _buildDietBars() : _emptyChart('Nessun dato dieta'),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Media: $_dietAvg%', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.35))),
          Text('Tracciati: $_dietDays giorni', style: const TextStyle(fontSize: 10, color: Color(0xFFF97316))),
        ],
      ),
    );
  }

  Widget _buildDietBars() {
    return LayoutBuilder(builder: (_, constraints) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_dietData.length, (i) {
          final score = (_dietData[i]['score'] as num?)?.toDouble() ?? 0;
          final pct = score / 100.0;
          final color = score >= 70
              ? const Color(0xFF22C55E)
              : score >= 40
                  ? const Color(0xFFF97316)
                  : const Color(0xFFEF4444);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                height: (pct * constraints.maxHeight * 0.85).clamp(4, constraints.maxHeight),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          );
        }),
      );
    });
  }

  Widget _buildStrengthCard() {
    final exercises = _strengthData['exercises'] as List<dynamic>? ?? [];
    return _chartCard(
      title: 'Progresso Forza',
      trailing: Text('${exercises.length} esercizi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF60A5FA))),
      height: 180,
      child: exercises.isEmpty
          ? _emptyChart('Nessun dato forza')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: exercises.take(8).map<Widget>((ex) {
                  final name = ex['name']?.toString() ?? '';
                  final improvement = (ex['improvement'] as num?)?.toDouble() ?? 0;
                  final isPositive = improvement >= 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${isPositive ? '+' : ''}${improvement.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 28,
                          height: (improvement.abs().clamp(5, 100) * 1.2),
                          decoration: BoxDecoration(
                            color: (isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444)).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 50,
                          child: Text(name, style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.4)),
                              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildDaysGrid() {
    return _chartCard(
      title: 'Ultimi 14 Giorni',
      trailing: Text('$_dayStreak giorni di serie', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFF97316))),
      height: null,
      child: _days.isEmpty
          ? _emptyChart('Nessun dato')
          : Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: _days.map<Widget>((day) {
                final completed = day['completed'] == true;
                final isToday = day['is_today'] == true;
                final total = day['total'] as int? ?? 0;
                final dayName = day['day_name']?.toString() ?? '';

                Color bg;
                Color border;
                Widget icon;

                if (completed) {
                  bg = const Color(0xFFF97316);
                  border = const Color(0xFFFB923C);
                  icon = const Icon(Icons.check, size: 14, color: Colors.white);
                } else if (isToday) {
                  bg = Colors.white.withValues(alpha: 0.1);
                  border = const Color(0xFFF97316);
                  icon = Text(dayName, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFFF97316)));
                } else if (total > 0) {
                  bg = const Color(0xFFEF4444).withValues(alpha: 0.2);
                  border = const Color(0xFFEF4444).withValues(alpha: 0.3);
                  icon = const Text('✕', style: TextStyle(fontSize: 10, color: Color(0xFFEF4444)));
                } else {
                  bg = Colors.white.withValues(alpha: 0.05);
                  border = Colors.white.withValues(alpha: 0.1);
                  icon = Text(dayName, style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.3)));
                }

                return Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: border, width: isToday ? 1.5 : 1),
                  ),
                  alignment: Alignment.center,
                  child: icon,
                );
              }).toList(),
            ),
    );
  }

  Widget _chartCard({
    required String title,
    required Widget trailing,
    required double? height,
    required Widget child,
    Widget? footer,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              trailing,
            ],
          ),
          const SizedBox(height: 8),
          if (height != null) SizedBox(height: height - 60, child: child) else child,
          if (footer != null) ...[const SizedBox(height: 6), footer],
        ],
      ),
    );
  }

  Widget _emptyChart(String msg) {
    return Center(
      child: Text(msg, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.25), fontStyle: FontStyle.italic)),
    );
  }
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType keyboardType;

  const _EditField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _VideoUploadButton extends ConsumerStatefulWidget {
  final String exerciseId;
  final ValueChanged<Map<String, dynamic>> onUploaded;

  const _VideoUploadButton({required this.exerciseId, required this.onUploaded});

  @override
  ConsumerState<_VideoUploadButton> createState() => _VideoUploadButtonState();
}

class _VideoUploadButtonState extends ConsumerState<_VideoUploadButton> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    String? filePath;
    String? fileName;

    // Use file_picker on desktop, image_picker on mobile/web
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    if (isDesktop) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'avi', 'webm', 'mkv'],
      );
      if (result == null || result.files.isEmpty) return;
      filePath = result.files.single.path;
      fileName = result.files.single.name;
    } else {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;
      filePath = video.path;
      fileName = video.name;
    }

    if (filePath == null) return;

    setState(() => _uploading = true);
    try {
      final service = ref.read(trainerServiceProvider);
      final result = await service.uploadExerciseVideo(widget.exerciseId, filePath, fileName);
      ref.invalidate(trainerExercisesProvider);
      widget.onUploaded(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video caricato'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore upload: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _uploading ? null : _pickAndUpload,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: _uploading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              )
            : const Icon(Icons.video_library_rounded, size: 22, color: AppColors.primary),
      ),
    );
  }
}
