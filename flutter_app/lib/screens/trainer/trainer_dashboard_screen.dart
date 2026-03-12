import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/trainer_profile.dart';
import '../../providers/trainer_provider.dart';
import '../../services/trainer_service.dart';
import '../../widgets/glass_card.dart';

const double _kDesktopBreakpoint = 1024;

class TrainerDashboardScreen extends ConsumerStatefulWidget {
  const TrainerDashboardScreen({super.key});

  @override
  ConsumerState<TrainerDashboardScreen> createState() => _TrainerDashboardScreenState();
}

class _TrainerDashboardScreenState extends ConsumerState<TrainerDashboardScreen> {
  String _searchQuery = '';
  String _filter = 'all'; // all, with_plan, without_plan
  int _selectedDay = 0; // 0-6 for week days
  late DateTime _weekStart;
  TrainerClient? _selectedClient;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _selectedDay = now.weekday - 1;
  }

  void _changeWeek(int offset) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * offset));
    });
  }

  @override
  Widget build(BuildContext context) {
    final trainerAsync = ref.watch(trainerDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: trainerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Errore: $e', style: const TextStyle(color: AppColors.textSecondary))),
        data: (trainer) => _buildContent(trainer),
      ),
    );
  }

  Widget _buildContent(TrainerProfile trainer) {
    final isDesktop = MediaQuery.of(context).size.width > _kDesktopBreakpoint;

    if (isDesktop) {
      return _buildDesktop(trainer);
    }
    return _buildMobile(trainer);
  }

  // ═══════════════════════════════════════════════════════════
  //  DESKTOP: 2-column grid (1.4fr clients | 1fr schedule)
  // ═══════════════════════════════════════════════════════════
  Widget _buildDesktop(TrainerProfile trainer) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row with stats ──────────────────
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Utenti',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gestisci i tuoi clienti e i loro dati',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const Spacer(),
                _StatChip(value: '${trainer.clients.length}', label: 'clienti'),
                const SizedBox(width: 8),
                _StatChip(value: '${trainer.activeClients}', label: 'attivi'),
                const SizedBox(width: 8),
                _StatChip(value: '${trainer.atRiskClients}', label: 'inattivi'),
              ],
            ),
            const SizedBox(height: 20),

            // ── 2-column layout ────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT: Clients (~58%)
                  Expanded(
                    flex: 14,
                    child: _buildDesktopClientPanel(trainer.clients),
                  ),
                  const SizedBox(width: 20),
                  // RIGHT: Client Workout Log (~42%)
                  Expanded(
                    flex: 10,
                    child: _selectedClient != null
                        ? _ClientWorkoutLogPanel(
                            client: _selectedClient!,
                            service: ref.read(trainerServiceProvider),
                            onClose: () => setState(() => _selectedClient = null),
                          )
                        : _buildScheduleSection(trainer.schedule),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopClientPanel(List<TrainerClient> clients) {
    final filtered = _filterClients(clients);

    return Column(
      children: [
        // Search + filters
        Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Cerca clienti...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.grey[600]),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildFilterIcon(),
          ],
        ),
        const SizedBox(height: 12),

        // Client list (scrollable)
        Expanded(
          child: filtered.isEmpty
              ? GlassCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _searchQuery.isEmpty ? 'Nessun cliente' : 'Nessun risultato',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final c = filtered[index];
                    final isSelected = _selectedClient?.id == c.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedClient = c),
                        child: _ClientCard(client: c, isSelected: isSelected),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  MOBILE: single column scroll
  // ═══════════════════════════════════════════════════════════
  Widget _buildMobile(TrainerProfile trainer) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // ── Header ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Utenti',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestisci i tuoi clienti e i loro dati',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),

          // ── Stats Bar ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  _StatChip(value: '${trainer.clients.length}', label: 'clienti'),
                  const SizedBox(width: 8),
                  _StatChip(value: '${trainer.activeClients}', label: 'attivi'),
                  const SizedBox(width: 8),
                  _StatChip(value: '${trainer.atRiskClients}', label: 'inattivi'),
                ],
              ),
            ),
          ),

          // ── Client Search + Filter ─────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Cerca clienti...',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.grey[600]),
                          filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterIcon(),
                ],
              ),
            ),
          ),

          // ── Client List ────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: _buildMobileClientList(trainer.clients),
          ),

          // ── Schedule Section ──────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _buildScheduleSection(trainer.schedule),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────

  Widget _buildFilterIcon() {
    final isFiltered = _filter != 'all';
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filtra clienti', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Tutti'),
                  leading: Icon(Icons.people_rounded, color: _filter == 'all' ? AppColors.primary : Colors.grey[600]),
                  selected: _filter == 'all',
                  selectedColor: AppColors.primary,
                  onTap: () { setState(() => _filter = 'all'); Navigator.pop(ctx); },
                ),
                ListTile(
                  title: const Text('Con scheda'),
                  leading: Icon(Icons.assignment_rounded, color: _filter == 'with_plan' ? AppColors.primary : Colors.grey[600]),
                  selected: _filter == 'with_plan',
                  selectedColor: AppColors.primary,
                  onTap: () { setState(() => _filter = 'with_plan'); Navigator.pop(ctx); },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: isFiltered ? AppColors.primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isFiltered ? AppColors.primary.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(Icons.tune_rounded, size: 20, color: isFiltered ? AppColors.primary : Colors.grey[500]),
      ),
    );
  }

  List<TrainerClient> _filterClients(List<TrainerClient> clients) {
    return clients.where((c) {
      if (_searchQuery.isNotEmpty && !c.name.toLowerCase().contains(_searchQuery)) return false;
      if (_filter == 'with_plan' && (c.plan.isEmpty || c.plan == 'Nessuna scheda')) return false;
      if (_filter == 'without_plan' && c.plan.isNotEmpty && c.plan != 'Nessuna scheda') return false;
      return true;
    }).toList();
  }

  Widget _buildMobileClientList(List<TrainerClient> clients) {
    final filtered = _filterClients(clients);

    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: GlassCard(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _searchQuery.isEmpty ? 'Nessun cliente' : 'Nessun risultato',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          ),
        ),
      );
    }

    return SliverList.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final client = filtered[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ClientCard(client: client),
        );
      },
    );
  }

  // ── Schedule Section (shared desktop/mobile) ───────────────
  Widget _buildScheduleSection(List<TrainerEvent> allEvents) {
    const days = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
    final selectedDate = _weekStart.add(Duration(days: _selectedDay));
    final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
    final dayEvents = allEvents.where((e) => e.date == dateStr).toList();

    const months = ['Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
        'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Week navigation
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Agenda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: () => _changeWeek(-1),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chevron_left_rounded, size: 20, color: AppColors.textSecondary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  months[selectedDate.month - 1],
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
              GestureDetector(
                onTap: () => _changeWeek(1),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Day tabs
          Row(
            children: List.generate(7, (i) {
              final date = _weekStart.add(Duration(days: i));
              final isSelected = i == _selectedDay;
              final isToday = _isToday(date);
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
                    child: Column(
                      children: [
                        Text(
                          days[i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppColors.primary : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Events for selected day
          if (dayEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Nessun evento', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ),
            )
          else
            ...dayEvents.map((event) => _EventTile(event: event)),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}

// ── Stat Chip ──────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String value;
  final String label;

  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

// ── Client Card ────────────────────────────────────────────
class _ClientCard extends StatelessWidget {
  final TrainerClient client;
  final bool isSelected;

  const _ClientCard({required this.client, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    final hasPlan = client.plan.isNotEmpty && client.plan != 'Nessuna scheda';
    final statusColor = switch (client.status) {
      'active' => const Color(0xFF22C55E),
      'inactive' => AppColors.danger,
      _ => Colors.grey,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.06),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            backgroundImage: client.profilePicture != null
                ? NetworkImage(
                    client.profilePicture!.startsWith('http')
                        ? client.profilePicture!
                        : '${ApiConfig.baseUrl}${client.profilePicture}',
                  )
                : null,
            child: client.profilePicture == null
                ? Text(
                    client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Name + Plan
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        client.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (client.isPremium) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAB308).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('PRO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFEAB308))),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  hasPlan ? client.plan : 'Nessuna scheda',
                  style: TextStyle(fontSize: 12, color: hasPlan ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Status + Expiry
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              if (client.planExpiry != null) ...[
                const SizedBox(height: 4),
                Text(
                  client.planExpiry!,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Event Tile ─────────────────────────────────────────────
class _EventTile extends StatelessWidget {
  final TrainerEvent event;

  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final typeColor = switch (event.type) {
      'consultation' => const Color(0xFF3B82F6),
      'class' || 'course' => const Color(0xFF8B5CF6),
      'personal' => const Color(0xFF22C55E),
      _ => Colors.grey,
    };
    final typeLabel = switch (event.type) {
      'consultation' => 'Consulenza',
      'class' || 'course' => 'Corso',
      'personal' => 'Personale',
      _ => event.type,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: typeColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: typeColor.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  if (event.subtitle.isNotEmpty)
                    Text(event.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(event.time, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400])),
                const SizedBox(height: 2),
                Text(typeLabel, style: TextStyle(fontSize: 10, color: typeColor)),
              ],
            ),
            if (event.completed) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF22C55E)),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  CLIENT WORKOUT LOG PANEL (right side on desktop)
// ═══════════════════════════════════════════════════════════

class _ClientWorkoutLogPanel extends StatefulWidget {
  final TrainerClient client;
  final TrainerService service;
  final VoidCallback onClose;

  const _ClientWorkoutLogPanel({
    required this.client,
    required this.service,
    required this.onClose,
  });

  @override
  State<_ClientWorkoutLogPanel> createState() => _ClientWorkoutLogPanelState();
}

class _ClientWorkoutLogPanelState extends State<_ClientWorkoutLogPanel> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  // Workouts tab
  List<dynamic> _workoutDays = [];
  bool _loadingWorkouts = true;
  // Strength tab
  Map<String, dynamic> _weightData = {};
  Map<String, dynamic> _strengthData = {};
  Map<String, dynamic> _dietData = {};
  Map<String, dynamic> _streakData = {};
  bool _loadingStrength = true;
  // Notes tab
  List<dynamic> _notes = [];
  bool _loadingNotes = true;
  final _noteCtrl = TextEditingController();
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void didUpdateWidget(covariant _ClientWorkoutLogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client.id != widget.client.id) {
      setState(() { _loadingWorkouts = true; _loadingStrength = true; _loadingNotes = true; });
      _loadAll();
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadWorkouts(), _loadStrength(), _loadNotes()]);
  }

  Future<void> _loadWorkouts() async {
    try {
      final data = await widget.service.getClientWorkoutLog(widget.client.id);
      if (mounted) setState(() { _workoutDays = data; _loadingWorkouts = false; });
    } catch (_) { if (mounted) setState(() => _loadingWorkouts = false); }
  }

  Future<void> _loadStrength() async {
    try {
      final results = await Future.wait([
        widget.service.getClientWeightHistory(widget.client.id),
        widget.service.getClientStrengthProgress(widget.client.id),
        widget.service.getClientDietConsistency(widget.client.id),
        widget.service.getClientWeekStreak(widget.client.id),
      ]);
      if (mounted) {
        setState(() {
        _weightData = results[0];
        _strengthData = results[1];
        _dietData = results[2];
        _streakData = results[3];
        _loadingStrength = false;
      });
      }
    } catch (_) { if (mounted) setState(() => _loadingStrength = false); }
  }

  Future<void> _loadNotes() async {
    try {
      final data = await widget.service.getClientNotes(widget.client.id);
      if (mounted) setState(() { _notes = data; _loadingNotes = false; });
    } catch (e) { debugPrint('LOAD NOTES ERROR: $e'); if (mounted) setState(() => _loadingNotes = false); }
  }

  Future<void> _saveNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _savingNote = true);
    try {
      await widget.service.saveClientNote(widget.client.id, title: 'Nota', content: text);
      _noteCtrl.clear();
      await _loadNotes();
    } catch (e) { debugPrint('SAVE NOTE ERROR: $e'); }
    if (mounted) setState(() => _savingNote = false);
  }

  Future<void> _deleteNote(String noteId) async {
    try {
      await widget.service.deleteNote(noteId);
      await _loadNotes();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage: widget.client.profilePicture != null
                    ? NetworkImage(
                        widget.client.profilePicture!.startsWith('http')
                            ? widget.client.profilePicture!
                            : '${ApiConfig.baseUrl}${widget.client.profilePicture}',
                      )
                    : null,
                child: widget.client.profilePicture == null
                    ? Text(widget.client.name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.client.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.close_rounded, size: 18, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tab bar
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey[500],
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Allenamenti'),
                Tab(text: 'Forza'),
                Tab(text: 'Note'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildWorkoutsTab(),
                _buildStrengthTab(),
                _buildNotesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB 1: WORKOUTS ──────────────────────────────────────
  Widget _buildWorkoutsTab() {
    if (_loadingWorkouts) return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2));
    if (_workoutDays.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.fitness_center_rounded, size: 40, color: Colors.grey[700]),
        const SizedBox(height: 12),
        Text('Nessun allenamento completato', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      ]));
    }
    return ListView.builder(
      itemCount: _workoutDays.length,
      itemBuilder: (_, i) => _buildDayCard(_workoutDays[i] as Map<String, dynamic>),
    );
  }

  // ── TAB 2: STRENGTH / METRICS ────────────────────────────
  Widget _buildStrengthTab() {
    if (_loadingStrength) return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2));

    final weightList = _weightData['data'] as List<dynamic>? ?? [];
    final dietList = _dietData['data'] as List<dynamic>? ?? [];
    final categories = _strengthData['categories'] as Map<String, dynamic>? ?? {};
    final days = _streakData['days'] as List<dynamic>? ?? [];
    final streak = _streakData['current_streak'] as int? ?? 0;
    final dietAvg = _dietData['average_score'] ?? 0;

    // Quick stats
    double? currentWeight;
    double? weightChange;
    if (weightList.isNotEmpty) {
      currentWeight = (weightList.last['weight'] as num).toDouble();
      final first = (weightList.first['weight'] as num).toDouble();
      weightChange = currentWeight - first;
    }

    // Strength trend
    double upperPct = 0, lowerPct = 0, cardioPct = 0;
    if (categories.isNotEmpty) {
      upperPct = ((categories['upper_body'] as Map<String, dynamic>?)?['progress'] as num?)?.toDouble() ?? 0;
      lowerPct = ((categories['lower_body'] as Map<String, dynamic>?)?['progress'] as num?)?.toDouble() ?? 0;
      cardioPct = ((categories['cardio'] as Map<String, dynamic>?)?['progress'] as num?)?.toDouble() ?? 0;
    }
    final avgStrength = categories.isNotEmpty ? (upperPct + lowerPct + cardioPct) / 3 : 0.0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick stats row (matches webapp)
          Row(children: [
            _quickStat(currentWeight?.toStringAsFixed(1) ?? '--', 'PESO (KG)', Colors.white),
            const SizedBox(width: 6),
            _quickStat('$streak', 'SERIE GIORNI', const Color(0xFFF97316)),
            const SizedBox(width: 6),
            _quickStat('$dietAvg', 'DIETA %', const Color(0xFF22C55E)),
            const SizedBox(width: 6),
            _quickStat('${avgStrength >= 0 ? '\u2191' : '\u2193'} ${avgStrength.toStringAsFixed(0)}%', 'FORZA', const Color(0xFF60A5FA)),
          ]),
          const SizedBox(height: 12),

          // Charts grid: Weight + Diet side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weight Progress card
              Expanded(child: _buildWeightCard(weightList, currentWeight, weightChange)),
              const SizedBox(width: 8),
              // Diet Consistency card
              Expanded(child: _buildDietCard(dietList)),
            ],
          ),
          const SizedBox(height: 8),

          // Strength Progress card (full width, multi-line chart)
          _buildStrengthCard(categories),
          const SizedBox(height: 8),

          // 14-day grid card
          if (days.isNotEmpty) _buildDaysGridCard(days, streak),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWeightCard(List<dynamic> weightList, double? currentWeight, double? weightChange) {
    final goalWeight = _weightData['goal_weight'];
    return Container(
      height: 200,
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
              const Text('Progresso Peso', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              if (weightChange != null)
                Text('${weightChange >= 0 ? '+' : ''}${weightChange.toStringAsFixed(1)} kg',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: weightChange >= 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444))),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: weightList.isEmpty
                ? Center(child: Text('Nessun dato', style: TextStyle(fontSize: 11, color: Colors.grey[600])))
                : CustomPaint(
                    size: Size.infinite,
                    painter: _WeightLineChartPainter(
                      data: weightList.map((d) => (d['weight'] as num).toDouble()).toList(),
                      labels: weightList.map((d) => (d['date'] as String).substring(5)).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: 'Attuale: ', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                TextSpan(text: '${currentWeight?.toStringAsFixed(1) ?? '--'} kg',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ])),
              Text.rich(TextSpan(children: [
                TextSpan(text: 'Obiettivo: ', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                TextSpan(text: '${goalWeight ?? '--'} kg',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFF97316))),
              ])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDietCard(List<dynamic> dietList) {
    final dietStreak = _dietData['current_streak'] ?? 0;
    final dietAvg = _dietData['average_score'] ?? 0;
    final totalDays = _dietData['total_days'] ?? 0;
    return Container(
      height: 200,
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
              const Text('Costanza Dieta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text('$dietStreak day streak',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF22C55E))),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: dietList.isEmpty
                ? Center(child: Text('No diet data logged', style: TextStyle(fontSize: 11, color: Colors.grey[600])))
                : CustomPaint(
                    size: Size.infinite,
                    painter: _DietBarChartPainter(
                      data: dietList.map((d) => (d['score'] as num?)?.toDouble() ?? 0).toList(),
                      labels: dietList.map((d) => (d['date'] as String).substring(5)).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: 'Media: ', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                TextSpan(text: '$dietAvg%',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ])),
              Text.rich(TextSpan(children: [
                TextSpan(text: 'Tracciati: ', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                TextSpan(text: '$totalDays giorni',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFF97316))),
              ])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthCard(Map<String, dynamic> categories) {
    // Extract category data for multi-line chart
    final upperData = (categories['upper_body'] as Map<String, dynamic>?);
    final lowerData = (categories['lower_body'] as Map<String, dynamic>?);
    final cardioData = (categories['cardio'] as Map<String, dynamic>?);

    final upperProgress = (upperData?['progress'] as num?)?.toDouble() ?? 0;
    final lowerProgress = (lowerData?['progress'] as num?)?.toDouble() ?? 0;
    final cardioProgress = (cardioData?['progress'] as num?)?.toDouble() ?? 0;

    // Build series for the chart
    final List<_ChartSeries> series = [];
    final List<String> chartLabels = [];

    for (final entry in [
      ('Upper', const Color(0xFFF97316), upperData),
      ('Lower', const Color(0xFF8B5CF6), lowerData),
      ('Cardio', const Color(0xFF22C55E), cardioData),
    ]) {
      final catData = entry.$3;
      if (catData != null) {
        final dataList = catData['data'] as List<dynamic>? ?? [];
        final values = dataList.map((d) => (d['strength'] as num?)?.toDouble()).toList();
        if (values.any((v) => v != null)) {
          series.add(_ChartSeries(name: entry.$1, color: entry.$2, values: values));
          if (chartLabels.isEmpty) {
            chartLabels.addAll(dataList.map((d) => (d['date'] as String).substring(5)));
          }
        }
      }
    }

    // Goal labels
    final goals = _strengthData['goals'] as Map<String, dynamic>? ?? {};

    return Container(
      height: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Progresso Forza', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          // Legend
          if (series.isNotEmpty)
            Row(
              children: series.map((s) => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(children: [
                  Container(width: 16, height: 3, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Text(s.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[400])),
                ]),
              )).toList(),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: series.isEmpty
                ? Center(child: Text('Nessun dato', style: TextStyle(fontSize: 11, color: Colors.grey[600])))
                : Row(
                    children: [
                      Expanded(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _StrengthLineChartPainter(
                            series: series,
                            labels: chartLabels,
                          ),
                        ),
                      ),
                      // Goal percentage labels on the right
                      if (goals.isNotEmpty || upperProgress != 0 || lowerProgress != 0 || cardioProgress != 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (upperProgress != 0 || goals['upper'] != null)
                                _goalBadge('${upperProgress.toStringAsFixed(0)}%', const Color(0xFFF97316)),
                              if (lowerProgress != 0 || goals['lower'] != null) ...[
                                const SizedBox(height: 6),
                                _goalBadge('${lowerProgress.toStringAsFixed(0)}%', const Color(0xFF8B5CF6)),
                              ],
                              if (cardioProgress != 0 || goals['cardio'] != null) ...[
                                const SizedBox(height: 6),
                                _goalBadge('${cardioProgress.toStringAsFixed(0)}%', const Color(0xFF22C55E)),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _goalBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _buildDaysGridCard(List<dynamic> days, int streak) {
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
              const Text('Ultimi 14 Giorni', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text('$streak day${streak != 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFF97316))),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
            children: days.map<Widget>((day) {
              final completed = day['completed'] == true;
              final isToday = day['is_today'] == true;
              final total = day['total'] as int? ?? 0;
              final dayName = day['day_name']?.toString() ?? '';

              Color bg; Color border; Widget icon;
              if (completed) {
                bg = const Color(0xFFF97316); border = const Color(0xFFFB923C);
                icon = const Icon(Icons.check, size: 14, color: Colors.white);
              } else if (isToday) {
                bg = Colors.white.withValues(alpha: 0.1); border = const Color(0xFFF97316);
                icon = Text(dayName, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFFF97316)));
              } else if (total > 0) {
                bg = const Color(0xFFEF4444).withValues(alpha: 0.2); border = const Color(0xFFEF4444).withValues(alpha: 0.3);
                icon = const Text('✕', style: TextStyle(fontSize: 10, color: Color(0xFFEF4444)));
              } else {
                bg = Colors.white.withValues(alpha: 0.05); border = Colors.white.withValues(alpha: 0.1);
                icon = Text(dayName, style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.3)));
              }
              return Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: border, width: isToday ? 1.5 : 1)),
                alignment: Alignment.center, child: icon,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── TAB 3: NOTES ─────────────────────────────────────────
  Widget _buildNotesTab() {
    return Column(
      children: [
        // Add note input
        Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: TextField(
                  controller: _noteCtrl,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Scrivi una nota...',
                    hintStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => _saveNote(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _savingNote ? null : _saveNote,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: _savingNote
                    ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.send_rounded, size: 18, color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Notes list
        Expanded(
          child: _loadingNotes
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
              : _notes.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.note_alt_outlined, size: 40, color: Colors.grey[700]),
                      const SizedBox(height: 12),
                      Text('Nessuna nota per questo cliente', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ]))
                  : ListView.builder(
                      itemCount: _notes.length,
                      itemBuilder: (_, i) {
                        final note = _notes[i] as Map<String, dynamic>;
                        final content = note['content']?.toString() ?? '';
                        final updatedAt = note['updated_at']?.toString() ?? '';
                        String timeLabel = '';
                        try {
                          final dt = DateTime.parse(updatedAt);
                          final diff = DateTime.now().difference(dt);
                          if (diff.inMinutes < 60) {
                            timeLabel = '${diff.inMinutes}m fa';
                          } else if (diff.inHours < 24) {
                            timeLabel = '${diff.inHours}h fa';
                          } else {
                            timeLabel = '${diff.inDays}g fa';
                          }
                        } catch (_) {}

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(content, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                                      const SizedBox(height: 4),
                                      Text(timeLabel, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _deleteNote(note['id']?.toString() ?? ''),
                                  child: Icon(Icons.close_rounded, size: 16, color: Colors.grey[600]),
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

  // ── SHARED HELPERS ───────────────────────────────────────

  Widget _quickStat(String value, String label, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: valueColor)),
          const SizedBox(height: 1),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.35)),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day) {
    final date = day['date']?.toString() ?? '';
    final exercises = day['exercises'] as List<dynamic>? ?? [];

    String displayDate = date;
    try {
      final dt = DateTime.parse(date);
      final now = DateTime.now();
      final diff = DateTime(now.year, now.month, now.day).difference(DateTime(dt.year, dt.month, dt.day)).inDays;
      if (diff == 0) { displayDate = 'Oggi'; }
      else if (diff == 1) { displayDate = 'Ieri'; }
      else {
        const dn = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
        const mn = ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];
        displayDate = '${dn[dt.weekday - 1]} ${dt.day} ${mn[dt.month - 1]}';
      }
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Text(displayDate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const Spacer(),
                Text('${exercises.length} eserciz${exercises.length == 1 ? 'io' : 'i'}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
            ),
            ...exercises.map<Widget>((ex) => _buildExerciseTile(ex as Map<String, dynamic>)),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseTile(Map<String, dynamic> ex) {
    final name = ex['exercise_name']?.toString() ?? 'Sconosciuto';
    final metricType = ex['metric_type']?.toString() ?? 'weight_reps';
    final sets = ex['sets'] as List<dynamic>? ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            Text('${sets.length} set', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[500])),
          ]),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(children: [
                  SizedBox(width: 32, child: Text('Set', style: _headerStyle)),
                  if (metricType == 'weight_reps' || metricType == 'weight') ...[
                    Expanded(child: Text('Peso', style: _headerStyle)),
                    Expanded(child: Text('Reps', style: _headerStyle)),
                  ],
                  if (metricType == 'duration' || metricType == 'duration_distance')
                    Expanded(child: Text('Durata', style: _headerStyle)),
                  if (metricType == 'distance' || metricType == 'duration_distance')
                    Expanded(child: Text('Distanza', style: _headerStyle)),
                ]),
              ),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.04)),
              ...sets.map<Widget>((s) {
                final set = s as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(children: [
                    SizedBox(width: 32, child: Container(
                      width: 20, height: 20, alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
                      child: Text('${set['set_number'] ?? ''}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    )),
                    if (metricType == 'weight_reps' || metricType == 'weight') ...[
                      Expanded(child: Text(
                        set['weight'] != null ? '${(set['weight'] as num).toStringAsFixed(set['weight'] == (set['weight'] as num).toInt() ? 0 : 1)} kg' : '--',
                        style: _valueStyle)),
                      Expanded(child: Text(set['reps'] != null ? '${set['reps']}' : '--', style: _valueStyle)),
                    ],
                    if (metricType == 'duration' || metricType == 'duration_distance')
                      Expanded(child: Text(set['duration'] != null ? '${(set['duration'] as num).toStringAsFixed(0)} min' : '--', style: _valueStyle)),
                    if (metricType == 'distance' || metricType == 'duration_distance')
                      Expanded(child: Text(set['distance'] != null ? '${(set['distance'] as num).toStringAsFixed(1)} km' : '--', style: _valueStyle)),
                  ]),
                );
              }),
            ]),
          ),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 0.3);
  TextStyle get _valueStyle => const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary);
}

// ── Chart Data Models ─────────────────────────────────────

class _ChartSeries {
  final String name;
  final Color color;
  final List<double?> values;
  const _ChartSeries({required this.name, required this.color, required this.values});
}

// ── Weight Line Chart (matches webapp Chart.js line chart) ──

class _WeightLineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;

  _WeightLineChartPainter({required this.data, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double leftPad = 30;
    const double bottomPad = 16;
    const double topPad = 4;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad - topPad;

    final minVal = data.reduce((a, b) => a < b ? a : b) - 0.5;
    final maxVal = data.reduce((a, b) => a > b ? a : b) + 0.5;
    final range = maxVal - minVal;

    // Grid lines
    final gridPaint = Paint()..color = const Color(0x0DFFFFFF)..strokeWidth = 1;
    final textStyle = const TextStyle(fontSize: 9, color: Color(0xFF666666));
    for (int i = 0; i <= 4; i++) {
      final y = topPad + chartH - (chartH * i / 4);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final val = minVal + range * i / 4;
      final tp = TextPainter(text: TextSpan(text: val.toStringAsFixed(1), style: textStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    // X-axis labels (show a few)
    final step = (labels.length / 5).ceil().clamp(1, labels.length);
    for (int i = 0; i < labels.length; i += step) {
      final x = leftPad + (chartW * i / (data.length - 1).clamp(1, data.length));
      final tp = TextPainter(text: TextSpan(text: labels[i], style: textStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - bottomPad + 2));
    }

    // Line + fill
    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < data.length; i++) {
      final x = leftPad + (chartW * i / (data.length - 1).clamp(1, data.length));
      final y = topPad + chartH - (chartH * (data[i] - minVal) / range);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, topPad + chartH);
        fillPath.lineTo(x, y);
      } else {
        // Smooth curve
        final prevX = leftPad + (chartW * (i - 1) / (data.length - 1).clamp(1, data.length));
        final prevY = topPad + chartH - (chartH * (data[i - 1] - minVal) / range);
        final cpx = (prevX + x) / 2;
        path.cubicTo(cpx, prevY, cpx, y, x, y);
        fillPath.cubicTo(cpx, prevY, cpx, y, x, y);
      }
    }
    // Close fill
    final lastX = leftPad + chartW;
    fillPath.lineTo(lastX, topPad + chartH);
    fillPath.close();

    canvas.drawPath(fillPath, Paint()..color = const Color(0x1AF97316));
    canvas.drawPath(path, Paint()..color = const Color(0xFFF97316)..strokeWidth = 2..style = PaintingStyle.stroke);

    // Points
    final pointPaint = Paint()..color = const Color(0xFFF97316);
    for (int i = 0; i < data.length; i++) {
      final x = leftPad + (chartW * i / (data.length - 1).clamp(1, data.length));
      final y = topPad + chartH - (chartH * (data[i] - minVal) / range);
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightLineChartPainter old) => old.data != data;
}

// ── Diet Bar Chart (matches webapp Chart.js bar chart) ──────

class _DietBarChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;

  _DietBarChartPainter({required this.data, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double leftPad = 24;
    const double bottomPad = 16;
    const double topPad = 4;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad - topPad;

    // Grid lines (0, 25, 50, 75, 100)
    final gridPaint = Paint()..color = const Color(0x0DFFFFFF)..strokeWidth = 1;
    final textStyle = const TextStyle(fontSize: 9, color: Color(0xFF666666));
    for (int i = 0; i <= 4; i++) {
      final y = topPad + chartH - (chartH * i / 4);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final val = (25 * i).toString();
      final tp = TextPainter(text: TextSpan(text: val, style: textStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    // Bars
    final barWidth = (chartW / data.length) * 0.7;
    final gap = (chartW / data.length) * 0.3;
    for (int i = 0; i < data.length; i++) {
      final score = data[i];
      final barH = (score / 100) * chartH;
      final x = leftPad + (chartW * i / data.length) + gap / 2;
      final y = topPad + chartH - barH;

      Color barColor;
      if (score >= 80) {
        barColor = const Color(0xB322C55E); // green 70%
      } else if (score >= 60) {
        barColor = const Color(0xB3EAB308); // yellow 70%
      } else {
        barColor = const Color(0xB3EF4444); // red 70%
      }

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barH),
        const Radius.circular(4),
      );
      canvas.drawRRect(rrect, Paint()..color = barColor);
    }

    // X-axis labels (show a few)
    final step = (labels.length / 5).ceil().clamp(1, labels.length);
    for (int i = 0; i < labels.length; i += step) {
      final x = leftPad + (chartW * i / data.length) + (chartW / data.length) / 2;
      final tp = TextPainter(text: TextSpan(text: labels[i], style: const TextStyle(fontSize: 8, color: Color(0xFF666666))), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - bottomPad + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _DietBarChartPainter old) => old.data != data;
}

// ── Strength Multi-Line Chart (matches webapp Chart.js multi-dataset line) ──

class _StrengthLineChartPainter extends CustomPainter {
  final List<_ChartSeries> series;
  final List<String> labels;

  _StrengthLineChartPainter({required this.series, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty || labels.isEmpty) return;

    const double leftPad = 30;
    const double bottomPad = 18;
    const double topPad = 4;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad - topPad;

    // Find global min/max across all series
    double globalMin = double.infinity;
    double globalMax = double.negativeInfinity;
    for (final s in series) {
      for (final v in s.values) {
        if (v != null) {
          if (v < globalMin) globalMin = v;
          if (v > globalMax) globalMax = v;
        }
      }
    }
    if (globalMin == double.infinity) return;
    final padding = (globalMax - globalMin) * 0.1 + 1;
    globalMin -= padding;
    globalMax += padding;
    final range = globalMax - globalMin;

    // Grid lines
    final gridPaint = Paint()..color = const Color(0x0DFFFFFF)..strokeWidth = 1;
    final textStyle = const TextStyle(fontSize: 9, color: Color(0xFF888888));
    for (int i = 0; i <= 4; i++) {
      final y = topPad + chartH - (chartH * i / 4);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final val = globalMin + range * i / 4;
      final tp = TextPainter(
        text: TextSpan(text: '${val.toStringAsFixed(0)}%', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    // X-axis labels
    final maxLabels = labels.length;
    final step = (maxLabels / 6).ceil().clamp(1, maxLabels);
    for (int i = 0; i < maxLabels; i += step) {
      final x = leftPad + (chartW * i / (maxLabels - 1).clamp(1, maxLabels));
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: const TextStyle(fontSize: 9, color: Color(0xFF888888))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - bottomPad + 3));
    }

    // Draw each series
    for (final s in series) {
      final linePath = Path();
      final fillPath = Path();
      final pointPaint = Paint()..color = s.color;
      final bgPaint = Paint()..color = const Color(0xFF1A1A1A);
      bool started = false;
      for (int i = 0; i < s.values.length; i++) {
        final v = s.values[i];
        if (v == null) continue;
        final x = leftPad + (chartW * i / (maxLabels - 1).clamp(1, maxLabels));
        final y = topPad + chartH - (chartH * (v - globalMin) / range);

        if (!started) {
          linePath.moveTo(x, y);
          fillPath.moveTo(x, topPad + chartH);
          fillPath.lineTo(x, y);
          started = true;
        } else {
          linePath.lineTo(x, y);
          fillPath.lineTo(x, y);
        }
      }

      if (!started) continue;

      // Close fill path
      final lastIdx = s.values.lastIndexWhere((v) => v != null);
      if (lastIdx >= 0) {
        final lastX = leftPad + (chartW * lastIdx / (maxLabels - 1).clamp(1, maxLabels));
        fillPath.lineTo(lastX, topPad + chartH);
        fillPath.close();
      }

      canvas.drawPath(fillPath, Paint()..color = s.color.withValues(alpha: 0.08));
      canvas.drawPath(linePath, Paint()..color = s.color..strokeWidth = 3..style = PaintingStyle.stroke);

      // Points with border
      for (int i = 0; i < s.values.length; i++) {
        final v = s.values[i];
        if (v == null) continue;
        final x = leftPad + (chartW * i / (maxLabels - 1).clamp(1, maxLabels));
        final y = topPad + chartH - (chartH * (v - globalMin) / range);
        canvas.drawCircle(Offset(x, y), 5, bgPaint);
        canvas.drawCircle(Offset(x, y), 4, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StrengthLineChartPainter old) => true;
}
