import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/client_provider.dart';
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

  // Certificates
  List<Map<String, dynamic>> _certificates = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final svc = ref.read(ownerServiceProvider);
    try {
      final results = await Future.wait([
        svc.getCrmPipeline().catchError((_) => <String, dynamic>{}),
        svc.getCrmAnalytics().catchError((_) => <String, dynamic>{}),
        svc.getAtRiskClients().catchError((_) => <Map<String, dynamic>>[]),
        svc.getCrmInteractions().catchError((_) => <Map<String, dynamic>>[]),
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
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          childAspectRatio: 2.2,
          children: [
            _buildPipelineCard('$_pipelineNew', 'Nuovi', '< 14 giorni', const Color(0xFF4ADE80)),
            _buildPipelineCard('$_pipelineActive', 'Attivi', 'Coinvolti', const Color(0xFF60A5FA)),
            _buildPipelineCard('$_pipelineAtRisk', 'A Rischio', '5-14 giorni', const Color(0xFFFACC15)),
            _buildPipelineCard('$_pipelineChurning', 'In Abbandono', '> 14 giorni', const Color(0xFFF87171)),
          ],
        ),
      ],
    );
  }

  Widget _buildPipelineCard(String value, String label, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey[700])),
        ],
      ),
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
                final isCritical = daysInactive > 10;

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
                            isCritical ? 'Critico' : 'A Rischio',
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
    final isCritical = daysInactive > 10;

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
                    isCritical ? 'Critico · ${daysInactive}g inattivo' : 'A Rischio · ${daysInactive}g inattivo',
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
