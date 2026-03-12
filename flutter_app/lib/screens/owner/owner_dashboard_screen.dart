import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/gym_provider.dart';
import '../../providers/owner_provider.dart';
import '../../widgets/dashboard_sheets.dart';
import '../../widgets/glass_card.dart';
import 'owner_automation_builder_screen.dart';

const double _kDesktopBreakpoint = 1024;

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  String _gymName = 'La Mia Palestra';
  double _monthlyRevenue = 0;
  double _subscriptionRevenue = 0;
  double _appointmentRevenue = 0;
  double _nutritionAppointmentRevenue = 0;
  int _appointmentCount = 0;
  int _nutritionAppointmentCount = 0;
  int _activeSubscriptions = 0;
  int _activeMembers = 0;
  int _staffActive = 0;
  List<Map<String, dynamic>> _revenueByPlan = [];

  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _messageLog = [];
  List<Map<String, dynamic>> _trainers = [];
  List<Map<String, dynamic>> _pendingTrainers = [];
  List<Map<String, dynamic>> _activityFeed = [];

  bool _loading = true;

  // Activity carousel
  int _activityPage = 0;

  // Commission modal state
  String _commissionPeriod = 'month';
  List<Map<String, dynamic>> _commissions = [];
  bool _commissionsLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _syncGymContext();
      _loadAll();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _syncGymContext() {
    var gymId = ref.read(activeGymIdProvider);
    if (gymId == null) {
      gymId = ref.read(defaultGymIdProvider);
      if (gymId != null) {
        ref.read(activeGymIdProvider.notifier).state = gymId;
      }
    }
    ref.read(apiClientProvider).activeGymId = gymId;
  }

  void _switchGym(String gymId) {
    ref.read(activeGymIdProvider.notifier).state = gymId;
    ref.read(apiClientProvider).activeGymId = gymId;
    _loadAll();
  }

  Widget _buildGymSwitcher() {
    final gyms = ref.watch(ownerGymsProvider);
    final activeId = ref.watch(activeGymIdProvider);

    // Single gym — just show the name with gradient
    if (gyms.length <= 1) {
      return ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [AppColors.primary, Color(0xFFFB923C)],
        ).createShader(bounds),
        child: Text(
          _gymName,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
        ),
      );
    }

    // Multiple gyms — dropdown switcher
    final activeGym = gyms.firstWhere(
      (g) => g.id == activeId,
      orElse: () => gyms.first,
    );

    return GestureDetector(
      onTap: () => _showGymPicker(gyms, activeGym.id),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.primary, Color(0xFFFB923C)],
            ).createShader(bounds),
            child: Text(
              activeGym.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  void _showGymPicker(List<dynamic> gyms, String activeId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Le Tue Palestre', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ...gyms.map((g) {
              final isActive = g.id == activeId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    if (!isActive) _switchGym(g.id);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive ? AppColors.primary.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.primary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              g.name.isNotEmpty ? g.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800,
                                color: isActive ? AppColors.primary : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            g.name,
                            style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600,
                              color: isActive ? AppColors.primary : Colors.grey[400],
                            ),
                          ),
                        ),
                        if (isActive)
                          const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showCreateGymDialog();
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Aggiungi Palestra'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[500],
                  side: BorderSide(color: Colors.grey[800]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateGymDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nuova Palestra', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nome della palestra',
            hintStyle: TextStyle(color: Colors.grey[700]),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annulla', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final result = await ref.read(ownerServiceProvider).createGym(name);
                // Re-login to refresh gym list, or just add locally
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Palestra "$name" creata!')),
                  );
                  // Switch to new gym
                  _switchGym(result['id'] as String);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Errore: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Crea'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAll() async {
    final svc = ref.read(ownerServiceProvider);
    try {
      final results = await Future.wait([
        svc.getOwnerData().catchError((_) => <String, dynamic>{}),
        svc.getSubscriptionPlans().catchError((_) => <Map<String, dynamic>>[]),
        svc.getOffers().catchError((_) => <Map<String, dynamic>>[]),
        svc.getAutomatedMessages().catchError((_) => <Map<String, dynamic>>[]),
        svc.getAutomatedMessagesLog().catchError((_) => <Map<String, dynamic>>[]),
        svc.getApprovedTrainers().catchError((_) => <Map<String, dynamic>>[]),
        svc.getPendingTrainers().catchError((_) => <Map<String, dynamic>>[]),
        svc.getActivityFeed().catchError((_) => <Map<String, dynamic>>[]),
        svc.getGymSettings().catchError((_) => <String, dynamic>{}),
        svc.getCommissions(period: 'month').catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;

      final data = results[0] as Map<String, dynamic>;
      final settings = results[8] as Map<String, dynamic>;

      setState(() {
        _monthlyRevenue = (data['monthly_revenue'] as num?)?.toDouble() ?? 0;
        _subscriptionRevenue = (data['subscription_revenue'] as num?)?.toDouble() ?? 0;
        _appointmentRevenue = (data['appointment_revenue'] as num?)?.toDouble() ?? 0;
        _nutritionAppointmentRevenue = (data['nutrition_appointment_revenue'] as num?)?.toDouble() ?? 0;
        _appointmentCount = (data['appointment_count'] as num?)?.toInt() ?? 0;
        _nutritionAppointmentCount = (data['nutrition_appointment_count'] as num?)?.toInt() ?? 0;
        _activeSubscriptions = (data['active_subscriptions'] as num?)?.toInt() ?? 0;
        _activeMembers = (data['active_members'] as num?)?.toInt() ?? 0;
        _staffActive = (data['staff_active'] as num?)?.toInt() ?? 0;
        _revenueByPlan = (data['revenue_by_plan'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ?? [];
        _plans = results[1] as List<Map<String, dynamic>>;
        _offers = results[2] as List<Map<String, dynamic>>;
        _templates = results[3] as List<Map<String, dynamic>>;
        _messageLog = results[4] as List<Map<String, dynamic>>;
        _trainers = results[5] as List<Map<String, dynamic>>;
        _pendingTrainers = results[6] as List<Map<String, dynamic>>;
        _activityFeed = results[7] as List<Map<String, dynamic>>;
        _commissions = results[9] as List<Map<String, dynamic>>;
        _gymName = (settings['gym_name'] as String?) ?? 'La Mia Palestra';
        _loading = false;

        // Use subscription counts from plans for accurate per-plan breakdown
        _activeSubscriptions = _plans.fold(0, (sum, p) => sum + ((p['active_subscriptions'] as num?)?.toInt() ?? 0));
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > _kDesktopBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadAll,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isDesktop ? 32 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    if (!isDesktop) ...[
                      Center(
                        child: Column(
                          children: [
                            _buildGymSwitcher(),
                            const SizedBox(height: 2),
                            Text('Dashboard', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dashboard', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                              const SizedBox(height: 4),
                              _buildGymSwitcher(),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Pending staff banner
                    if (_pendingTrainers.isNotEmpty) ...[
                      _buildPendingBanner(),
                      const SizedBox(height: 20),
                    ],

                    // Main grid
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left 2/3
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                _buildOperationsZone(),
                                const SizedBox(height: 24),
                                _buildProductsZone(),
                                const SizedBox(height: 24),
                                _buildAutomationZone(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Right 1/3
                          Expanded(
                            flex: 1,
                            child: Column(
                              children: [
                                _buildTeamZone(),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildOperationsZone(),
                          const SizedBox(height: 24),
                          _buildProductsZone(),
                          const SizedBox(height: 24),
                          _buildTeamZone(),
                          const SizedBox(height: 24),
                          _buildAutomationZone(),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PENDING STAFF BANNER
  // ═══════════════════════════════════════════════════════════
  Widget _buildPendingBanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFFACC15).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_rounded, size: 16, color: Color(0xFFFACC15)),
            ),
            const SizedBox(width: 8),
            const Text('Approvazioni Staff in Attesa',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFACC15), letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 12),
        ..._pendingTrainers.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            padding: const EdgeInsets.all(12),
            borderRadius: 16,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: Text(
                    (t['username'] as String? ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['username'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      if (t['email'] != null)
                        Text(t['email'] as String, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                _buildRoleBadge(t['sub_role'] as String? ?? t['role'] as String? ?? 'trainer'),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80), size: 28),
                  onPressed: () => _approveTrainer(t['id'] as String),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.cancel_rounded, color: Color(0xFFF87171), size: 28),
                  onPressed: () => _rejectTrainer(t['id'] as String, t['username'] as String? ?? ''),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildRoleBadge(String role) {
    final color = role.contains('nutri') ? const Color(0xFF4ADE80) : AppColors.primary;
    final label = role.contains('nutri') ? 'Nutrizionista' : (role.contains('both') ? 'Trainer+Nutri' : 'Trainer');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Future<void> _approveTrainer(String id) async {
    try {
      await ref.read(ownerServiceProvider).approveTrainer(id);
      _loadAll();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _rejectTrainer(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rifiuta Trainer'),
        content: Text('Sei sicuro di voler rifiutare $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Rifiuta', style: TextStyle(color: Color(0xFFF87171)))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(ownerServiceProvider).rejectTrainer(id);
        _loadAll();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  OPERATIONS ZONE (Green)
  // ═══════════════════════════════════════════════════════════
  Widget _buildOperationsZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildZoneHeader(
          icon: Icons.attach_money_rounded,
          title: 'Operazioni',
          subtitle: 'Ricavi e metriche aziendali',
          color: const Color(0xFF4ADE80),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _showRevenueDetailSheet,
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [const Color(0xFF4ADE80).withValues(alpha: 0.1), Colors.transparent],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Ricavi Mensili', style: TextStyle(fontSize: 11, color: Colors.grey[500], letterSpacing: 0.5)),
                        const Spacer(),
                        Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey[600]),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '€${_monthlyRevenue.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF4ADE80)),
                    ),
                    const SizedBox(height: 16),
                    _buildMetricRow('Abbonamenti Attivi', '$_activeSubscriptions'),
                    const SizedBox(height: 8),
                    _buildMetricRow('Clienti Attivi', '$_activeMembers'),
                    const SizedBox(height: 8),
                    _buildMetricRow('Staff', '$_staffActive'),
                  ],
                ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ─── Revenue Detail Sheet ───
  void _showRevenueDetailSheet() {
    const green = Color(0xFF4ADE80);
    final totalCommissionDue = _commissions.fold<double>(
      0, (sum, c) => sum + ((c['commission_due'] as num?)?.toDouble() ?? 0),
    );
    final netRevenue = _monthlyRevenue - totalCommissionDue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (ctx, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: green.withValues(alpha: 0.3))),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // Header
              Text('Dettaglio Ricavi Mensili', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Panoramica delle entrate del mese corrente', style: TextStyle(fontSize: 12, color: Colors.grey[500])),

              const SizedBox(height: 20),

              // Total prominently
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [green.withValues(alpha: 0.15), green.withValues(alpha: 0.05)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: green.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, color: green, size: 28),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ricavi Totali', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                        Text('€${_monthlyRevenue.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: green)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Revenue sources
              Text('Fonti di Ricavo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[400])),
              const SizedBox(height: 10),

              // Subscriptions
              _revenueSourceTile(
                icon: Icons.card_membership_rounded,
                color: const Color(0xFF42A5F5),
                label: 'Abbonamenti',
                sublabel: '$_activeSubscriptions attivi',
                amount: _subscriptionRevenue,
                percentage: _monthlyRevenue > 0 ? (_subscriptionRevenue / _monthlyRevenue * 100) : 0,
              ),
              const SizedBox(height: 8),

              // Trainer appointments
              _revenueSourceTile(
                icon: Icons.fitness_center_rounded,
                color: AppColors.primary,
                label: 'Appuntamenti Trainer',
                sublabel: '$_appointmentCount questo mese',
                amount: _appointmentRevenue,
                percentage: _monthlyRevenue > 0 ? (_appointmentRevenue / _monthlyRevenue * 100) : 0,
              ),
              const SizedBox(height: 8),

              // Nutritionist appointments
              _revenueSourceTile(
                icon: Icons.restaurant_rounded,
                color: const Color(0xFF66BB6A),
                label: 'Consulenze Nutrizionista',
                sublabel: '$_nutritionAppointmentCount questo mese',
                amount: _nutritionAppointmentRevenue,
                percentage: _monthlyRevenue > 0 ? (_nutritionAppointmentRevenue / _monthlyRevenue * 100) : 0,
              ),

              const SizedBox(height: 20),

              // Per-plan breakdown
              if (_revenueByPlan.isNotEmpty) ...[
                Text('Ricavi per Piano', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[400])),
                const SizedBox(height: 10),
                ..._revenueByPlan.map((p) {
                  final planName = p['name'] as String? ?? '';
                  final planRevenue = (p['revenue'] as num?)?.toDouble() ?? 0;
                  final planCount = (p['count'] as num?)?.toInt() ?? 0;
                  final pct = _subscriptionRevenue > 0 ? (planRevenue / _subscriptionRevenue * 100) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(planName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                Text('$planCount abbonati', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('€${planRevenue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 14),
              ],

              // Net revenue after commissions
              Divider(color: Colors.grey[800]),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Commissioni Totali', style: TextStyle(fontSize: 13)),
                  Text('- €${totalCommissionDue.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEF5350))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ricavo Netto', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('€${netRevenue.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: green)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _revenueSourceTile({
    required IconData icon,
    required Color color,
    required String label,
    required String sublabel,
    required double amount,
    required double percentage,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(sublabel, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('€${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
              Text('${percentage.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PRODUCTS ZONE (Purple)
  // ═══════════════════════════════════════════════════════════
  Widget _buildProductsZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildZoneHeader(
          icon: Icons.inventory_2_rounded,
          title: 'Prodotti',
          subtitle: 'Piani e offerte promozionali',
          color: const Color(0xFFA78BFA),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildPlansCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildOffersCard()),
                ],
              );
            }
            return Column(
              children: [
                _buildPlansCard(),
                const SizedBox(height: 16),
                _buildOffersCard(),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlansCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Piani', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              _buildActionChip('+ Nuovo', const Color(0xFFA78BFA), onTap: () => _showPlanModal()),
            ],
          ),
          const SizedBox(height: 12),
          if (_plans.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Center(child: Text('Nessun piano', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _plans.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _buildPlanItem(_plans[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanItem(Map<String, dynamic> plan) {
    final isActive = plan['is_active'] == true;
    final billingType = plan['billing_type'] as String? ?? 'monthly';
    final price = (plan['price'] as num?)?.toDouble() ?? 0;
    final annualPrice = (plan['annual_price'] as num?)?.toDouble() ?? price;
    final installments = (plan['installment_count'] as num?)?.toInt() ?? 1;
    final activeSubs = (plan['active_subscriptions'] as num?)?.toInt() ?? 0;

    String priceLabel;
    if (billingType == 'monthly') {
      priceLabel = '€${price.toStringAsFixed(0)}/mese';
    } else {
      priceLabel = '€${annualPrice.toStringAsFixed(0)}/anno';
      if (installments > 1) priceLabel += ' ($installments rate da €${price.toStringAsFixed(0)})';
    }

    return Opacity(
      opacity: isActive ? 1.0 : 0.5,
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        borderRadius: 12,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(plan['name'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                      if (!isActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                          child: const Text('Disattivo', style: TextStyle(fontSize: 9, color: Color(0xFFF87171), fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('$priceLabel · $activeSubs abb.', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_rounded, size: 16, color: Colors.grey[500]),
              onPressed: () => _showPlanModal(plan: plan),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.grey[500]),
              onPressed: () => _deletePlan(plan),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.card_giftcard_rounded, size: 16, color: const Color(0xFFA78BFA)),
                  const SizedBox(width: 6),
                  const Text('Offerte', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              _buildActionChip('+ Crea', const Color(0xFFA78BFA), onTap: () => _showOfferModal()),
            ],
          ),
          const SizedBox(height: 12),
          if (_offers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Center(child: Text('Nessuna offerta', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _offers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _buildOfferItem(_offers[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOfferItem(Map<String, dynamic> offer) {
    final isActive = offer['is_active'] == true;
    final title = offer['title'] as String? ?? '';
    final discountType = offer['discount_type'] as String? ?? 'percent';
    final discountValue = (offer['discount_value'] as num?)?.toDouble() ?? 0;
    final discountLabel = discountType == 'percent' ? '${discountValue.toStringAsFixed(0)}%' : '€${discountValue.toStringAsFixed(0)}';

    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 12,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('-$discountLabel', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                Text(isActive ? 'Attiva' : 'Bozza', style: TextStyle(fontSize: 10, color: isActive ? const Color(0xFF4ADE80) : Colors.grey[600])),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _toggleOffer(offer),
            child: Icon(
              isActive ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              size: 24,
              color: isActive ? const Color(0xFFFACC15) : const Color(0xFF4ADE80),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.grey[500]),
            onPressed: () => _deleteOffer(offer),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  AUTOMATION ZONE (Blue)
  // ═══════════════════════════════════════════════════════════
  Widget _buildAutomationZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildZoneHeader(
          icon: Icons.bolt_rounded,
          title: 'Automazione',
          subtitle: 'Comunicazione automatica ai clienti',
          color: const Color(0xFF60A5FA),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTemplatesCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildMessageLogCard()),
                ],
              );
            }
            return Column(
              children: [
                _buildTemplatesCard(),
                const SizedBox(height: 16),
                _buildMessageLogCard(),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTemplatesCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Modelli Messaggi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              _buildActionChip('+ Crea', const Color(0xFF60A5FA), onTap: () => _openAutomationBuilder()),
            ],
          ),
          const SizedBox(height: 12),
          if (_templates.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Nessun modello', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _templates.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _buildTemplateItem(_templates[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTemplateItem(Map<String, dynamic> tmpl) {
    final enabled = tmpl['enabled'] == true;
    final trigger = tmpl['trigger_type'] as String? ?? '';
    final triggerLabels = {
      'missed_workout': 'Allenamento Mancato',
      'days_inactive': 'Giorni Inattivo',
      'no_show_appointment': 'No-Show',
      'subscription_canceled': 'Abbonamento Cancellato',
    };

    return GestureDetector(
      onTap: () => _openAutomationBuilder(tmpl: tmpl),
      child: GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 12,
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? const Color(0xFF4ADE80) : Colors.grey[700],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tmpl['name'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                Text(triggerLabels[trigger] ?? trigger, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _toggleTemplate(tmpl),
            child: Container(
              width: 36, height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: enabled ? AppColors.primary : Colors.grey[700],
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 16, height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.grey[500]),
            onPressed: () => _deleteTemplate(tmpl),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    ));
  }

  void _swipeActivityPage(int delta) {
    final next = (_activityPage + delta).clamp(0, 1);
    if (next != _activityPage) setState(() => _activityPage = next);
  }

  Widget _buildMessageLogCard() {
    const tabDefs = [
      (icon: Icons.bolt_rounded, label: 'Automazioni', color: Color(0xFF60A5FA)),
      (icon: Icons.show_chart_rounded, label: 'Eventi', color: Color(0xFF9CA3AF)),
    ];
    final activeTab = tabDefs[_activityPage];

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab header
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < tabDefs.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _activityPage = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: _activityPage == i ? tabDefs[i].color.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tabDefs[i].icon, size: 14, color: _activityPage == i ? tabDefs[i].color : Colors.grey[700]),
                        const SizedBox(width: 5),
                        Text(
                          tabDefs[i].label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _activityPage == i ? FontWeight.w700 : FontWeight.w500,
                            color: _activityPage == i ? tabDefs[i].color : Colors.grey[700],
                          ),
                        ),
                        if (_activityPage == i) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: tabDefs[i].color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${i == 0 ? _messageLog.length : _activityFeed.length}',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: tabDefs[i].color),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              if (_activityPage == 0)
                _buildActionChip('Controlla', const Color(0xFF60A5FA), onTap: _triggerCheck),
            ],
          ),
          const SizedBox(height: 12),

          // Swipeable content area
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity == null) return;
              if (details.primaryVelocity! < -100) _swipeActivityPage(1);   // swipe left → next
              if (details.primaryVelocity! > 100) _swipeActivityPage(-1);   // swipe right → prev
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                key: ValueKey(_activityPage),
                height: 260,
                child: _activityPage == 0
                    ? _buildAutomationPage()
                    : _buildEventsPage(),
              ),
            ),
          ),

          // Dot indicators
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(2, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: _activityPage == i ? 16 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: _activityPage == i ? activeTab.color : Colors.grey[800],
                borderRadius: BorderRadius.circular(3),
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildAutomationPage() {
    if (_messageLog.isEmpty) {
      return Center(child: Text('Nessun messaggio inviato', style: TextStyle(fontSize: 12, color: Colors.grey[700])));
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      itemCount: _messageLog.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
      itemBuilder: (_, i) {
        final log = _messageLog[i];
        final status = log['status'] as String? ?? '';
        final triggerType = log['trigger_type'] as String? ?? '';
        return _buildLogRow(
          icon: status == 'failed' ? Icons.error_outline_rounded : Icons.send_rounded,
          iconColor: status == 'failed' ? const Color(0xFFEF4444) : const Color(0xFF60A5FA),
          text: '${log['template_name'] ?? 'Automazione'} → ${log['client_name'] ?? 'Cliente'}',
          subtitle: _triggerLabel(triggerType),
          trailing: _formatLogTime(log['triggered_at'] as String?),
        );
      },
    );
  }

  Widget _buildEventsPage() {
    if (_activityFeed.isEmpty) {
      return Center(child: Text('Nessun evento recente', style: TextStyle(fontSize: 12, color: Colors.grey[700])));
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      itemCount: _activityFeed.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
      itemBuilder: (_, i) {
        final item = _activityFeed[i];
        final type = item['type'] as String? ?? '';
        return _buildLogRow(
          icon: _feedIcon(type),
          iconColor: _feedColor(type),
          text: item['title'] as String? ?? item['description'] as String? ?? '',
          subtitle: item['description'] as String?,
          trailing: item['time'] as String? ?? _formatLogTime(item['timestamp'] as String?),
        );
      },
    );
  }

  Widget _buildLogRow({
    required IconData icon,
    Color? iconColor,
    required String text,
    String? subtitle,
    String? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor ?? Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[400]), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[700])),
              ],
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(trailing, style: TextStyle(fontSize: 10, color: Colors.grey[700])),
            ),
        ],
      ),
    );
  }

  String _triggerLabel(String triggerType) {
    switch (triggerType) {
      case 'days_inactive': return 'Inattività';
      case 'missed_workout': return 'Allenamento mancato';
      case 'no_show_appointment': return 'Appuntamento mancato';
      case 'subscription_canceled': return 'Abbonamento cancellato';
      case 'payment_failed': return 'Pagamento fallito';
      case 'upcoming_appointment': return 'Promemoria appuntamento';
      default: return triggerType;
    }
  }

  String _formatLogTime(String? isoTime) {
    if (isoTime == null || isoTime.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoTime);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m fa';
      if (diff.inHours < 24) return '${diff.inHours}h fa';
      if (diff.inDays < 7) return '${diff.inDays}g fa';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  Color _feedColor(String type) {
    switch (type) {
      case 'check_in': return const Color(0xFF34D399);
      case 'workout': return const Color(0xFFF97316);
      case 'subscription': return const Color(0xFFA78BFA);
      case 'appointment': return const Color(0xFF60A5FA);
      default: return Colors.grey[600]!;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  TEAM ZONE (Orange)
  // ═══════════════════════════════════════════════════════════
  /// Find commission data for a trainer by matching id/trainer_id
  Map<String, dynamic>? _commissionFor(Map<String, dynamic> trainer) {
    final tid = trainer['id']?.toString() ?? '';
    for (final c in _commissions) {
      if ((c['trainer_id']?.toString() ?? '') == tid || (c['id']?.toString() ?? '') == tid) return c;
    }
    return null;
  }

  Widget _buildTeamZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildZoneHeader(
          icon: Icons.people_rounded,
          title: 'Team',
          subtitle: 'I tuoi trainer e staff',
          color: AppColors.primary,
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _showCommissionsModal,
                    child: Row(
                      children: [
                        Icon(Icons.attach_money_rounded, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text('Commissioni', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _showTrainersModal,
                    child: Text('Vedi Tutti →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_trainers.isEmpty)
                Center(child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Nessun trainer', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ))
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 440),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _trainers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final t = _trainers[i];
                      final name = t['username'] as String? ?? '';
                      final rate = (t['commission_rate'] as num?)?.toDouble();
                      final comm = _commissionFor(t);
                      final revenue = (comm?['total_revenue'] as num?)?.toDouble() ?? 0;
                      final cut = (comm?['commission_due'] as num?)?.toDouble() ?? 0;
                      final clientCount = (comm?['client_count'] as num?)?.toInt() ?? (comm?['sub_count'] as num?)?.toInt() ?? 0;

                      return GestureDetector(
                        onTap: () => _showTrainerDetailSheet(t, comm),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              // Name row with rate badge
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ),
                                  if (rate != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text('${rate.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Stats row: Revenue · Cut · Clients
                              Row(
                                children: [
                                  _teamStatPill(Icons.trending_up_rounded, '€${revenue.toStringAsFixed(0)}', 'Ricavi'),
                                  const SizedBox(width: 6),
                                  _teamStatPill(Icons.payments_rounded, '€${cut.toStringAsFixed(0)}', 'Spettanza'),
                                  const SizedBox(width: 6),
                                  _teamStatPill(Icons.people_outline_rounded, '$clientCount', 'Clienti'),
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
          ),
        ),
      ],
    );
  }

  Widget _teamStatPill(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 12, color: Colors.grey[600]),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  // ─── Trainer Detail Sheet ───
  void _showTrainerDetailSheet(Map<String, dynamic> trainer, Map<String, dynamic>? comm) {
    final name = trainer['username'] as String? ?? '';
    final role = trainer['role'] as String? ?? 'trainer';
    final picture = trainer['profile_picture'] as String?;
    final rate = (trainer['commission_rate'] as num?)?.toDouble() ?? 0;
    final revenue = (comm?['total_revenue'] as num?)?.toDouble() ?? 0;
    final cut = (comm?['commission_due'] as num?)?.toDouble() ?? 0;
    final clientCount = (comm?['client_count'] as num?)?.toInt() ?? 0;
    final apptRevenue = (comm?['appt_revenue'] as num?)?.toDouble() ?? 0;
    final apptCount = (comm?['appt_count'] as num?)?.toInt() ?? 0;
    final subRevenue = (comm?['sub_revenue'] as num?)?.toDouble() ?? 0;
    final subCount = (comm?['sub_count'] as num?)?.toInt() ?? 0;
    final trainerId = trainer['id']?.toString() ?? '';

    final roleLabel = role == 'nutritionist' ? 'Nutrizionista' : role == 'staff' ? 'Staff' : 'Trainer';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.8,
        builder: (ctx, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: AppColors.primary.withValues(alpha: 0.3))),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // Avatar + Name + Role
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage: picture != null ? NetworkImage(picture) : null,
                    child: picture == null
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary))
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(roleLabel, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('${rate.toStringAsFixed(0)}% commissione',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Revenue summary cards
              Row(
                children: [
                  _detailCard('Ricavi Totali', '€${revenue.toStringAsFixed(2)}', Icons.trending_up_rounded, AppColors.primary),
                  const SizedBox(width: 10),
                  _detailCard('Spettanza', '€${cut.toStringAsFixed(2)}', Icons.payments_rounded, const Color(0xFF4CAF50)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _detailCard('Clienti', '$clientCount', Icons.people_rounded, const Color(0xFF42A5F5)),
                  const SizedBox(width: 10),
                  _detailCard('Appuntamenti', '$apptCount', Icons.calendar_today_rounded, const Color(0xFFAB47BC)),
                ],
              ),

              const SizedBox(height: 20),

              // Breakdown section
              Text('Dettaglio Ricavi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[400])),
              const SizedBox(height: 10),

              _breakdownRow('Appuntamenti', apptCount, apptRevenue),
              const SizedBox(height: 6),
              _breakdownRow('Abbonamenti', subCount, subRevenue),

              const SizedBox(height: 8),
              Divider(color: Colors.grey[800]),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Totale', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Text('€${revenue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Commissione (${rate.toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  Text('€${cut.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4CAF50))),
                ],
              ),

              const SizedBox(height: 24),

              // Chat button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _openChatWithTrainer(trainerId, name, picture);
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Apri Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(String label, int count, double amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text('$count', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(width: 16),
          Text('€${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _openChatWithTrainer(String trainerId, String trainerName, String? picture) async {
    try {
      final service = ref.read(clientServiceProvider);
      final conversations = await service.getConversations();
      Map<String, dynamic>? conv;
      for (final c in conversations) {
        if (c['other_user_id']?.toString() == trainerId) {
          conv = Map<String, dynamic>.from(c);
          break;
        }
      }
      conv ??= {
        'id': '',
        'other_user_id': trainerId,
        'other_user_name': trainerName,
        'other_user_profile_picture': picture,
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

  IconData _feedIcon(String type) {
    switch (type) {
      case 'check_in': return Icons.login_rounded;
      case 'workout': return Icons.fitness_center_rounded;
      case 'subscription': return Icons.card_membership_rounded;
      case 'appointment': return Icons.event_rounded;
      default: return Icons.circle_outlined;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  SHARED BUILDERS
  // ═══════════════════════════════════════════════════════════
  Widget _buildZoneHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(width: 4, height: 32, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildActionChip(String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  MODAL DIALOGS
  // ═══════════════════════════════════════════════════════════

  // ── Plan Modal ─────────────────────────────────────────
  void _showPlanModal({Map<String, dynamic>? plan}) {
    final isEdit = plan != null;
    final nameCtrl = TextEditingController(text: plan?['name'] as String? ?? '');
    final descCtrl = TextEditingController(text: plan?['description'] as String? ?? '');
    final monthlyPriceCtrl = TextEditingController(text: plan?['price']?.toString() ?? '');
    final annualPriceCtrl = TextEditingController(text: (plan?['annual_price'] ?? plan?['price'])?.toString() ?? '');
    final trialCtrl = TextEditingController(text: (plan?['trial_days'] ?? 0).toString());
    final featuresCtrl = TextEditingController(text: (plan?['features'] as List?)?.join('\n') ?? '');
    String billingType = plan?['billing_type'] as String? ?? 'annual';
    int installments = (plan?['installment_count'] as num?)?.toInt() ?? 12;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isEdit ? 'Modifica Piano' : 'Crea Piano', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _modalLabel('Nome Piano'),
                        _modalInput(nameCtrl, 'es. Base, Premium, VIP'),
                        const SizedBox(height: 12),
                        _modalLabel('Descrizione'),
                        _modalInput(descCtrl, 'Breve descrizione del piano', maxLines: 2),
                        const SizedBox(height: 12),
                        _modalLabel('Tipo di Fatturazione'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: _billingToggle('Mensile', 'monthly', billingType, (v) => setModalState(() => billingType = v))),
                            const SizedBox(width: 8),
                            Expanded(child: _billingToggle('Annuale', 'annual', billingType, (v) => setModalState(() => billingType = v))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (billingType == 'monthly') ...[
                          _modalLabel('Prezzo Mensile (€)'),
                          _modalInput(monthlyPriceCtrl, '49.90', keyboardType: TextInputType.number),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _modalLabel('Prezzo Annuale (€)'),
                                _modalInput(annualPriceCtrl, '600.00', keyboardType: TextInputType.number),
                              ])),
                              const SizedBox(width: 8),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _modalLabel('Rate'),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: installments,
                                      dropdownColor: const Color(0xFF252525),
                                      isExpanded: true,
                                      style: const TextStyle(fontSize: 14, color: Colors.white),
                                      items: [1, 2, 3, 4, 6, 12].map((n) => DropdownMenuItem(value: n, child: Text(n == 1 ? '1 (unico)' : '$n rate'))).toList(),
                                      onChanged: (v) => setModalState(() => installments = v!),
                                    ),
                                  ),
                                ),
                              ])),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        _modalLabel('Periodo di Prova (giorni)'),
                        _modalInput(trialCtrl, '0', keyboardType: TextInputType.number),
                        const SizedBox(height: 12),
                        _modalLabel('Caratteristiche (una per riga)'),
                        _modalInput(featuresCtrl, 'Allenamenti illimitati\nPiani alimentari\nCoaching 1-a-1', maxLines: 3),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final data = {
                                'name': nameCtrl.text,
                                'description': descCtrl.text,
                                'billing_type': billingType,
                                'trial_days': int.tryParse(trialCtrl.text) ?? 0,
                                'features': featuresCtrl.text.split('\n').where((l) => l.trim().isNotEmpty).toList(),
                              };
                              if (billingType == 'monthly') {
                                data['price'] = double.tryParse(monthlyPriceCtrl.text) ?? 0;
                              } else {
                                data['annual_price'] = double.tryParse(annualPriceCtrl.text) ?? 0;
                                data['installment_count'] = installments;
                                final annual = double.tryParse(annualPriceCtrl.text) ?? 0;
                                data['price'] = installments > 0 ? (annual / installments) : annual;
                              }

                              try {
                                if (isEdit) {
                                  await ref.read(ownerServiceProvider).updatePlan(plan['id'] as String, data);
                                } else {
                                  await ref.read(ownerServiceProvider).createPlan(data);
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                                _loadAll();
                              } catch (e) {
                                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Errore: $e')));
                              }
                            },
                            child: Text(isEdit ? 'Salva Modifiche' : 'Crea Piano'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Offer Modal ────────────────────────────────────────
  void _showOfferModal({Map<String, dynamic>? offer}) {
    final isEdit = offer != null;
    final titleCtrl = TextEditingController(text: offer?['title'] as String? ?? '');
    final descCtrl = TextEditingController(text: offer?['description'] as String? ?? '');
    final discountValueCtrl = TextEditingController(text: (offer?['discount_value'] as num?)?.toString() ?? '');
    final durationCtrl = TextEditingController(text: (offer?['duration_months'] ?? 1).toString());
    final couponCtrl = TextEditingController(text: offer?['coupon_code'] as String? ?? '');
    final maxUsesCtrl = TextEditingController(text: (offer?['max_uses'] as num?)?.toString() ?? '');
    String discountType = offer?['discount_type'] as String? ?? 'percent';
    String? planId = offer?['plan_id'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isEdit ? 'Modifica Offerta' : 'Crea Offerta', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _modalLabel('Titolo Offerta'),
                        _modalInput(titleCtrl, 'es. Offerta Capodanno'),
                        const SizedBox(height: 12),
                        _modalLabel('Descrizione'),
                        _modalInput(descCtrl, 'Descrivi l\'offerta', maxLines: 2),
                        const SizedBox(height: 12),
                        _modalLabel('Applica al Piano'),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: planId,
                              dropdownColor: const Color(0xFF252525),
                              isExpanded: true,
                              style: const TextStyle(fontSize: 14, color: Colors.white),
                              hint: const Text('Tutti i Piani', style: TextStyle(color: Colors.white54)),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Tutti i Piani')),
                                ..._plans.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['name'] as String? ?? ''))),
                              ],
                              onChanged: (v) => setModalState(() => planId = v),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _modalLabel('Tipo Sconto'),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: discountType,
                                    dropdownColor: const Color(0xFF252525),
                                    isExpanded: true,
                                    style: const TextStyle(fontSize: 14, color: Colors.white),
                                    items: const [
                                      DropdownMenuItem(value: 'percent', child: Text('Percentuale (%)')),
                                      DropdownMenuItem(value: 'fixed', child: Text('Importo Fisso (€)')),
                                    ],
                                    onChanged: (v) => setModalState(() => discountType = v!),
                                  ),
                                ),
                              ),
                            ])),
                            const SizedBox(width: 8),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _modalLabel('Valore Sconto'),
                              _modalInput(discountValueCtrl, 'es. 20', keyboardType: TextInputType.number),
                            ])),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _modalLabel('Durata (mesi)'),
                              _modalInput(durationCtrl, '1', keyboardType: TextInputType.number),
                            ])),
                            const SizedBox(width: 8),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _modalLabel('Codice Coupon'),
                              _modalInput(couponCtrl, 'es. SUMMER50'),
                            ])),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _modalLabel('Limite Utilizzo'),
                        _modalInput(maxUsesCtrl, 'Illimitato', keyboardType: TextInputType.number),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final data = {
                                'title': titleCtrl.text,
                                'description': descCtrl.text,
                                'discount_type': discountType,
                                'discount_value': double.tryParse(discountValueCtrl.text) ?? 0,
                                'duration_months': int.tryParse(durationCtrl.text) ?? 1,
                                'coupon_code': couponCtrl.text.toUpperCase(),
                                'plan_id': ?planId,
                                if (maxUsesCtrl.text.isNotEmpty) 'max_uses': int.tryParse(maxUsesCtrl.text),
                              };
                              try {
                                if (isEdit) {
                                  await ref.read(ownerServiceProvider).updateOffer(offer['id'] as String, data);
                                } else {
                                  await ref.read(ownerServiceProvider).createOffer(data);
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                                _loadAll();
                              } catch (e) {
                                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Errore: $e')));
                              }
                            },
                            child: Text(isEdit ? 'Salva Modifiche' : 'Crea Offerta'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Template Modal ─────────────────────────────────────
  void _showTemplateModal({Map<String, dynamic>? tmpl}) {
    final isEdit = tmpl != null;
    final nameCtrl = TextEditingController(text: tmpl?['name'] as String? ?? '');
    final messageCtrl = TextEditingController(text: tmpl?['message_template'] as String? ?? '');
    final daysCtrl = TextEditingController(text: (tmpl?['trigger_config']?['days_threshold'] as num?)?.toString() ?? '5');
    String trigger = tmpl?['trigger_type'] as String? ?? 'missed_workout';
    bool enabled = tmpl?['enabled'] as bool? ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final showDays = trigger == 'days_inactive';
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isEdit ? 'Modifica Modello' : 'Crea Messaggio Automatico', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _modalLabel('Nome Modello'),
                        _modalInput(nameCtrl, 'es. Promemoria Cliente Inattivo'),
                        const SizedBox(height: 12),
                        _modalLabel('Trigger'),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: trigger,
                              dropdownColor: const Color(0xFF252525),
                              isExpanded: true,
                              style: const TextStyle(fontSize: 14, color: Colors.white),
                              items: const [
                                DropdownMenuItem(value: 'missed_workout', child: Text('Allenamento Mancato')),
                                DropdownMenuItem(value: 'days_inactive', child: Text('Giorni Inattivo')),
                                DropdownMenuItem(value: 'no_show_appointment', child: Text('Appuntamento Non Presentato')),
                              ],
                              onChanged: (v) => setModalState(() => trigger = v!),
                            ),
                          ),
                        ),
                        if (showDays) ...[
                          const SizedBox(height: 12),
                          _modalLabel('Soglia Giorni'),
                          _modalInput(daysCtrl, '5', keyboardType: TextInputType.number),
                          Text('Invia messaggio quando il cliente non si allena da questo numero di giorni', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                        const SizedBox(height: 12),
                        _modalLabel('Metodi di Consegna'),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.check_box, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Text('Notifica In-App', style: TextStyle(fontSize: 13)),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.check_box_outline_blank, size: 18, color: Colors.grey[700]),
                          const SizedBox(width: 8),
                          Text('Email (Prossimamente)', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.check_box_outline_blank, size: 18, color: Colors.grey[700]),
                          const SizedBox(width: 8),
                          Text('WhatsApp (Prossimamente)', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        ]),
                        const SizedBox(height: 12),
                        _modalLabel('Messaggio'),
                        _modalInput(messageCtrl, 'Ciao {client_name}, abbiamo notato che hai saltato...', maxLines: 4),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 8,
                            children: ['{client_name}', '{days_inactive}', '{workout_title}', '{trainer_name}']
                                .map((v) => Text(v, style: const TextStyle(fontSize: 11, color: AppColors.primary)))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Attiva questo modello', style: TextStyle(fontSize: 13)),
                            GestureDetector(
                              onTap: () => setModalState(() => enabled = !enabled),
                              child: Container(
                                width: 44, height: 24,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: enabled ? AppColors.primary : Colors.grey[700],
                                ),
                                child: AnimatedAlign(
                                  duration: const Duration(milliseconds: 200),
                                  alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    width: 20, height: 20,
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              final data = {
                                'name': nameCtrl.text,
                                'trigger_type': trigger,
                                'message_template': messageCtrl.text,
                                'enabled': enabled,
                                'delivery_methods': ['in_app'],
                                'trigger_config': {
                                  if (showDays) 'days_threshold': int.tryParse(daysCtrl.text) ?? 5,
                                },
                              };
                              try {
                                if (isEdit) {
                                  await ref.read(ownerServiceProvider).updateAutomatedMessage(tmpl['id'] as String, data);
                                } else {
                                  await ref.read(ownerServiceProvider).createAutomatedMessage(data);
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                                _loadAll();
                              } catch (e) {
                                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Errore: $e')));
                              }
                            },
                            child: Text(isEdit ? 'Salva Modifiche' : 'Crea Modello'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Trainers Modal ─────────────────────────────────────
  void _showTrainersModal() async {
    final gymCode = await ref.read(ownerServiceProvider).getGymCode().catchError((_) => '');

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Gestione Team', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_pendingTrainers.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFACC15))),
                          const SizedBox(width: 8),
                          Text('Approvazioni in Attesa', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFFACC15), letterSpacing: 0.5)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._pendingTrainers.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildTrainerRow(t, pending: true),
                      )),
                      const SizedBox(height: 16),
                    ],
                    Text('Trainer Attivi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[600], letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    if (_trainers.isEmpty)
                      Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Nessun trainer', style: TextStyle(color: Colors.grey[600]))))
                    else
                      ..._trainers.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildTrainerRow(t, pending: false),
                      )),
                  ],
                ),
              ),
            ),
            // Footer with gym code
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
              ),
              child: Column(
                children: [
                  Text('Condividi il codice palestra per invitare trainer', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF252525), borderRadius: BorderRadius.circular(8)),
                        child: Text(gymCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primary, fontFamily: 'monospace', letterSpacing: 1.2)),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: gymCode));
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Codice copiato!')));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                          child: const Text('Copia', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainerRow(Map<String, dynamic> t, {required bool pending}) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
          child: Text(
            (t['username'] as String? ?? '?')[0].toUpperCase(),
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t['username'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              if (t['email'] != null)
                Text(t['email'] as String, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ),
        _buildRoleBadge(t['sub_role'] as String? ?? t['role'] as String? ?? 'trainer'),
        if (pending) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80), size: 24),
            onPressed: () {
              _approveTrainer(t['id'] as String);
              Navigator.pop(context);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: const Icon(Icons.cancel_rounded, color: Color(0xFFF87171), size: 24),
            onPressed: () {
              _rejectTrainer(t['id'] as String, t['username'] as String? ?? '');
              Navigator.pop(context);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ],
    );
  }

  // ── Commissions Modal ──────────────────────────────────
  void _showCommissionsModal() async {
    setState(() { _commissionsLoading = true; _commissionPeriod = 'month'; });

    try {
      final data = await ref.read(ownerServiceProvider).getCommissions(period: _commissionPeriod);
      if (mounted) setState(() { _commissions = data; _commissionsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _commissionsLoading = false);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          double totalOwed = _commissions.fold(0.0, (sum, c) => sum + ((c['commission_due'] as num?)?.toDouble() ?? 0));

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Commissioni Trainer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                // Period selector
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    children: [
                      Text('Periodo', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      const SizedBox(width: 12),
                      ...[('month', 'Questo mese'), ('last_month', 'Mese scorso'), ('year', 'Quest\'anno'), ('all', 'Sempre')].map((e) {
                        final isActive = _commissionPeriod == e.$1;
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: GestureDetector(
                            onTap: () async {
                              _commissionPeriod = e.$1;
                              setModalState(() {});
                              try {
                                final data = await ref.read(ownerServiceProvider).getCommissions(period: e.$1);
                                _commissions = data;
                                setModalState(() {});
                              } catch (_) {}
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? AppColors.primary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(e.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? AppColors.primary : Colors.white38)),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                // Commissions list
                Expanded(
                  child: _commissionsLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : _commissions.isEmpty
                          ? Center(child: Text('Nessun dato', style: TextStyle(color: Colors.grey[600])))
                          : ListView.separated(
                              padding: const EdgeInsets.all(20),
                              itemCount: _commissions.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (_, i) => _buildCommissionItem(_commissions[i], setModalState),
                            ),
                ),
                // Total footer
                if (_commissions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Totale dovuto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500], letterSpacing: 0.5)),
                        Text('€${totalOwed.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommissionItem(Map<String, dynamic> c, StateSetter setModalState) {
    final name = c['trainer_name'] as String? ?? c['username'] as String? ?? '';
    final rate = (c['commission_rate'] as num?)?.toDouble() ?? 0;
    final apptRevenue = (c['appt_revenue'] as num?)?.toDouble() ?? 0;
    final apptCount = (c['appt_count'] as num?)?.toInt() ?? 0;
    final subRevenue = (c['sub_revenue'] as num?)?.toDouble() ?? 0;
    final subCount = (c['sub_count'] as num?)?.toInt() ?? 0;
    final totalRevenue = (c['total_revenue'] as num?)?.toDouble() ?? 0;
    final commissionDue = (c['commission_due'] as num?)?.toDouble() ?? 0;
    final trainerId = c['trainer_id'] as String? ?? c['id'] as String? ?? '';

    final rateCtrl = TextEditingController(text: rate.toStringAsFixed(0));

    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              SizedBox(
                width: 54,
                height: 30,
                child: TextField(
                  controller: rateCtrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5))),
                  ),
                  onSubmitted: (val) async {
                    final newRate = double.tryParse(val);
                    if (newRate != null) {
                      try {
                        await ref.read(ownerServiceProvider).setCommissionRate(trainerId, newRate);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commissione aggiornata')));
                      } catch (_) {}
                    }
                  },
                ),
              ),
              const Text(' %', style: TextStyle(fontSize: 12, color: Colors.white38)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _commDetailRow('Appuntamenti', '€${apptRevenue.toStringAsFixed(0)}', '($apptCount)')),
              Expanded(child: _commDetailRow('Abbonamenti', '€${subRevenue.toStringAsFixed(0)}', '($subCount)')),
            ],
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Totale: €${totalRevenue.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              Text('Commissione: €${commissionDue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _commDetailRow(String label, String value, String count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        Row(
          children: [
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Text(count, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  ACTION HANDLERS
  // ═══════════════════════════════════════════════════════════
  Future<void> _deletePlan(Map<String, dynamic> plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Elimina Piano'),
        content: Text('Eliminare "${plan['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina', style: TextStyle(color: Color(0xFFF87171)))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(ownerServiceProvider).deletePlan(plan['id'] as String);
        _loadAll();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _toggleOffer(Map<String, dynamic> offer) async {
    try {
      await ref.read(ownerServiceProvider).updateOffer(offer['id'] as String, {'is_active': !(offer['is_active'] == true)});
      _loadAll();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _deleteOffer(Map<String, dynamic> offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Elimina Offerta'),
        content: Text('Eliminare "${offer['title']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina', style: TextStyle(color: Color(0xFFF87171)))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(ownerServiceProvider).deleteOffer(offer['id'] as String);
        _loadAll();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _openAutomationBuilder({Map<String, dynamic>? tmpl}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OwnerAutomationBuilderScreen(existingTemplate: tmpl)),
    );
    if (result == true) _loadAll();
  }

  Future<void> _toggleTemplate(Map<String, dynamic> tmpl) async {
    try {
      await ref.read(ownerServiceProvider).toggleAutomatedMessage(tmpl['id'] as String);
      _loadAll();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _deleteTemplate(Map<String, dynamic> tmpl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Elimina Modello'),
        content: Text('Eliminare "${tmpl['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina', style: TextStyle(color: Color(0xFFF87171)))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(ownerServiceProvider).deleteAutomatedMessage(tmpl['id'] as String);
        _loadAll();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _triggerCheck() async {
    try {
      await ref.read(ownerServiceProvider).triggerCheck();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Controllo eseguito')));
      _loadAll();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  MODAL HELPERS
  // ═══════════════════════════════════════════════════════════
  Widget _modalLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 0.5)),
    );
  }

  Widget _modalInput(TextEditingController ctrl, String hint, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[700]),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _billingToggle(String label, String value, String current, ValueChanged<String> onChanged) {
    final isActive = current == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? AppColors.primary : Colors.white.withValues(alpha: 0.1)),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isActive ? AppColors.primary : Colors.white54)),
      ),
    );
  }
}
