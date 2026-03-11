import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/trainer_profile.dart';
import '../../providers/trainer_provider.dart';
import '../../widgets/glass_card.dart';

const double _kDesktopBreakpoint = 1024;

class TrainerScheduleScreen extends ConsumerStatefulWidget {
  const TrainerScheduleScreen({super.key});

  @override
  ConsumerState<TrainerScheduleScreen> createState() => _TrainerScheduleScreenState();
}

class _TrainerScheduleScreenState extends ConsumerState<TrainerScheduleScreen> {
  int _selectedDay = 0;
  late DateTime _weekStart;

  // Commission state
  bool _commissionsLoading = true;
  bool _commissionsLoadStarted = false;
  String _commissionPeriod = 'month';
  Map<String, dynamic>? _commissionData;

  // Notes state
  final _notesCtrl = TextEditingController();
  bool _notesLoading = true;
  bool _notesSaving = false;
  bool _notesLoadStarted = false;
  List<Map<String, dynamic>> _savedNotes = [];
  String? _editingNoteId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _selectedDay = now.weekday - 1;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _ensureCommissionsLoaded() {
    if (_commissionsLoadStarted) return;
    _commissionsLoadStarted = true;
    _loadCommissions();
  }

  Future<void> _loadCommissions() async {
    try {
      final data = await ref.read(trainerServiceProvider).getMyCommissions(period: _commissionPeriod);
      if (mounted) setState(() { _commissionData = data; _commissionsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _commissionsLoading = false);
    }
  }

  void _ensureNotesLoaded() {
    if (_notesLoadStarted) return;
    _notesLoadStarted = true;
    _loadPersonalNotes();
  }

  Future<void> _loadPersonalNotes() async {
    try {
      final notes = await ref.read(trainerServiceProvider).getPersonalNotes();
      if (mounted) {
        _savedNotes = notes.map((n) => Map<String, dynamic>.from(n as Map)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _notesLoading = false);
  }

  Future<void> _savePersonalNotes() async {
    final text = _notesCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _notesSaving = true);
    try {
      final service = ref.read(trainerServiceProvider);
      if (_editingNoteId != null) {
        await service.updatePersonalNote(_editingNoteId!, title: 'Nota', content: text);
        _editingNoteId = null;
      } else {
        await service.savePersonalNote(title: 'Nota', content: text);
      }
      _notesCtrl.clear();
      await _loadPersonalNotes();
    } catch (_) {}
    if (mounted) setState(() => _notesSaving = false);
  }

  Future<void> _deleteNote(String noteId) async {
    try {
      await ref.read(trainerServiceProvider).deletePersonalNote(noteId);
      await _loadPersonalNotes();
    } catch (_) {}
  }

  Future<void> _assignWorkoutToSelf(TrainerProfile trainer, Map<String, dynamic> workout) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    try {
      await ref.read(trainerServiceProvider).createEvent({
        'date': dateStr,
        'time': '08:00',
        'title': workout['title'] ?? 'Workout',
        'subtitle': 'Personal Workout',
        'type': 'workout',
        'duration': workout['duration'] ?? 60,
        'workout_id': workout['id'],
      });
      ref.invalidate(trainerDataProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${workout['title']} assegnato per oggi!'), backgroundColor: const Color(0xFF22C55E)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nell\'assegnazione'), backgroundColor: Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _assignSplitToSelf(TrainerProfile trainer, Map<String, dynamic> split) async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dateStr = '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    try {
      await ref.read(trainerServiceProvider).assignSplit({
        'client_id': trainer.id,
        'split_id': split['id'],
        'start_date': dateStr,
      });
      ref.invalidate(trainerDataProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${split['name']} assegnato per questa settimana!'), backgroundColor: const Color(0xFF22C55E)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nell\'assegnazione'), backgroundColor: Color(0xFFEF4444)),
        );
      }
    }
  }

  void _changeWeek(int offset) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * offset));
    });
  }

  // ── Reschedule ──────────────────────────────────────────────
  Future<void> _showRescheduleSheet(TrainerEvent event) async {
    // Parse current date/time
    DateTime currentDate;
    try {
      currentDate = DateTime.parse(event.date);
    } catch (_) {
      currentDate = DateTime.now();
    }
    TimeOfDay currentTime;
    try {
      final parts = event.time.split(':');
      currentTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      currentTime = TimeOfDay.now();
    }

    DateTime? newDate = currentDate;
    TimeOfDay? newTime = currentTime;

    // Result: 'single' = move this event only, 'series' = move all future, null = cancelled
    final isCourseEvent = event.courseId != null;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final dateLabel = '${newDate!.day.toString().padLeft(2, '0')}/${newDate!.month.toString().padLeft(2, '0')}/${newDate!.year}';
          final timeLabel = '${newTime!.hour.toString().padLeft(2, '0')}:${newTime!.minute.toString().padLeft(2, '0')}';

          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Sposta Evento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(Icons.close_rounded, color: Colors.grey[500], size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(event.title, style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                if (event.involvesOthers) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_rounded, size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 6),
                        Text(
                          event.courseId != null ? 'Evento con partecipanti' : 'Evento con cliente',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFF59E0B)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Date picker
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: newDate!,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: Color(0xFF1E1E1E)),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setSheetState(() => newDate = picked);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Data', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            Text(dateLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          ],
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded, color: Colors.grey[600]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Time picker
                GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: newTime!,
                      builder: (context, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: Color(0xFF1E1E1E)),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setSheetState(() => newTime = picked);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ora', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            Text(timeLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          ],
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right_rounded, color: Colors.grey[600]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Action buttons
                if (isCourseEvent) ...[
                  // Two buttons for course events: single vs series
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, 'single'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: const Text('Solo questo',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, 'series'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text('Tutta la serie',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Single confirm button for non-course events
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, 'single'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Conferma Spostamento',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          );
        });
      },
    );

    if (result == null || newDate == null || newTime == null) return;

    final newDateStr = '${newDate!.year}-${newDate!.month.toString().padLeft(2, '0')}-${newDate!.day.toString().padLeft(2, '0')}';
    final newTimeStr = '${newTime!.hour.toString().padLeft(2, '0')}:${newTime!.minute.toString().padLeft(2, '0')}';

    // Check if anything actually changed
    if (newDateStr == event.date && newTimeStr == event.time) return;

    final moveSeries = result == 'series';

    // If event involves others, do a dry run first to show confirmation
    if (event.involvesOthers) {
      final proceed = await _showAffectedPeopleConfirmation(event, newDateStr, newTimeStr, series: moveSeries);
      if (proceed != true) return;
    }

    // Perform the actual reschedule
    if (moveSeries) {
      await _performSeriesReschedule(event, newDateStr, newTimeStr);
    } else {
      await _performReschedule(event, newDateStr, newTimeStr);
    }
  }

  Future<bool?> _showAffectedPeopleConfirmation(TrainerEvent event, String newDate, String newTime, {bool series = false}) async {
    // Dry-run to get affected people
    Map<String, dynamic> dryRunResult;
    final service = ref.read(trainerServiceProvider);
    final payload = {'date': newDate, 'time': newTime, 'dry_run': true};
    try {
      dryRunResult = series
          ? await service.rescheduleEventSeries(event.id, payload)
          : await service.updateEvent(event.id, payload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
      return false;
    }

    final affectedPeople = (dryRunResult['affected_people'] as List?)
        ?.map((p) => Map<String, dynamic>.from(p as Map))
        .toList() ?? [];
    final affectedCount = affectedPeople.length;
    final eventsCount = dryRunResult['events_count'] as int?;

    if (!mounted) return false;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text(
              series ? 'Sposta Tutta la Serie' : 'Conferma Spostamento',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            )),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (series && eventsCount != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '$eventsCount lezioni future verranno spostate.',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
            Text(
              affectedCount > 0
                  ? 'Questo coinvolge $affectedCount ${affectedCount == 1 ? 'persona' : 'persone'}. Verranno notificati del cambio di orario.'
                  : 'Nessun partecipante coinvolto.',
              style: TextStyle(fontSize: 14, color: Colors.grey[300], height: 1.4),
            ),
            if (affectedPeople.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...affectedPeople.take(5).map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        (p['name']?.toString() ?? '?')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(p['name']?.toString() ?? 'Utente', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                  ],
                ),
              )),
              if (affectedPeople.length > 5)
                Text('...e altri ${affectedPeople.length - 5}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annulla', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              series ? 'Sposta Serie e Notifica' : 'Sposta e Notifica',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performReschedule(TrainerEvent event, String newDate, String newTime) async {
    try {
      await ref.read(trainerServiceProvider).updateEvent(event.id, {
        'date': newDate,
        'time': newTime,
      });
      ref.invalidate(trainerDataProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${event.title} spostato a $newDate alle $newTime'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _performSeriesReschedule(TrainerEvent event, String newDate, String newTime) async {
    try {
      final result = await ref.read(trainerServiceProvider).rescheduleEventSeries(event.id, {
        'date': newDate,
        'time': newTime,
      });
      ref.invalidate(trainerDataProvider);
      final movedCount = result['moved_count'] ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$movedCount lezioni di "${event.title}" spostate'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainerAsync = ref.watch(trainerDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: trainerAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Text('Errore: $e', style: const TextStyle(color: AppColors.textSecondary))),
          data: (trainer) => _buildContent(trainer),
        ),
      ),
    );
  }

  Widget _buildContent(TrainerProfile trainer) {
    _ensureNotesLoaded();
    _ensureCommissionsLoaded();
    final isDesktop = MediaQuery.of(context).size.width > _kDesktopBreakpoint;
    if (isDesktop) return _buildDesktop(trainer);
    return _buildMobile(trainer);
  }

  // ═══════════════════════════════════════════════════════════
  //  DESKTOP: 2-column layout
  // ═══════════════════════════════════════════════════════════
  Widget _buildDesktop(TrainerProfile trainer) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Il Mio Profilo',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          Text(trainer.name, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT: Training + At-Risk + Assign + Notes
                Expanded(
                  flex: 14,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ZoneHeader(icon: Icons.local_fire_department_rounded, title: 'Allenamento',
                            subtitle: 'Streak, piani e allenamenti', color: const Color(0xFF22C55E)),
                        const SizedBox(height: 12),
                        _buildTrainingZone(trainer),
                        const SizedBox(height: 24),

                        // Commissions
                        _ZoneHeader(icon: Icons.euro_rounded, title: 'Guadagni',
                            subtitle: 'Commissioni e ricavi', color: const Color(0xFFF59E0B)),
                        const SizedBox(height: 12),
                        _buildCommissionsZone(),
                        const SizedBox(height: 24),

                        // At-risk clients
                        if (_atRiskClients(trainer).isNotEmpty) ...[
                          _ZoneHeader(icon: Icons.warning_amber_rounded, title: 'Clienti Inattivi',
                              subtitle: '${_atRiskClients(trainer).length} clienti a rischio', color: const Color(0xFFF87171)),
                          const SizedBox(height: 12),
                          _buildAtRiskClientsZone(trainer),
                          const SizedBox(height: 24),
                        ],

                        // Assign workout/split
                        if (trainer.workouts.isNotEmpty || trainer.splits.isNotEmpty) ...[
                          _ZoneHeader(icon: Icons.assignment_rounded, title: 'Assegna a Me',
                              subtitle: 'Schede e split personali', color: const Color(0xFF8B5CF6)),
                          const SizedBox(height: 12),
                          _buildAssignZone(trainer),
                          const SizedBox(height: 24),
                        ],

                        _ZoneHeader(icon: Icons.description_rounded, title: 'Note Personali',
                            subtitle: 'Diario e appunti di allenamento', color: Colors.grey),
                        const SizedBox(height: 12),
                        _buildNotesZone(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // RIGHT: Schedule
                Expanded(
                  flex: 10,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ZoneHeader(icon: Icons.calendar_today_rounded, title: 'Agenda',
                            subtitle: 'Calendario e appuntamenti', color: const Color(0xFF3B82F6)),
                        const SizedBox(height: 12),
                        _buildCalendar(trainer.schedule),
                      ],
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
  //  MOBILE: single column scroll
  // ═══════════════════════════════════════════════════════════
  Widget _buildMobile(TrainerProfile trainer) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Il Mio Profilo',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          Text(trainer.name, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 20),

          _ZoneHeader(icon: Icons.local_fire_department_rounded, title: 'Allenamento',
              subtitle: 'Streak, piani e allenamenti', color: const Color(0xFF22C55E)),
          const SizedBox(height: 12),
          _buildTrainingZone(trainer),
          const SizedBox(height: 24),

          // Commissions
          _ZoneHeader(icon: Icons.euro_rounded, title: 'Guadagni',
              subtitle: 'Commissioni e ricavi', color: const Color(0xFFF59E0B)),
          const SizedBox(height: 12),
          _buildCommissionsZone(),
          const SizedBox(height: 24),

          // At-risk clients
          if (_atRiskClients(trainer).isNotEmpty) ...[
            _ZoneHeader(icon: Icons.warning_amber_rounded, title: 'Clienti Inattivi',
                subtitle: '${_atRiskClients(trainer).length} clienti a rischio', color: const Color(0xFFF87171)),
            const SizedBox(height: 12),
            _buildAtRiskClientsZone(trainer),
            const SizedBox(height: 24),
          ],

          // Assign workout/split
          if (trainer.workouts.isNotEmpty || trainer.splits.isNotEmpty) ...[
            _ZoneHeader(icon: Icons.assignment_rounded, title: 'Assegna a Me',
                subtitle: 'Schede e split personali', color: const Color(0xFF8B5CF6)),
            const SizedBox(height: 12),
            _buildAssignZone(trainer),
            const SizedBox(height: 24),
          ],

          _ZoneHeader(icon: Icons.calendar_today_rounded, title: 'Agenda',
              subtitle: 'Calendario e appuntamenti', color: const Color(0xFF3B82F6)),
          const SizedBox(height: 12),
          _buildCalendar(trainer.schedule),
          const SizedBox(height: 24),

          _ZoneHeader(icon: Icons.description_rounded, title: 'Note Personali',
              subtitle: 'Diario e appunti di allenamento', color: Colors.grey),
          const SizedBox(height: 12),
          _buildNotesZone(),
        ],
      ),
    );
  }

  // ── Helper ──
  List<TrainerClient> _atRiskClients(TrainerProfile trainer) {
    return trainer.clients.where((c) => c.status == 'At Risk').toList();
  }

  // ── Training Zone ──────────────────────────────────────────
  Widget _buildTrainingZone(TrainerProfile trainer) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Text('${trainer.streak}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF22C55E))),
                  const Text('Streak', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Text('${trainer.clients.length}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  const Text('Clienti', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Today's workout — full orange gradient card like client dashboard
        _buildTodaysPlanCard(trainer),
      ],
    );
  }

  Widget _buildTodaysPlanCard(TrainerProfile trainer) {
    final workout = trainer.todaysWorkout;
    final hasWorkout = workout != null;
    final isCompleted = hasWorkout && workout['completed'] == true;
    final title = hasWorkout ? (workout['title'] ?? 'Workout') : 'Nessun allenamento';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8461E), Color(0xFFF15A24), Color(0xFFF97316)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ALLENAMENTO DI OGGI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 1.2,
                ),
              ),
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Completato', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            title.toString().toUpperCase(),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),

          // Duration & difficulty / exercises
          Text(
            hasWorkout
                ? '${workout['duration'] != null ? '${workout['duration']} min' : ''}${workout['exercises'] != null ? ' • ${(workout['exercises'] as List).length} esercizi' : ''}${workout['difficulty'] != null ? ' • ${workout['difficulty']}' : ''}'
                : 'Assegnati un allenamento dalla sezione qui sotto.',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 24),

          // Divider + Button
          if (hasWorkout && !isCompleted) ...[
            Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => context.go('/trainer/active-workout', extra: workout),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'AVVIA ALLENAMENTO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Commissions Zone ─────────────────────────────────────
  Widget _buildCommissionsZone() {
    if (_commissionsLoading) {
      return const GlassCard(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: Color(0xFFF59E0B), strokeWidth: 2)),
      );
    }

    final data = _commissionData;
    if (data == null) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Center(child: Text('Nessun dato disponibile', style: TextStyle(fontSize: 13, color: Colors.grey[500]))),
      );
    }

    final rate = (data['commission_rate'] as num?)?.toDouble() ?? 0.0;
    final commissionDue = (data['commission_due'] as num?)?.toDouble() ?? 0.0;
    final totalRevenue = (data['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final apptRevenue = (data['appt_revenue'] as num?)?.toDouble() ?? 0.0;
    final apptCount = (data['appt_count'] as num?)?.toInt() ?? 0;
    final subRevenue = (data['sub_revenue'] as num?)?.toDouble() ?? 0.0;
    final subCount = (data['sub_count'] as num?)?.toInt() ?? 0;

    const periods = [
      ('month', 'Mese'),
      ('last_month', 'Scorso'),
      ('year', 'Anno'),
      ('all', 'Tutto'),
    ];

    return Column(
      children: [
        // Commission total card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('COMMISSIONE DOVUTA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.7), letterSpacing: 1.0)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${rate.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '€${commissionDue.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
              ),
              const SizedBox(height: 4),
              Text(
                'su €${totalRevenue.toStringAsFixed(2)} di ricavi totali',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Period filter pills
        Row(
          children: periods.map((p) {
            final isActive = p.$1 == _commissionPeriod;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() { _commissionPeriod = p.$1; _commissionsLoading = true; });
                  _loadCommissions();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isActive ? const Color(0xFFF59E0B).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Text(p.$2, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: isActive ? const Color(0xFFF59E0B) : Colors.grey[500]),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),

        // Breakdown
        GlassCard(
          child: Column(
            children: [
              _buildCommissionRow(
                icon: Icons.event_available_rounded,
                label: 'Appuntamenti 1-on-1',
                count: apptCount,
                amount: apptRevenue,
                color: const Color(0xFF3B82F6),
              ),
              Divider(color: Colors.white.withValues(alpha: 0.06), height: 16),
              _buildCommissionRow(
                icon: Icons.card_membership_rounded,
                label: 'Abbonamenti clienti',
                count: subCount,
                amount: subRevenue,
                color: const Color(0xFF8B5CF6),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommissionRow({
    required IconData icon,
    required String label,
    required int count,
    required double amount,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text('$count ${count == 1 ? 'transazione' : 'transazioni'}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ),
        Text('€${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }

  // ── At-Risk Clients Zone ──────────────────────────────────
  Widget _buildAtRiskClientsZone(TrainerProfile trainer) {
    final atRisk = _atRiskClients(trainer);
    return GlassCard(
      child: Column(
        children: atRisk.map((client) {
          // Parse days inactive from lastSeen ("X days ago" or "Never")
          String detail;
          if (client.lastSeen == 'Never') {
            detail = 'Mai allenato';
          } else {
            final match = RegExp(r'(\d+)').firstMatch(client.lastSeen);
            detail = match != null ? 'Inattivo da ${match.group(1)}gg' : client.lastSeen;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF87171).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF87171).withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFF87171).withValues(alpha: 0.15),
                    backgroundImage: client.profilePicture != null
                        ? NetworkImage(
                            client.profilePicture!.startsWith('http')
                                ? client.profilePicture!
                                : '${ApiConfig.baseUrl}${client.profilePicture}',
                          )
                        : null,
                    child: client.profilePicture == null
                        ? Text(client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFF87171)))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text(detail, style: const TextStyle(fontSize: 11, color: Color(0xFFF87171))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF87171).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(detail, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFF87171))),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Assign Workout/Split Zone ─────────────────────────────
  Widget _buildAssignZone(TrainerProfile trainer) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Workouts section
          if (trainer.workouts.isNotEmpty) ...[
            Row(children: [
              Icon(Icons.fitness_center_rounded, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text('I Miei Allenamenti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400])),
            ]),
            const SizedBox(height: 8),
            ...trainer.workouts.map((w) => _buildAssignCard(
              title: w['title']?.toString() ?? 'Workout',
              subtitle: '${w['duration'] ?? 60} min',
              icon: Icons.fitness_center_rounded,
              color: AppColors.primary,
              buttonText: 'Assegna a Me (Oggi)',
              onTap: () => _assignWorkoutToSelf(trainer, w),
            )),
          ],

          if (trainer.workouts.isNotEmpty && trainer.splits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Colors.white.withValues(alpha: 0.06)),
            ),

          // Splits section
          if (trainer.splits.isNotEmpty) ...[
            Row(children: [
              Icon(Icons.calendar_view_week_rounded, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text('I Miei Split', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400])),
            ]),
            const SizedBox(height: 8),
            ...trainer.splits.map((s) => _buildAssignCard(
              title: s['name']?.toString() ?? 'Split',
              subtitle: '${s['schedule']?.length ?? 0} giorni',
              icon: Icons.calendar_view_week_rounded,
              color: const Color(0xFF8B5CF6),
              buttonText: 'Assegna a Me (Settimana)',
              onTap: () => _assignSplitToSelf(trainer, s),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Text(buttonText,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Notes Zone ────────────────────────────────────────────
  Widget _buildNotesZone() {
    return Column(
      children: [
        // Input card
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Scrivi una nuova nota...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_editingNoteId != null)
                    GestureDetector(
                      onTap: () => setState(() { _editingNoteId = null; _notesCtrl.clear(); }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Annulla', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[400])),
                      ),
                    ),
                  GestureDetector(
                    onTap: _notesSaving ? null : _savePersonalNotes,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _notesSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                          : Text(_editingNoteId != null ? 'Aggiorna' : 'Salva',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Saved notes list
        if (_notesLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
          )
        else if (_savedNotes.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._savedNotes.map((note) {
            final content = note['content']?.toString() ?? '';
            final createdAt = note['created_at']?.toString() ?? '';
            final noteId = note['id']?.toString() ?? '';
            // Format date
            String dateLabel = '';
            if (createdAt.length >= 10) {
              final parts = createdAt.substring(0, 10).split('-');
              if (parts.length == 3) dateLabel = '${parts[2]}/${parts[1]}/${parts[0]}';
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(content, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (dateLabel.isNotEmpty)
                          Text(dateLabel, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() {
                            _editingNoteId = noteId;
                            _notesCtrl.text = content;
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.edit_rounded, size: 15, color: Colors.grey[500]),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _deleteNote(noteId),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.delete_outline_rounded, size: 15, color: Colors.grey[500]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  // ── Calendar Zone ─────────────────────────────────────────
  Widget _buildCalendar(List<TrainerEvent> allEvents) {
    const days = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
    const months = ['Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
        'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'];
    final selectedDate = _weekStart.add(Duration(days: _selectedDay));
    final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
    final dayEvents = allEvents.where((e) => e.date == dateStr).toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(onTap: () => _changeWeek(-1),
                  child: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary)),
              Expanded(
                child: Center(
                  child: Text('${months[selectedDate.month - 1]} ${selectedDate.year}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ),
              ),
              GestureDetector(onTap: () => _changeWeek(1),
                  child: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(7, (i) {
              final date = _weekStart.add(Duration(days: i));
              final isSelected = i == _selectedDay;
              final isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month && date.day == DateTime.now().day;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isToday && !isSelected ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
                    ),
                    child: Column(children: [
                      Text(days[i], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.primary : Colors.grey[600])),
                      const SizedBox(height: 2),
                      Text('${date.day}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary)),
                    ]),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          if (dayEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('Nessun evento', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
            )
          else
            ...dayEvents.map((event) {
              final typeColor = switch (event.type) {
                'consultation' => const Color(0xFF3B82F6),
                'class' || 'course' => const Color(0xFF8B5CF6),
                'personal' || 'workout' => const Color(0xFF22C55E),
                _ => Colors.grey,
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: event.completed ? null : () => _showRescheduleSheet(event),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: typeColor.withValues(alpha: 0.15)),
                    ),
                    child: Row(children: [
                      Container(width: 4, height: 36,
                          decoration: BoxDecoration(color: typeColor, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            if (event.subtitle.isNotEmpty) Text(event.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      Text(event.time, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400])),
                      if (event.completed) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF22C55E)),
                      ] else ...[
                        const SizedBox(width: 6),
                        Icon(Icons.drag_indicator_rounded, size: 16, color: Colors.grey[600]),
                      ],
                    ]),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ZoneHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _ZoneHeader({required this.icon, required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3))),
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ]),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: Colors.grey[500]),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
    ]);
  }
}
