import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/stat_card.dart';

class StaffAppointmentsScreen extends ConsumerStatefulWidget {
  const StaffAppointmentsScreen({super.key});

  @override
  ConsumerState<StaffAppointmentsScreen> createState() =>
      _StaffAppointmentsScreenState();
}

class _StaffAppointmentsScreenState
    extends ConsumerState<StaffAppointmentsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _quickCheckIn(String memberId, String memberName) async {
    try {
      final service = ref.read(staffServiceProvider);
      await service.checkIn(memberId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$memberName check-in effettuato')),
        );
        ref.invalidate(staffCheckinsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  void _showTrainerSchedule(String trainerId, String trainerName) async {
    try {
      final service = ref.read(staffServiceProvider);
      final data = await service.getTrainerSchedule(trainerId);
      if (!mounted) return;

      final availability = data['availability'] as List? ?? [];
      final todayAppts = data['today_appointments'] as List? ?? [];
      final dayNames = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Orario - $trainerName',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Disponibilità Settimanale',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              if (availability.isEmpty)
                const Text(
                  'Nessuna disponibilità impostata',
                  style: TextStyle(color: AppColors.textTertiary),
                )
              else
                ...availability.map((slot) {
                  final dayIndex = slot['day_of_week'] as int? ?? 0;
                  final day =
                      dayIndex < dayNames.length ? dayNames[dayIndex] : '?';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Text(day,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          const Spacer(),
                          Text(
                            '${slot['start_time']} - ${slot['end_time']}',
                            style: const TextStyle(
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 20),
              const Text(
                'Appuntamenti di Oggi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              if (todayAppts.isEmpty)
                const Text(
                  'Nessun appuntamento oggi',
                  style: TextStyle(color: AppColors.textTertiary),
                )
              else
                ...todayAppts.map((appt) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.person,
                                  size: 18, color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appt['client_name']?.toString() ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary),
                                  ),
                                  Text(
                                    '${appt['time'] ?? ''} · ${appt['duration'] ?? 60} min',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            _statusBadge(
                                appt['status']?.toString() ?? 'scheduled'),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  Widget _statusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'confirmed':
        color = AppColors.success;
        label = 'Confermato';
      case 'completed':
        color = Colors.blueAccent;
        label = 'Completato';
      case 'canceled':
        color = AppColors.danger;
        label = 'Annullato';
      default:
        color = AppColors.warning;
        label = 'Programmato';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkins = ref.watch(staffCheckinsProvider);
    final appointments = ref.watch(staffAppointmentsProvider);
    final trainers = ref.watch(staffTrainersProvider);
    final members = ref.watch(staffMembersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.invalidate(staffCheckinsProvider);
          ref.invalidate(staffAppointmentsProvider);
          ref.invalidate(staffTrainersProvider);
        },
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              title: Text(
                'Prenotazioni',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Stats Row ─────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Check-in oggi',
                            value: checkins.when(
                              data: (d) => '${d['count'] ?? 0}',
                              loading: () => '...',
                              error: (_, __) => '-',
                            ),
                            icon: Icons.login_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatCard(
                            label: 'Appuntamenti',
                            value: appointments.when(
                              data: (d) => '${d.length}',
                              loading: () => '...',
                              error: (_, __) => '-',
                            ),
                            icon: Icons.event_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatCard(
                            label: 'Trainer',
                            value: trainers.when(
                              data: (d) => '${d.length}',
                              loading: () => '...',
                              error: (_, __) => '-',
                            ),
                            icon: Icons.sports_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Quick Check-In ────────────────────
                    const Text(
                      'Check-In Rapido',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Cerca cliente per check-in...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                    ),
                    if (_searchQuery.length >= 2)
                      members.when(
                        data: (list) {
                          final q = _searchQuery.toLowerCase();
                          final filtered = list
                              .where((m) =>
                                  (m['name']?.toString() ?? '')
                                      .toLowerCase()
                                      .contains(q) ||
                                  (m['username']?.toString() ?? '')
                                      .toLowerCase()
                                      .contains(q))
                              .take(8)
                              .toList();
                          if (filtered.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('Nessun risultato',
                                  style: TextStyle(
                                      color: AppColors.textTertiary)),
                            );
                          }
                          return Container(
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Column(
                              children: filtered
                                  .map((m) => ListTile(
                                        dense: true,
                                        leading: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: AppColors.primary
                                              .withValues(alpha: 0.15),
                                          child: Text(
                                            (m['name']?.toString() ?? '?')
                                                .substring(0, 1)
                                                .toUpperCase(),
                                            style: const TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12),
                                          ),
                                        ),
                                        title: Text(
                                            m['name']?.toString() ?? '',
                                            style: const TextStyle(
                                                color:
                                                    AppColors.textPrimary)),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.login_rounded,
                                              color: AppColors.success,
                                              size: 20),
                                          onPressed: () => _quickCheckIn(
                                            m['id']?.toString() ?? '',
                                            m['name']?.toString() ?? '',
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(
                              color: AppColors.primary),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    const SizedBox(height: 24),

                    // ── Appointments & Check-ins Grid ─────
                    LayoutBuilder(builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 600;
                      final apptWidget = _buildAppointmentsList(appointments);
                      final checkinWidget = _buildRecentCheckins(checkins);

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: apptWidget),
                            const SizedBox(width: 16),
                            Expanded(child: checkinWidget),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          apptWidget,
                          const SizedBox(height: 16),
                          checkinWidget,
                        ],
                      );
                    }),
                    const SizedBox(height: 24),

                    // ── Trainers Section ──────────────────
                    const Text(
                      'Trainer della Palestra',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    trainers.when(
                      data: (list) {
                        if (list.isEmpty) {
                          return const GlassCard(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Nessun trainer registrato',
                                    style: TextStyle(
                                        color: AppColors.textTertiary)),
                              ),
                            ),
                          );
                        }
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: list
                              .map((t) => _buildTrainerCard(t))
                              .toList(),
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                      error: (e, _) => Text('Errore: $e',
                          style:
                              const TextStyle(color: AppColors.danger)),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsList(
      AsyncValue<List<Map<String, dynamic>>> appointments) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_rounded,
                  size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Appuntamenti di Oggi',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          appointments.when(
            data: (list) {
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('Nessun appuntamento oggi',
                        style: TextStyle(color: AppColors.textTertiary)),
                  ),
                );
              }
              return Column(
                children: list
                    .map((appt) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      appt['client_name']?.toString() ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary),
                                    ),
                                    Text(
                                      'con ${appt['trainer_name'] ?? ''} · ${appt['time'] ?? ''}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              _statusBadge(
                                  appt['status']?.toString() ?? 'scheduled'),
                            ],
                          ),
                        ))
                    .toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child:
                    CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (e, _) =>
                Text('Errore: $e', style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCheckins(AsyncValue<Map<String, dynamic>> checkins) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.login_rounded,
                  size: 18, color: AppColors.success),
              SizedBox(width: 8),
              Text(
                'Check-in Recenti',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          checkins.when(
            data: (data) {
              final recent = (data['recent'] as List?) ?? [];
              if (recent.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('Nessun check-in oggi',
                        style: TextStyle(color: AppColors.textTertiary)),
                  ),
                );
              }
              return Column(
                children: recent
                    .take(10)
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  c['member_name']?.toString() ?? '',
                                  style: const TextStyle(
                                      color: AppColors.textPrimary),
                                ),
                              ),
                              Text(
                                c['time']?.toString() ?? '',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child:
                    CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (e, _) =>
                Text('Errore: $e', style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerCard(Map<String, dynamic> trainer) {
    final name = trainer['name']?.toString() ??
        trainer['username']?.toString() ??
        '?';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final subRole = trainer['sub_role']?.toString() ?? 'trainer';

    return GlassCard(
      onTap: () => _showTrainerSchedule(
        trainer['id']?.toString() ?? '',
        name,
      ),
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 220,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  Text(
                    subRole == 'both'
                        ? 'Trainer / Nutrizionista'
                        : subRole == 'nutritionist'
                            ? 'Nutrizionista'
                            : 'Trainer',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
