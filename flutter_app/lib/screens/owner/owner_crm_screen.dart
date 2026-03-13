import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/gym_provider.dart';
import '../../providers/owner_provider.dart';
import '../../widgets/dashboard_sheets.dart';

class OwnerCrmScreen extends ConsumerStatefulWidget {
  const OwnerCrmScreen({super.key});

  @override
  ConsumerState<OwnerCrmScreen> createState() => _OwnerCrmScreenState();
}

class _OwnerCrmScreenState extends ConsumerState<OwnerCrmScreen> {
  bool _loading = true;

  // Pipeline
  int _pipelineNew = 0;
  int _pipelineActive = 0;
  int _pipelineAtRisk = 0;
  int _pipelineChurning = 0;

  // Analytics
  String _engagementRate = '--%';
  String _avgHealth = '--';

  // At-risk clients
  List<Map<String, dynamic>> _atRiskClients = [];

  // Interactions
  List<Map<String, dynamic>> _interactions = [];

  // Ex-clients
  List<Map<String, dynamic>> _exClients = [];

  // Certificates
  List<Map<String, dynamic>> _certificates = [];

  String? _lastGymId;

  @override
  void initState() {
    super.initState();
    _syncGymContext();
    _loadAll();
  }

  void _syncGymContext() {
    final gymId = ref.read(activeGymIdProvider);
    if (gymId != null) {
      ref.read(apiClientProvider).activeGymId = gymId;
    }
  }

