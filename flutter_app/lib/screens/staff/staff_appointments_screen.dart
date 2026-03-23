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

  void _showAppointmentsDetail(AsyncValue<List<Map<String, dynamic>>> appointments) {
    final data = appointments.valueOrNull;
    if (data == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Appuntamenti di Oggi (${data.length})',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (data.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Nessun appuntamento oggi',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                ),
              )
            else
            ...data.map((appt) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.event_rounded,
                          size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appt['client_name']?.toString() ?? 'Cliente',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'con ${appt['trainer_name']?.toString() ?? 'Trainer'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${appt['time']?.toString() ?? ''} · ${appt['duration'] ?? 60} min',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusBadge(appt['status']?.toString() ?? 'scheduled'),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showCheckinsList(AsyncValue<Map<String, dynamic>> checkins) {
    final data = checkins.valueOrNull;
    if (data == null) return;

    final recent = (data['recent'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final count = data['count'] ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Check-in di Oggi ($count)',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (recent.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Nessun check-in oggi',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                ),
              )
            else
              ...recent.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.success.withValues(alpha: 0.15),
                        child: Text(
                          (c['member_name']?.toString() ?? '?').substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c['member_name']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              c['time']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 20),
                    ],
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  void _showTrainersList(AsyncValue<List<Map<String, dynamic>>> trainers) {
    final data = trainers.valueOrNull;
    if (data == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Trainer (${data.length})',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (data.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Nessun trainer registrato',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                ),
              )
            else
              ...data.map((t) {
                final name = t['name']?.toString() ?? t['username']?.toString() ?? '?';
                final specialties = t['specialties'] as List? ?? [];
                final isOnline = t['is_online'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showTrainerSchedule(
                        t['id']?.toString() ?? '',
                        name,
                      );
                    },
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (specialties.isNotEmpty)
                                Text(
                                  specialties.join(', '),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isOnline ? AppColors.success : AppColors.textTertiary)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: isOnline ? AppColors.success : AppColors.textTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isOnline ? 'In palestra' : 'Assente',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isOnline ? AppColors.success : AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textTertiary, size: 20),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _showTrainerSchedule(String trainerId, String trainerName) async {
    try {
      final service = ref.read(staffServiceProvider);
      final data = await service.getTrainerSchedule(trainerId);
      if (!mounted) return;

      final availability = data['availability'] as List? ?? [];
      final weekAppts = data['week_appointments'] as List? ?? [];
      final dayNames = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

      // Group week appointments by day
      final Map<int, List<dynamic>> apptsByDay = {};
      for (final appt in weekAppts) {
        final dateStr = appt['date']?.toString() ?? '';
        if (dateStr.isNotEmpty) {
          try {
            final d = DateTime.parse(dateStr);
            final dow = d.weekday - 1; // 0=Mon
            apptsByDay.putIfAbsent(dow, () => []).add(appt);
          } catch (_) {}
        }
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.7,
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

              // Weekly view: availability + bookings per day
              ...List.generate(7, (dayIndex) {
                final daySlots = availability
                    .where((s) => (s['day_of_week'] as int?) == dayIndex)
                    .toList();
                final dayAppts = apptsByDay[dayIndex] ?? [];
                final isToday = dayIndex == DateTime.now().weekday - 1;

                if (daySlots.isEmpty && dayAppts.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : AppColors.borderLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                dayNames[dayIndex],
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: isToday
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 6),
                              const Text('Oggi',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                            ],
                            const Spacer(),
                            if (daySlots.isNotEmpty)
                              Text(
                                '${daySlots.first['start_time']} - ${daySlots.first['end_time']}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                          ],
                        ),
                        if (dayAppts.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(
                              color: AppColors.borderLight, height: 1),
                          const SizedBox(height: 8),
                          ...dayAppts.map((appt) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: _statusColor(
                                            appt['status']?.toString() ??
                                                'scheduled'),
                                        borderRadius:
                                            BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            appt['client_name']?.toString() ??
                                                '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            '${appt['time'] ?? ''} - ${appt['end_time'] ?? ''} · ${appt['session_type'] ?? ''}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _statusBadge(
                                        appt['status']?.toString() ??
                                            'scheduled'),
                                  ],
                                ),
                              )),
                        ] else if (daySlots.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Nessuna prenotazione',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                                fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
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

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.success;
      case 'completed':
        return Colors.blueAccent;
      case 'canceled':
        return AppColors.danger;
      case 'pending_trainer':
        return Colors.orange;
      default:
        return AppColors.warning;
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
      case 'pending_trainer':
        color = Colors.orange;
        label = 'In Attesa';
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
                            onTap: () => _showCheckinsList(checkins),
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
                            onTap: () => _showAppointmentsDetail(appointments),
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
                            onTap: () => _showTrainersList(trainers),
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
