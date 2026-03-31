import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/nutritionist_provider.dart';
import '../../services/nutritionist_service.dart';

class NutritionistScheduleScreen extends ConsumerStatefulWidget {
  const NutritionistScheduleScreen({super.key});

  @override
  ConsumerState<NutritionistScheduleScreen> createState() =>
      _NutritionistScheduleScreenState();
}

class _NutritionistScheduleScreenState
    extends ConsumerState<NutritionistScheduleScreen> {
  static const _dayNames = [
    'Lunedì',
    'Martedì',
    'Mercoledì',
    'Giovedì',
    'Venerdì',
    'Sabato',
    'Domenica',
  ];

  final Map<int, _DaySlot> _days = {};
  double? _sessionRate;
  bool _saving = false;

  NutritionistService get _service =>
      ref.read(nutritionistServiceProvider);

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 7; i++) {
      _days[i] = _DaySlot(
        enabled: false,
        start: i >= 5 ? '10:00' : '09:00',
        end: i >= 5 ? '14:00' : '17:00',
      );
    }
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final slots = await _service.getAvailability();
      for (final slot in slots) {
        final day = slot['day_of_week'] as int;
        _days[day] = _DaySlot(
          enabled: true,
          start: slot['start_time'] as String? ?? '09:00',
          end: slot['end_time'] as String? ?? '17:00',
        );
      }
      final rateData = await _service.getSessionRate();
      _sessionRate = rateData['session_rate'] != null
          ? (rateData['session_rate'] as num).toDouble()
          : null;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final availability = <Map<String, dynamic>>[];
      for (final entry in _days.entries) {
        if (entry.value.enabled) {
          availability.add({
            'day_of_week': entry.key,
            'start_time': entry.value.start,
            'end_time': entry.value.end,
          });
        }
      }
      await _service.setAvailability(availability);
      await _service.setSessionRate(_sessionRate);
      ref.invalidate(nutritionistAvailabilityProvider);
      _toast('Disponibilità e tariffa salvate!');
    } catch (e) {
      _toast('Errore: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(nutritionistAppointmentsProvider);
    final rateCtrl = TextEditingController(
        text: _sessionRate?.toStringAsFixed(2) ?? '');
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.invalidate(nutritionistAppointmentsProvider);
          await _loadData();
        },
        child: CustomScrollView(
          slivers: [
            // Header with save button
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              title: const Text(
                'Disponibilità',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: _saving ? null : _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: _saving
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Salva',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Availability + Rate: side-by-side on wide, stacked on narrow
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  flex: 3,
                                  child: _buildAvailabilitySection()),
                              const SizedBox(width: 16),
                              Expanded(
                                  flex: 1,
                                  child: _buildRateSection(rateCtrl)),
                            ],
                          )
                        else ...[
                          _buildAvailabilitySection(),
                          const SizedBox(height: 16),
                          _buildRateSection(rateCtrl),
                        ],

                        const SizedBox(height: 16),

                        // Appointments
                        _buildAppointmentsSection(appointmentsAsync),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Weekly Availability ──────────────────────────────────
  Widget _buildAvailabilitySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Orari settimanali',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400])),
          const SizedBox(height: 4),
          Text('Imposta le ore disponibili per le consulenze',
              style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          const SizedBox(height: 16),
          ...List.generate(7, (i) => _buildDayRow(i)),
        ],
      ),
    );
  }

  // ── Session Rate ─────────────────────────────────────────
  Widget _buildRateSection(TextEditingController rateCtrl) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tariffa',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400])),
          const SizedBox(height: 4),
          Text('Prezzo visibile ai clienti',
              style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          const SizedBox(height: 16),
          TextField(
            controller: rateCtrl,
            keyboardType: TextInputType.number,
            onChanged: (v) => _sessionRate = double.tryParse(v),
            style: const TextStyle(fontSize: 15, color: Colors.white),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(color: Colors.grey[700], fontSize: 15),
              suffixText: '€/ora',
              suffixStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  // ── Upcoming Appointments ────────────────────────────────
  Widget _buildAppointmentsSection(AsyncValue<List<Map<String, dynamic>>> appointmentsAsync) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Prossimi appuntamenti',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400])),
          const SizedBox(height: 12),
          appointmentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Errore nel caricamento',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
            data: (appointments) {
              final upcoming = appointments
                  .where((a) => a['status'] == 'scheduled')
                  .take(10)
                  .toList();
              if (upcoming.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.event_outlined,
                            size: 28, color: Colors.grey[800]),
                        const SizedBox(height: 8),
                        Text('Nessun appuntamento',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[700])),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children:
                    upcoming.map((a) => _buildAppointmentTile(a)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Day Row ──────────────────────────────────────────────
  Widget _buildDayRow(int dayIndex) {
    final slot = _days[dayIndex]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AnimatedOpacity(
        duration: AppAnim.fast,
        opacity: slot.enabled ? 1.0 : 0.45,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: slot.enabled
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // iOS-style toggle
              GestureDetector(
                onTap: () {
                  setState(() {
                    _days[dayIndex] =
                        slot.copyWith(enabled: !slot.enabled);
                  });
                },
                child: AnimatedContainer(
                  duration: AppAnim.fast,
                  width: 44,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: slot.enabled
                        ? AppColors.success
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                  child: AnimatedAlign(
                    duration: AppAnim.fast,
                    alignment: slot.enabled
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 90,
                child: Text(_dayNames[dayIndex],
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white)),
              ),
              if (slot.enabled) ...[
                const Spacer(),
                _timeInput(slot.start, (v) {
                  setState(() {
                    _days[dayIndex] = slot.copyWith(start: v);
                  });
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('–',
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey[600])),
                ),
                _timeInput(slot.end, (v) {
                  setState(() {
                    _days[dayIndex] = slot.copyWith(end: v);
                  });
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Time Input ───────────────────────────────────────────
  Widget _timeInput(String value, ValueChanged<String> onChanged) {
    final ctrl = TextEditingController(text: value);
    return SizedBox(
      width: 72,
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }

  // ── Appointment Tile ─────────────────────────────────────
  Widget _buildAppointmentTile(Map<String, dynamic> appt) {
    final status = appt['status'] as String? ?? '';
    final statusColor = status == 'completed'
        ? AppColors.success
        : status == 'canceled'
            ? AppColors.danger
            : AppColors.primary;
    final statusLabel = status == 'completed'
        ? 'Completato'
        : status == 'canceled'
            ? 'Annullato'
            : 'Prenotato';
    final clientName = appt['client_name'] as String? ?? 'Consulenza';
    final initial =
        clientName.isNotEmpty ? clientName[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Initial avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(initial,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(clientName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                      '${appt['date']} alle ${appt['start_time']}${appt['duration'] != null ? ' (${appt['duration']} min)' : ''}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }
}

class _DaySlot {
  final bool enabled;
  final String start;
  final String end;

  const _DaySlot({
    required this.enabled,
    required this.start,
    required this.end,
  });

  _DaySlot copyWith({bool? enabled, String? start, String? end}) {
    return _DaySlot(
      enabled: enabled ?? this.enabled,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}