  Future<void> _loadAll() async {
    final svc = ref.read(ownerServiceProvider);
    try {
      final results = await Future.wait([
        svc.getCrmPipeline().catchError((_) => <String, dynamic>{}),
        svc.getCrmAnalytics().catchError((_) => <String, dynamic>{}),
        svc.getAtRiskClients().catchError((_) => <Map<String, dynamic>>[]),
        svc.getCrmInteractions().catchError((_) => <Map<String, dynamic>>[]),
        svc.getExClients().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;

      final pipeline = results[0] as Map<String, dynamic>;
      final analytics = results[1] as Map<String, dynamic>;

      setState(() {
        _pipelineNew = (pipeline['new'] as num?)?.toInt() ?? 0;
        _pipelineActive = (pipeline['active'] as num?)?.toInt() ?? 0;
        _pipelineAtRisk = (pipeline['at_risk'] as num?)?.toInt() ?? 0;
        _pipelineChurning = (pipeline['churning'] as num?)?.toInt() ?? 0;

        _engagementRate = '${((analytics['engagement_rate'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}%';
        _avgHealth = ((analytics['avg_health_score'] as num?)?.toDouble() ?? 0).toStringAsFixed(1);

        _atRiskClients = results[2] as List<Map<String, dynamic>>;
        _interactions = results[3] as List<Map<String, dynamic>>;
        _exClients = results[4] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentGymId = ref.watch(activeGymIdProvider);
    if (_lastGymId != null && currentGymId != _lastGymId) {
      _lastGymId = currentGymId;
      ref.read(apiClientProvider).activeGymId = currentGymId;
      Future.microtask(() => _loadAll());
    }
    _lastGymId = currentGymId;

    final isDesktop = MediaQuery.of(context).size.width > 1024;

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
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [AppColors.primary, Color(0xFFFB923C)],
                              ).createShader(bounds),
                              child: const Text('CRM', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                            ),
                            const SizedBox(height: 2),
                            Text('Gestione clienti', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CRM', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                          const SizedBox(height: 4),
                          const Text('Gestione Clienti', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Pipeline
                    _buildPipelineSection(isDesktop),
                    const SizedBox(height: 24),

                    // At-Risk Clients
                    _buildAtRiskSection(),
                    const SizedBox(height: 24),

                    // Ex-Clients
                    _buildExClientsSection(),
                    const SizedBox(height: 24),

                    // Recent Interactions
                    _buildInteractionsSection(),
                    const SizedBox(height: 24),

                    // Medical Certificates
                    _buildCertificatesSection(),
                  ],
                ),
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PIPELINE
  // ═══════════════════════════════════════════════════════════
  Widget _buildPipelineSection(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildZoneBar(AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pipeline Clienti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5)),
                  Text('Stato dei membri', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_engagementRate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4ADE80))),
                Text('Coinvolgimento', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_avgHealth, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF60A5FA))),
                Text('Salute Media', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: isDesktop ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.5,
          children: [
            _buildPipelineCard('$_pipelineNew', 'Nuovi', '< 14 giorni', const Color(0xFF4ADE80), onTap: () => _showPipelineClients('new', 'Nuovi', const Color(0xFF4ADE80))),
            _buildPipelineCard('$_pipelineActive', 'Attivi', 'Coinvolti', const Color(0xFF60A5FA), onTap: () => _showPipelineClients('active', 'Attivi', const Color(0xFF60A5FA))),
            _buildPipelineCard('$_pipelineAtRisk', 'A Rischio', '5-14 giorni', const Color(0xFFFACC15), onTap: () => _showPipelineClients('at_risk', 'A Rischio', const Color(0xFFFACC15))),
            _buildPipelineCard('$_pipelineChurning', 'In Abbandono', '> 14 giorni', const Color(0xFFF87171), onTap: () => _showPipelineClients('churning', 'In Abbandono', const Color(0xFFF87171))),
          ],
        ),
      ],
    );
  }

  Widget _buildPipelineCard(String value, String label, String sub, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500]), overflow: TextOverflow.ellipsis),
              Text(sub, style: TextStyle(fontSize: 9, color: Colors.grey[700]), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPipelineClients(String status, String title, Color color) async {
    // Show loading sheet immediately
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PipelineClientsSheet(
        status: status,
        title: title,
        color: color,
        onClientTap: (client) {
          Navigator.pop(ctx);
          _showPipelineClientDetail(client, color);
        },
      ),
    );
  }

  void _showPipelineClientDetail(Map<String, dynamic> client, Color color) {
    final clientId = client['id']?.toString() ?? '';
    final name = client['name'] as String? ?? '';
    final streak = (client['streak'] as num?)?.toInt() ?? 0;
    final healthScore = (client['health_score'] as num?)?.toInt() ?? 0;
    final workouts = (client['completed_workouts'] as num?)?.toInt() ?? 0;
    final courses = (client['completed_courses'] as num?)?.toInt() ?? 0;
    final trainerName = client['trainer_name'] as String?;
    final planName = client['plan_name'] as String?;
    final email = client['email'] as String?;
    final daysInactive = (client['days_inactive'] as num?)?.toInt() ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase(),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
                ),
              ),
              const SizedBox(height: 12),
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: GestureDetector(
                    onTap: () { Navigator.pop(ctx); _showStreakDetail(clientId, name); },
                    child: _detailStatCard(Icons.local_fire_department, '$streak', 'Daystreak', AppColors.primary),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: GestureDetector(
                    onTap: () { Navigator.pop(ctx); _showDietDetail(clientId, name); },
                    child: _detailStatCard(Icons.favorite, '$healthScore', 'Salute', const Color(0xFF4ADE80)),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: GestureDetector(
                    onTap: () { Navigator.pop(ctx); _showWorkoutDetail(clientId, name); },
                    child: _detailStatCard(Icons.fitness_center, '$workouts', 'Allenamenti', const Color(0xFF60A5FA)),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: GestureDetector(
                    onTap: () { Navigator.pop(ctx); _showCoursesDetail(clientId, name, courses); },
                    child: _detailStatCard(Icons.school, '$courses', 'Corsi', const Color(0xFFA78BFA)),
                  )),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _detailInfoRow(Icons.person, 'Trainer', trainerName ?? 'Nessun trainer'),
                    const SizedBox(height: 10),
                    _detailInfoRow(Icons.card_membership, 'Piano', planName ?? 'Nessun piano attivo'),
                    const SizedBox(height: 10),
                    _detailInfoRow(Icons.schedule, 'Inattivo da', '${daysInactive}g'),
                    if (email != null) ...[
                      const SizedBox(height: 10),
                      _detailInfoRow(Icons.email_outlined, 'Email', email),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openChatWithClient(client);
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Apri Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── STREAK DETAIL ──
  void _showStreakDetail(String clientId, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StreakDetailSheet(clientId: clientId, name: name),
    );
  }

  // ── DIET/HEALTH DETAIL ──
  void _showDietDetail(String clientId, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DietDetailSheet(clientId: clientId, name: name),
    );
  }

  // ── WORKOUT DETAIL ──
  void _showWorkoutDetail(String clientId, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WorkoutDetailSheet(clientId: clientId, name: name),
    );
  }

  // ── COURSES DETAIL ──
  void _showCoursesDetail(String clientId, String name, int totalCourses) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CoursesDetailSheet(clientId: clientId, name: name, totalCourses: totalCourses),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  AT-RISK CLIENTS
  // ═══════════════════════════════════════════════════════════
  Widget _buildAtRiskSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildZoneBar(const Color(0xFFFACC15)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Clienti a Rischio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5)),
                  Text('Richiede attenzione', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_atRiskClients.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF4ADE80)),
                SizedBox(width: 8),
                Text('Nessun cliente a rischio! Ottima fidelizzazione.', style: TextStyle(fontSize: 13, color: Color(0xFF4ADE80))),
              ],
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 440),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _atRiskClients.length,
              separatorBuilder: (_, i) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = _atRiskClients[i];
                final name = c['username'] as String? ?? c['name'] as String? ?? '';
                final daysInactive = (c['days_inactive'] as num?)?.toInt() ?? 0;
                final streak = (c['streak'] as num?)?.toInt() ?? 0;
                final trainerName = c['trainer_name'] as String?;
                final pipelineStatus = c['pipeline_status'] as String? ?? '';
                final isCritical = pipelineStatus == 'churning';

                return GestureDetector(
                  onTap: () => _showClientDetail(c),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        // Avatar with 2-letter initials
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAB308).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFACC15)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Name + info row
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                  ),
                                  if (streak > 0) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.local_fire_department, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 2),
                                    Text('$streak', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${daysInactive}g inattivo · ${trainerName ?? 'Nessun trainer'}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCritical
                                ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                                : const Color(0xFFEAB308).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isCritical ? 'In Abbandono' : 'A Rischio',
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: isCritical ? const Color(0xFFF87171) : const Color(0xFFFACC15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right, size: 18, color: Colors.grey[700]),
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

  void _showClientDetail(Map<String, dynamic> client) {
    final name = client['username'] as String? ?? client['name'] as String? ?? '';
    final daysInactive = (client['days_inactive'] as num?)?.toInt() ?? 0;
    final streak = (client['streak'] as num?)?.toInt() ?? 0;
    final healthScore = (client['health_score'] as num?)?.toInt() ?? 0;
    final trainerName = client['trainer_name'] as String?;
    final planName = client['plan_name'] as String?;
    final lastWorkout = client['last_workout_date'] as String?;
    final email = client['email'] as String?;
    final pipelineStatus = client['pipeline_status'] as String? ?? '';
    final isCritical = pipelineStatus == 'churning';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),

                // Avatar + Name + Badge
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAB308).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFFACC15)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCritical
                        ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                        : const Color(0xFFEAB308).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCritical ? 'In Abbandono · ${daysInactive}g inattivo' : 'A Rischio · ${daysInactive}g inattivo',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: isCritical ? const Color(0xFFF87171) : const Color(0xFFFACC15),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Stats row: Streak, Health, Trainer
                Row(
                  children: [
                    Expanded(child: _detailStatCard(Icons.local_fire_department, '$streak', 'Daystreak', AppColors.primary)),
                    const SizedBox(width: 10),
                    Expanded(child: _detailStatCard(Icons.favorite, '$healthScore', 'Salute', const Color(0xFF4ADE80))),
                    const SizedBox(width: 10),
                    Expanded(child: _detailStatCard(Icons.person, trainerName ?? '-', 'Trainer', const Color(0xFF60A5FA))),
                  ],
                ),
                const SizedBox(height: 12),

                // Plan + Last workout info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _detailInfoRow(Icons.card_membership, 'Piano', planName ?? 'Nessun piano attivo'),
                      const SizedBox(height: 10),
                      _detailInfoRow(Icons.fitness_center, 'Ultimo allenamento', lastWorkout ?? 'Mai'),
                      if (email != null) ...[
                        const SizedBox(height: 10),
                        _detailInfoRow(Icons.email_outlined, 'Email', email),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Open chat button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openChatWithClient(client);
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('Apri Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openChatWithClient(Map<String, dynamic> client) async {
    final clientId = client['id']?.toString() ?? '';
    final clientName = client['username'] as String? ?? client['name'] as String? ?? '';
    final clientPicture = client['profile_picture'] as String?;

    try {
      final service = ref.read(clientServiceProvider);
      final conversations = await service.getConversations();
      Map<String, dynamic>? conv;
      for (final c in conversations) {
        if (c['other_user_id']?.toString() == clientId) {
          conv = Map<String, dynamic>.from(c);
          break;
        }
      }
      conv ??= {
        'id': '',
        'other_user_id': clientId,
        'other_user_name': clientName,
        'other_user_profile_picture': clientPicture,
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

  Widget _detailStatCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _detailInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  EX-CLIENTS
  // ═══════════════════════════════════════════════════════════
  Widget _buildExClientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildZoneBar(const Color(0xFF6B7280)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ex-Clienti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5)),
                  Text('Abbonamenti scaduti o cancellati', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF6B7280).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_exClients.length}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_exClients.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text('Nessun ex-cliente', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 440),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _exClients.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = _exClients[i];
                final name = c['name'] as String? ?? '';
                final planName = c['last_plan_name'] as String? ?? 'Nessun piano';
                final daysSince = (c['days_since_cancellation'] as num?)?.toInt() ?? 0;
                final phone = c['phone'] as String?;

                return GestureDetector(
                  onTap: () => _showExClientDetail(c),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B7280).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(
                                '$planName · ${daysSince}g fa',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (phone != null && phone.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.message, size: 18, color: Color(0xFF25D366)),
                            onPressed: () => _openWhatsApp(phone, 'Ciao $name! Ci manchi in palestra. Torna a trovarci!'),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B7280).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Ex-Cliente',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right, size: 18, color: Colors.grey[700]),
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

  void _showExClientDetail(Map<String, dynamic> client) {
    final name = client['name'] as String? ?? '';
    final planName = client['last_plan_name'] as String? ?? 'Nessun piano';
    final daysSince = (client['days_since_cancellation'] as num?)?.toInt() ?? 0;
    final canceledAt = client['canceled_at'] as String? ?? '';
    final email = client['email'] as String?;
    final phone = client['phone'] as String?;
    final subStatus = client['last_subscription_status'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),

              // Avatar
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF6B7280).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF)),
                ),
              ),
              const SizedBox(height: 12),
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B7280).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Ex-Cliente · ${daysSince}g fa',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF)),
                ),
              ),
              const SizedBox(height: 20),

              // Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _detailInfoRow(Icons.card_membership, 'Ultimo piano', planName),
                    const SizedBox(height: 10),
                    _detailInfoRow(Icons.cancel_outlined, 'Stato', subStatus == 'past_due' ? 'Pagamento scaduto' : 'Cancellato'),
                    if (canceledAt.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _detailInfoRow(Icons.calendar_today, 'Data cancellazione', canceledAt.length >= 10 ? canceledAt.substring(0, 10) : canceledAt),
                    ],
                    if (email != null) ...[
                      const SizedBox(height: 10),
                      _detailInfoRow(Icons.email_outlined, 'Email', email),
                    ],
                    if (phone != null) ...[
                      const SizedBox(height: 10),
                      _detailInfoRow(Icons.phone, 'Telefono', phone),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  if (phone != null && phone.isNotEmpty)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openWhatsApp(phone, 'Ciao $name! Ci manchi in palestra. Abbiamo delle offerte speciali per te. Torna a trovarci!');
                        },
                        icon: const Icon(Icons.message, size: 16),
                        label: const Text('WhatsApp'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  if (phone != null && phone.isNotEmpty)
                    const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openChatWithClient(client);
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: const Text('Apri Chat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(String phone, String message) async {
    final svc = ref.read(ownerServiceProvider);
    try {
      final result = await svc.generateWhatsappLink(phone, message);
      final link = result['whatsapp_link'] as String;
      final uri = Uri.parse(link);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  RECENT INTERACTIONS
  // ═══════════════════════════════════════════════════════════
  Widget _buildInteractionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildZoneBar(Colors.grey[600]!),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Attività Recenti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 0.5)),
                  Text('Interazioni dei clienti', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            GestureDetector(
              onTap: _loadAll,
              child: const Text('Aggiorna', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_interactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text('Nessuna attività recente', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 256),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _interactions.length,
              separatorBuilder: (_, _i) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final item = _interactions[i];
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 6, color: Colors.grey[700]),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item['description'] as String? ?? item['message'] as String? ?? '',
                          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  CERTIFICATES
  // ═══════════════════════════════════════════════════════════
  Widget _buildCertificatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildZoneBar(const Color(0xFF4ADE80)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Certificati Medici', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 0.5)),
                  Text('Stato certificati dei membri', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_certificates.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text('Nessun certificato', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 256),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _certificates.length,
              itemBuilder: (_, i) {
                final cert = _certificates[i];
                return Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                  child: Text(cert['description'] as String? ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildZoneBar(Color color) {
    return Container(width: 4, height: 32, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)));
  }
}

class _PipelineClientsSheet extends ConsumerStatefulWidget {
  final String status;
  final String title;
  final Color color;
  final void Function(Map<String, dynamic>) onClientTap;

  const _PipelineClientsSheet({
    required this.status,
    required this.title,
    required this.color,
    required this.onClientTap,
  });

  @override
  ConsumerState<_PipelineClientsSheet> createState() => _PipelineClientsSheetState();
}

class _PipelineClientsSheetState extends ConsumerState<_PipelineClientsSheet> {
  List<Map<String, dynamic>> _clients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final svc = ref.read(ownerServiceProvider);
      final data = await svc.getPipelineClients(widget.status);
      if (mounted) setState(() { _clients = data; _loading = false; });
    } catch (e) {
      debugPrint('PIPELINE CLIENTS ERROR: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(width: 4, height: 24, decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (!_loading)
                Text('${_clients.length} clienti', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          else if (_clients.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Nessun cliente in questa categoria', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _clients.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final c = _clients[i];
                  final name = c['name'] as String? ?? '';
                  final streak = (c['streak'] as num?)?.toInt() ?? 0;
                  final workouts = (c['completed_workouts'] as num?)?.toInt() ?? 0;
                  final courses = (c['completed_courses'] as num?)?.toInt() ?? 0;

                  return GestureDetector(
                    onTap: () => widget.onClientTap(c),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: widget.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase(),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.color),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                    if (streak > 0) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.local_fire_department, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 2),
                                      Text('$streak', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$workouts allenamenti · $courses corsi',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 18, color: Colors.grey[700]),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  STREAK DETAIL SHEET
// ═══════════════════════════════════════════════════════════
class _StreakDetailSheet extends ConsumerStatefulWidget {
  final String clientId;
  final String name;
  const _StreakDetailSheet({required this.clientId, required this.name});
  @override
  ConsumerState<_StreakDetailSheet> createState() => _StreakDetailSheetState();
}

class _StreakDetailSheetState extends ConsumerState<_StreakDetailSheet> {
  Map<String, dynamic> _data = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final svc = ref.read(ownerServiceProvider);
      final data = await svc.getClientWeekStreak(widget.clientId);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      debugPrint('STREAK ERROR: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final streak = (_data['current_streak'] as num?)?.toInt() ?? 0;
    final days = _data['days'] as List<dynamic>? ?? [];

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.local_fire_department, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Daystreak - ${widget.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primary))
          else ...[
            // Streak badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.local_fire_department, size: 24, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('$streak giorni consecutivi', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ]),
            ),
            const SizedBox(height: 20),
            // 14-day calendar grid
            if (days.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: days.map<Widget>((d) {
                  final day = d as Map<String, dynamic>;
                  final dayName = day['day_name'] as String? ?? '';
                  final completed = day['completed'] as bool? ?? false;
                  final isToday = day['is_today'] as bool? ?? false;
                  final total = (day['total'] as num?)?.toInt() ?? 0;
                  final done = (day['done'] as num?)?.toInt() ?? 0;
                  final date = day['date'] as String? ?? '';
                  final dateShort = date.length >= 10 ? date.substring(8, 10) : '';

                  return Container(
                    width: 56,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: completed
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : isToday
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: isToday ? Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5) : null,
                    ),
                    child: Column(children: [
                      Text(dayName, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                      const SizedBox(height: 2),
                      Text(dateShort, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: completed ? AppColors.primary : Colors.grey[400])),
                      const SizedBox(height: 2),
                      if (total > 0)
                        Text('$done/$total', style: TextStyle(fontSize: 9, color: completed ? AppColors.primary : Colors.grey[600]))
                      else
                        Text('--', style: TextStyle(fontSize: 9, color: Colors.grey[700])),
                    ]),
                  );
                }).toList(),
              ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  DIET/HEALTH DETAIL SHEET
// ═══════════════════════════════════════════════════════════
class _DietDetailSheet extends ConsumerStatefulWidget {
  final String clientId;
  final String name;
  const _DietDetailSheet({required this.clientId, required this.name});
  @override
  ConsumerState<_DietDetailSheet> createState() => _DietDetailSheetState();
}

class _DietDetailSheetState extends ConsumerState<_DietDetailSheet> {
  Map<String, dynamic> _weekData = {};
  Map<String, dynamic> _monthData = {};
  bool _loading = true;
  String _period = 'week'; // 'week' or 'month'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final svc = ref.read(ownerServiceProvider);
      final results = await Future.wait([
        svc.getClientDietConsistency(widget.clientId, period: 'week'),
        svc.getClientDietConsistency(widget.clientId, period: 'month'),
      ]);
      if (mounted) setState(() {
        _weekData = results[0] as Map<String, dynamic>;
        _monthData = results[1] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      debugPrint('DIET ERROR: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _data => _period == 'week' ? _weekData : _monthData;

  @override
  Widget build(BuildContext context) {
    final avgScore = (_data['average_score'] as num?)?.toInt() ?? 0;
    final currentStreak = (_data['current_streak'] as num?)?.toInt() ?? 0;
    final totalDays = (_data['total_days'] as num?)?.toInt() ?? 0;
    final dietDays = _data['data'] as List<dynamic>? ?? [];

    // Calculate averages for the period
    int avgCal = 0, avgProtein = 0;
    if (dietDays.isNotEmpty) {
      int totalCal = 0, totalProtein = 0;
      for (final d in dietDays) {
        totalCal += ((d as Map)['calories'] as num?)?.toInt() ?? 0;
        totalProtein += (d['protein'] as num?)?.toInt() ?? 0;
      }
      avgCal = totalCal ~/ dietDays.length;
      avgProtein = totalProtein ~/ dietDays.length;
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.favorite, size: 20, color: Color(0xFF4ADE80)),
            const SizedBox(width: 8),
            Expanded(child: Text('Salute - ${widget.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 12),
          // Period toggle
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              _periodTab('Settimana', 'week'),
              _periodTab('Mese', 'month'),
            ]),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFF4ADE80)))
          else ...[
            // Summary stats
            Row(children: [
              _dietStat('$avgScore%', 'Punteggio', _scoreColor(avgScore)),
              const SizedBox(width: 8),
              _dietStat('$currentStreak', 'Serie', AppColors.primary),
              const SizedBox(width: 8),
              _dietStat('$avgCal', 'kcal/g', const Color(0xFF60A5FA)),
              const SizedBox(width: 8),
              _dietStat('${avgProtein}g', 'Proteine', const Color(0xFFFACC15)),
            ]),
            const SizedBox(height: 12),
            // Consistency bar chart
            if (dietDays.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Consistenza giornaliera',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400]),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(dietDays.length, (i) {
                    final day = dietDays[i] as Map<String, dynamic>;
                    final score = (day['score'] as num?)?.toInt() ?? 0;
                    final barHeight = (score / 100 * 48).clamp(4.0, 48.0);
                    final date = day['date'] as String? ?? '';
                    String label = '';
                    try {
                      final dt = DateTime.parse(date);
                      label = ['L','M','M','G','V','S','D'][dt.weekday - 1];
                    } catch (_) {}
                    return Expanded(
                      child: Tooltip(
                        message: '$date: $score%',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: _scoreColor(score),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (_period == 'week')
                              Text(label, style: TextStyle(fontSize: 8, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Detailed day list
            if (dietDays.isNotEmpty)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: dietDays.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final day = dietDays[dietDays.length - 1 - i] as Map<String, dynamic>;
                    final date = day['date'] as String? ?? '';
                    final score = (day['score'] as num?)?.toInt() ?? 0;
                    final cal = (day['calories'] as num?)?.toInt() ?? 0;
                    final protein = (day['protein'] as num?)?.toInt() ?? 0;
                    final carbs = (day['carbs'] as num?)?.toInt() ?? 0;
                    final fat = (day['fat'] as num?)?.toInt() ?? 0;
                    final hydration = (day['hydration'] as num?)?.toInt() ?? 0;
                    final targetCal = (day['target_calories'] as num?)?.toInt() ?? 0;

                    String formattedDate = date;
                    try {
                      final dt = DateTime.parse(date);
                      final weekdays = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
                      formattedDate = '${weekdays[dt.weekday - 1]} ${dt.day}/${dt.month}';
                    } catch (_) {}

                    final calPct = targetCal > 0 ? (cal / targetCal * 100).round() : 0;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: _scoreColor(score).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text('$score', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _scoreColor(score))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(formattedDate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$cal kcal${targetCal > 0 ? ' ($calPct%)' : ''} · P:${protein}g · C:${carbs}g · F:${fat}g',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                            if (hydration > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFF60A5FA).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.water_drop, size: 12, color: Color(0xFF60A5FA)),
                                  const SizedBox(width: 2),
                                  Text('${(hydration / 1000).toStringAsFixed(1)}L', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF60A5FA))),
                                ]),
                              ),
                          ]),
                          // Calorie bar
                          if (targetCal > 0) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: (cal / targetCal).clamp(0, 1.5),
                                backgroundColor: Colors.white.withValues(alpha: 0.06),
                                valueColor: AlwaysStoppedAnimation(_scoreColor(score).withValues(alpha: 0.6)),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  Icon(Icons.restaurant_outlined, size: 48, color: Colors.grey[700]),
                  const SizedBox(height: 12),
                  Text('Nessun dato dieta', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                ]),
              ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _periodTab(String label, String value) {
    final selected = _period == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _period = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF4ADE80).withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF4ADE80) : Colors.grey[600],
          )),
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 70) return const Color(0xFF4ADE80);
    if (score >= 40) return const Color(0xFFFACC15);
    return const Color(0xFFF87171);
  }

  Widget _dietStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  WORKOUT DETAIL SHEET
// ═══════════════════════════════════════════════════════════
class _WorkoutDetailSheet extends ConsumerStatefulWidget {
  final String clientId;
  final String name;
  const _WorkoutDetailSheet({required this.clientId, required this.name});
  @override
  ConsumerState<_WorkoutDetailSheet> createState() => _WorkoutDetailSheetState();
}

class _WorkoutDetailSheetState extends ConsumerState<_WorkoutDetailSheet> {
  List<Map<String, dynamic>> _workoutDays = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final svc = ref.read(ownerServiceProvider);
      final data = await svc.getClientWorkoutLog(widget.clientId);
      if (mounted) setState(() { _workoutDays = data; _loading = false; });
    } catch (e) {
      debugPrint('WORKOUT LOG ERROR: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.fitness_center, size: 20, color: Color(0xFF60A5FA)),
            const SizedBox(width: 8),
            Text('Allenamenti - ${widget.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (!_loading)
              Text('${_workoutDays.length} sessioni', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ]),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primary))
          else if (_workoutDays.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.fitness_center_rounded, size: 40, color: Colors.grey[700]),
                const SizedBox(height: 12),
                Text('Nessun allenamento completato', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ]),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _workoutDays.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final day = _workoutDays[i];
                  final date = day['date'] as String? ?? '';
                  final exercises = day['exercises'] as List<dynamic>? ?? [];
                  final dateShort = date.length >= 10 ? date.substring(5) : date;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF60A5FA).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(dateShort, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF60A5FA))),
                          ),
                          const SizedBox(width: 8),
                          Text('${exercises.length} esercizi', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        ]),
                        const SizedBox(height: 8),
                        ...exercises.map<Widget>((ex) {
                          final e = ex as Map<String, dynamic>;
                          final exName = e['exercise_name'] as String? ?? '';
                          final sets = e['sets'] as List<dynamic>? ?? [];
                          final metricType = e['metric_type'] as String? ?? 'weight_reps';

                          String setsInfo = sets.map((s) {
                            final set = s as Map<String, dynamic>;
                            if (metricType == 'weight_reps') {
                              final reps = set['reps'] ?? 0;
                              final weight = set['weight'] ?? 0;
                              return '${weight}kg x $reps';
                            } else if (metricType == 'duration') {
                              final duration = set['duration'] ?? 0;
                              return '${duration}s';
                            } else if (metricType == 'distance') {
                              final distance = set['distance'] ?? 0;
                              return '${distance}m';
                            }
                            return '${set['reps'] ?? 0} reps';
                          }).join(' · ');

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(children: [
                              Icon(Icons.circle, size: 4, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(exName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(setsInfo, style: TextStyle(fontSize: 10, color: Colors.grey[500]), overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  COURSES DETAIL SHEET
// ═══════════════════════════════════════════════════════════
class _CoursesDetailSheet extends ConsumerStatefulWidget {
  final String clientId;
  final String name;
  final int totalCourses;
  const _CoursesDetailSheet({required this.clientId, required this.name, required this.totalCourses});
  @override
  ConsumerState<_CoursesDetailSheet> createState() => _CoursesDetailSheetState();
}

class _CoursesDetailSheetState extends ConsumerState<_CoursesDetailSheet> {
  List<Map<String, dynamic>> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final svc = ref.read(ownerServiceProvider);
      final data = await svc.getClientCourseLog(widget.clientId);
      if (mounted) setState(() { _courses = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.school, size: 20, color: Color(0xFFA78BFA)),
            const SizedBox(width: 8),
            Text('Corsi - ${widget.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFA78BFA).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Text('${widget.totalCourses} totali', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFA78BFA))),
            ),
          ]),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFFA78BFA)))
          else if (_courses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                Icon(Icons.school_outlined, size: 48, color: Colors.grey[700]),
                const SizedBox(height: 12),
                Text('Nessun corso completato', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
              ]),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _courses.length,
                separatorBuilder: (_, __) => Divider(color: Colors.grey[800], height: 1),
                itemBuilder: (ctx, i) {
                  final c = _courses[i];
                  final title = c['title'] ?? 'Corso';
                  final date = c['date'] ?? '';
                  // Format date nicely
                  String formattedDate = date;
                  try {
                    final dt = DateTime.parse(date);
                    final weekdays = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
                    formattedDate = '${weekdays[dt.weekday - 1]} ${dt.day}/${dt.month}/${dt.year}';
                  } catch (_) {}

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFA78BFA).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.school, size: 20, color: Color(0xFFA78BFA)),
                    ),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(formattedDate, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    trailing: const Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 20),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
