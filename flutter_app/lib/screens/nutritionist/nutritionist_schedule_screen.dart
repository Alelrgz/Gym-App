import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/nutritionist_provider.dart';
import '../../services/nutritionist_service.dart';
import '../../widgets/glass_card.dart';

const Color _kCyan = Color(0xFF06B6D4);

class NutritionistScheduleScreen extends ConsumerStatefulWidget {
  const NutritionistScheduleScreen({super.key});

  @override
  ConsumerState<NutritionistScheduleScreen> createState() =>
      _NutritionistScheduleScreenState();
}

class _NutritionistScheduleScreenState
    extends ConsumerState<NutritionistScheduleScreen> {
  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  // Availability state: day -> {enabled, start, end}
  final Map<int, _DaySlot> _days = {};
  double? _sessionRate;
  bool _saving = false;

  NutritionistService get _service =>
      ref.read(nutritionistServiceProvider);

  @override
  void initState() {
    super.initState();
    // Initialize all days as disabled with defaults
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: _kCyan,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.invalidate(nutritionistAppointmentsProvider);
          await _loadData();
        },
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              title: Text(
                'Schedule & Availability',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // ── Weekly Availability ──────────────────
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: _kCyan.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.schedule_rounded,
                                    size: 16, color: _kCyan),
                              ),
                              const SizedBox(width: 8),
                              const Text('Weekly Availability',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _kCyan,
                                      letterSpacing: 0.5)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                              "Set the hours you're available for client consultations",
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                          const SizedBox(height: 12),
                          ...List.generate(7, (i) => _buildDayRow(i)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Session Rate ─────────────────────────
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.success
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                    Icons.attach_money_rounded,
                                    size: 16,
                                    color: AppColors.success),
                              ),
                              const SizedBox(width: 8),
                              const Text('Consultation Rate',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                      letterSpacing: 0.5)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                              'Clients will see this price when booking. Leave empty for free sessions.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              SizedBox(
                                width: 160,
                                child: TextField(
                                  controller: rateCtrl,
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) =>
                                      _sessionRate = double.tryParse(v),
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 40.00',
                                    hintStyle: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 14),
                                    filled: true,
                                    fillColor:
                                        Colors.white.withValues(alpha: 0.04),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: Colors.white
                                              .withValues(alpha: 0.08)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                          color: Colors.white
                                              .withValues(alpha: 0.08)),
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('€ / hour',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500])),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Upcoming Appointments ────────────────
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                    Icons.event_available_rounded,
                                    size: 16,
                                    color: AppColors.primary),
                              ),
                              const SizedBox(width: 8),
                              const Text('Upcoming Appointments',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                      letterSpacing: 0.5)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          appointmentsAsync.when(
                            loading: () => const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      color: _kCyan, strokeWidth: 2)),
                            ),
                            error: (_, __) => Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Could not load appointments',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600])),
                            ),
                            data: (appointments) {
                              final upcoming = appointments
                                  .where(
                                      (a) => a['status'] == 'scheduled')
                                  .take(10)
                                  .toList();
                              if (upcoming.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: Text(
                                        'No upcoming appointments',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600])),
                                  ),
                                );
                              }
                              return Column(
                                children: upcoming
                                    .map((a) =>
                                        _buildAppointmentTile(a))
                                    .toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Save Button ──────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kCyan,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Save Availability & Rate',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayRow(int dayIndex) {
    final slot = _days[dayIndex]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _days[dayIndex] = slot.copyWith(enabled: !slot.enabled);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: slot.enabled,
                  activeColor: _kCyan,
                  onChanged: (v) {
                    setState(() {
                      _days[dayIndex] =
                          slot.copyWith(enabled: v ?? false);
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: Text(_dayNames[dayIndex],
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('to',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600])),
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

  Widget _timeInput(String value, ValueChanged<String> onChanged) {
    final ctrl = TextEditingController(text: value);
    return SizedBox(
      width: 80,
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 12, color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildAppointmentTile(Map<String, dynamic> appt) {
    final statusColor = appt['status'] == 'completed'
        ? AppColors.success
        : appt['status'] == 'canceled'
            ? AppColors.danger
            : _kCyan;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.person, size: 20, color: _kCyan),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appt['client_name'] ?? 'Consultation',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis),
                  Text(
                      '${appt['date']} at ${appt['start_time']}${appt['duration'] != null ? ' (${appt['duration']} min)' : ''}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            Text((appt['status'] as String? ?? '').toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor)),
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
