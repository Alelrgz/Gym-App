import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/staff_provider.dart';
import '../../services/staff_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/stat_card.dart';

class StaffDashboardScreen extends ConsumerStatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  ConsumerState<StaffDashboardScreen> createState() =>
      _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends ConsumerState<StaffDashboardScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _viewMemberProfile(Map<String, dynamic> member) async {
    final memberId = member['id']?.toString() ?? '';
    if (memberId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _MemberProfileSheet(
        memberId: memberId,
        ref: ref,
        parentContext: context,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(staffMembersProvider);
    final checkinsAsync = ref.watch(staffCheckinsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.invalidate(staffMembersProvider);
          ref.invalidate(staffCheckinsProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              title: const Text(
                'Utenti',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded,
                      color: AppColors.textSecondary),
                  onPressed: () => _showQrScanner(),
                  tooltip: 'Scan QR',
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton.icon(
                    onPressed: () => _openOnboardingWizard(),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Registra'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Stats ─────────────────────────────
                    membersAsync.when(
                      data: (members) {
                        final total = members.length;
                        return Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                label: 'Clienti totali',
                                value: '$total',
                                icon: Icons.people_rounded,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: StatCard(
                                label: 'Check-in oggi',
                                value: checkinsAsync.when(
                                  data: (d) => '${d['count'] ?? 0}',
                                  loading: () => '...',
                                  error: (_, __) => '-',
                                ),
                                icon: Icons.login_rounded,
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => Row(
                        children: [
                          Expanded(
                              child: StatCard(
                                  label: 'Clienti totali',
                                  value: '...',
                                  icon: Icons.people_rounded)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: StatCard(
                                  label: 'Check-in oggi',
                                  value: '...',
                                  icon: Icons.login_rounded)),
                        ],
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 16),

                    // ── Search ────────────────────────────
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Cerca clienti...',
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
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Members List ──────────────────────────────
            membersAsync.when(
              data: (members) {
                var filtered = members;
                if (_searchQuery.length >= 2) {
                  final q = _searchQuery.toLowerCase();
                  filtered = members
                      .where((m) =>
                          (m['name']?.toString() ?? '')
                              .toLowerCase()
                              .contains(q) ||
                          (m['username']?.toString() ?? '')
                              .toLowerCase()
                              .contains(q) ||
                          (m['email']?.toString() ?? '')
                              .toLowerCase()
                              .contains(q))
                      .toList();
                }
                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline,
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.2)),
                          const SizedBox(height: 12),
                          const Text('Nessun cliente trovato',
                              style:
                                  TextStyle(color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildMemberTile(filtered[i]),
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 36),
                      const SizedBox(height: 8),
                      Text('Errore: $e',
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref.invalidate(staffMembersProvider),
                        child: const Text('Riprova'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member) {
    final name =
        member['name']?.toString() ?? member['username']?.toString() ?? '?';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final email = member['email']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassCard(
        onTap: () => _viewMemberProfile(member),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.6),
                ]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(initial,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.white)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  if (email != null && email.isNotEmpty)
                    Text(email,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
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

  void _showQrScanner() {
    showDialog(
      context: context,
      builder: (ctx) => _QrScannerDialog(ref: ref, parentContext: context),
    );
  }

  void _openOnboardingWizard() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _OnboardingWizard(
        ref: ref,
        parentContext: context,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  MEMBER PROFILE SHEET
// ═══════════════════════════════════════════════════════════
class _MemberProfileSheet extends StatefulWidget {
  final String memberId;
  final WidgetRef ref;
  final BuildContext parentContext;

  const _MemberProfileSheet({
    required this.memberId,
    required this.ref,
    required this.parentContext,
  });

  @override
  State<_MemberProfileSheet> createState() => _MemberProfileSheetState();
}

class _MemberProfileSheetState extends State<_MemberProfileSheet> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final service = widget.ref.read(staffServiceProvider);
      final data = await service.getMember(widget.memberId);
      if (mounted) setState(() { _profile = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _checkIn() async {
    try {
      final service = widget.ref.read(staffServiceProvider);
      final name = _profile?['name']?.toString() ?? '';
      await service.checkIn(widget.memberId);
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(content: Text('$name check-in effettuato')),
        );
        widget.ref.invalidate(staffCheckinsProvider);
        _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reimposta Password',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Generare una nuova password temporanea per questo utente?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final service = widget.ref.read(staffServiceProvider);
      final result = await service.resetMemberPassword(widget.memberId);
      if (mounted) {
        final tempPw = result['temporary_password']?.toString() ?? '';
        _showTempPasswordDialog(tempPw);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  void _showTempPasswordDialog(String password) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            SizedBox(width: 8),
            Text('Password Reimpostata',
                style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Password temporanea:',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      password,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: AppColors.textSecondary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: password));
                      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                        const SnackBar(content: Text('Copiato!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Il cliente deve cambiare questa password al primo accesso.',
              style: TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeUsername() async {
    final controller = TextEditingController();
    final newUsername = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cambia Username',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nuovo username'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newUsername == null || newUsername.isEmpty) return;

    try {
      final service = widget.ref.read(staffServiceProvider);
      await service.changeMemberUsername(widget.memberId, newUsername);
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          const SnackBar(content: Text('Username aggiornato')),
        );
        widget.ref.invalidate(staffMembersProvider);
        _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  void _openPlanSelector() async {
    try {
      final service = widget.ref.read(staffServiceProvider);
      final plans = await service.getSubscriptionPlans();
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => _PlanSelectorSheet(
          plans: plans,
          memberId: widget.memberId,
          hasSubscription: _profile?['subscription'] != null,
          service: service,
          onSuccess: () {
            if (mounted) _loadProfile();
          },
          parentContext: widget.parentContext,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        if (_loading) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (_error != null) {
          return Center(
              child: Text('Errore: $_error',
                  style: const TextStyle(color: AppColors.danger)));
        }
        final p = _profile!;
        final name = p['name']?.toString() ?? '';
        final email = p['email']?.toString() ?? '';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
        final status = p['status']?.toString() ?? 'inactive';
        final isActive = status == 'active';
        final sub = p['subscription'] as Map<String, dynamic>?;
        final medCert = p['medical_certificate'] as Map<String, dynamic>?;
        final checkedInToday = p['checked_in_today'] == true;

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),

            // ── Header ───────────────────────────────
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.6),
                    ]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                      child: Text(initial,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      if (email.isNotEmpty)
                        Text(email,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isActive ? AppColors.success : AppColors.danger)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'Attivo' : 'Inattivo',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive ? AppColors.success : AppColors.danger),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Info Card ────────────────────────────
            GlassCard(
              child: Column(
                children: [
                  _infoRow('Membro dal', p['member_since']?.toString() ?? '-'),
                  _infoRow('Trainer', p['trainer_name']?.toString() ?? 'Non assegnato'),
                  _infoRow('Ultimo Check-in',
                      p['last_checkin'] != null
                          ? _formatDateTime(p['last_checkin'].toString())
                          : 'Mai'),
                  _infoRow('Check-in Totali', '${p['total_checkins'] ?? 0}'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Subscription Card ────────────────────
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.card_membership,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text('Abbonamento',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const Spacer(),
                      TextButton(
                        onPressed: _openPlanSelector,
                        child: const Text('Gestisci',
                            style: TextStyle(color: AppColors.primary, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow('Piano', sub?['plan']?.toString() ?? 'Nessuno'),
                  _infoRow('Stato', sub?['status']?.toString() ?? '-'),
                  _infoRow('Scadenza', sub?['expires']?.toString() ?? '-'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Medical Certificate ──────────────────
            if (medCert != null)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const Text('Certificato Medico',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        const Spacer(),
                        _certStatusBadge(medCert['status']?.toString() ?? ''),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _infoRow('File', medCert['filename']?.toString() ?? '-'),
                    _infoRow('Scadenza',
                        medCert['expiration_date']?.toString() ?? '-'),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // ── Actions ──────────────────────────────
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: checkedInToday ? null : _checkIn,
                    icon: Icon(
                        checkedInToday
                            ? Icons.check_circle
                            : Icons.login_rounded,
                        size: 18),
                    label: Text(checkedInToday ? 'Già fatto' : 'Check In'),
                    style: FilledButton.styleFrom(
                      backgroundColor: checkedInToday
                          ? Colors.grey[700]
                          : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetPassword,
                    icon: const Icon(Icons.lock_reset, size: 18),
                    label: const Text('Reimposta Password'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _changeUsername,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Cambia Username'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Flexible(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  Widget _certStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'valid':
        color = AppColors.success;
        label = 'Valido';
      case 'expiring':
        color = AppColors.warning;
        label = 'In scadenza';
      case 'expired':
        color = AppColors.danger;
        label = 'Scaduto';
      default:
        color = AppColors.textTertiary;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  QR SCANNER DIALOG
// ═══════════════════════════════════════════════════════════
class _QrScannerDialog extends StatefulWidget {
  final WidgetRef ref;
  final BuildContext parentContext;

  const _QrScannerDialog({required this.ref, required this.parentContext});

  @override
  State<_QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<_QrScannerDialog> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  String _statusText = 'In attesa della scansione...';
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScanned(String code) async {
    if (_processing || code.trim().isEmpty) return;
    setState(() { _processing = true; _statusText = 'Elaborazione...'; });

    try {
      final service = widget.ref.read(staffServiceProvider);
      final members = await service.getMembers();
      final member = members.firstWhere(
        (m) => m['id']?.toString() == code || m['username']?.toString() == code,
        orElse: () => <String, dynamic>{},
      );
      if (member.isEmpty) {
        setState(() { _statusText = 'Membro non trovato'; _processing = false; });
        return;
      }
      await service.checkIn(member['id'].toString());
      if (mounted) {
        setState(() => _statusText = '${member['name']} - Check-in effettuato!');
        widget.ref.invalidate(staffCheckinsProvider);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _statusText = 'Errore: $e'; _processing = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Scanner QR',
          style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _processing ? Icons.hourglass_top : Icons.qr_code_scanner,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(_statusText,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          const Text(
            'Scansiona il QR code del membro con il lettore',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
          // Hidden text field to capture scanner input
          SizedBox(
            width: 0, height: 0,
            child: TextField(
              controller: _inputController,
              focusNode: _focusNode,
              onSubmitted: _onScanned,
              autofocus: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Chiudi'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ONBOARDING WIZARD
// ═══════════════════════════════════════════════════════════
class _OnboardingWizard extends StatefulWidget {
  final WidgetRef ref;
  final BuildContext parentContext;

  const _OnboardingWizard({required this.ref, required this.parentContext});

  @override
  State<_OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<_OnboardingWizard> {
  int _step = 0;
  bool _submitting = false;

  // Step 1: Client Info
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _dobController = TextEditingController();

  // Step 2: Plan selection
  List<Map<String, dynamic>> _plans = [];
  String? _selectedPlanId;

  // Step 3: Payment
  String _paymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final service = widget.ref.read(staffServiceProvider);
      final plans = await service.getSubscriptionPlans();
      if (mounted) setState(() => _plans = plans);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final service = widget.ref.read(staffServiceProvider);
      final result = await service.onboardClient({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'date_of_birth': _dobController.text.trim(),
        if (_selectedPlanId != null) 'plan_id': _selectedPlanId,
        'payment_method': _paymentMethod,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.ref.invalidate(staffMembersProvider);
        _showSuccessDialog(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    final tempPw = result['temporary_password']?.toString() ?? '';
    final name = result['name']?.toString() ?? '';
    final username = result['username']?.toString() ?? '';

    showDialog(
      context: widget.parentContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 28),
            SizedBox(width: 8),
            Flexible(
              child: Text('Cliente Registrato!',
                  style: TextStyle(color: AppColors.textPrimary)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Credenziali del cliente:',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            _credentialRow('Nome', name),
            _credentialRow('Username', username),
            const SizedBox(height: 8),
            const Text('Password Temporanea:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      tempPw,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: AppColors.textSecondary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tempPw));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Copiato!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Il cliente deve cambiare questa password al primo accesso.',
              style: TextStyle(fontSize: 11, color: AppColors.warning),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _credentialRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // ── Header ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Registra Nuovo Cliente',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress
                Row(
                  children: List.generate(3, (i) {
                    return Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: i <= _step
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  ['Informazioni', 'Piano', 'Riepilogo'][_step],
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Content ────────────────────────────────
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                if (_step == 0) _buildStep1(),
                if (_step == 1) _buildStep2(),
                if (_step == 2) _buildStep3(),
              ],
            ),
          ),

          // ── Navigation ─────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Indietro'),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting
                        ? null
                        : _step < 2
                            ? () {
                                if (_step == 0) {
                                  if (_nameController.text.trim().isEmpty ||
                                      _phoneController.text.trim().isEmpty ||
                                      _usernameController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(widget.parentContext)
                                        .showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Compila i campi obbligatori')),
                                    );
                                    return;
                                  }
                                }
                                setState(() => _step++);
                              }
                            : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_step < 2 ? 'Avanti' : 'Completa Registrazione'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nome Completo *',
            prefixIcon: Icon(Icons.person, size: 20),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Numero di Telefono *',
            prefixIcon: Icon(Icons.phone, size: 20),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email (opzionale)',
            prefixIcon: Icon(Icons.email, size: 20),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dobController,
          decoration: const InputDecoration(
            labelText: 'Data di Nascita',
            prefixIcon: Icon(Icons.cake, size: 20),
            hintText: 'AAAA-MM-GG',
          ),
          keyboardType: TextInputType.datetime,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime(2000),
              firstDate: DateTime(1920),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              _dobController.text =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'Username *',
            prefixIcon: Icon(Icons.alternate_email, size: 20),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Una password temporanea verrà generata automaticamente.',
          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Seleziona Piano di Abbonamento',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        if (_plans.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Nessun piano disponibile',
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ),
          )
        else
          ..._plans.map((plan) {
            final isSelected = _selectedPlanId == plan['id']?.toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                onTap: () => setState(
                    () => _selectedPlanId = plan['id']?.toString()),
                variant: isSelected ? GlassVariant.accent : GlassVariant.base,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textTertiary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(plan['name']?.toString() ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          if (plan['description'] != null)
                            Text(plan['description'].toString(),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text(
                      '€${plan['price'] ?? '0'}/${plan['billing_interval'] == 'year' ? 'anno' : 'mese'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () {
                setState(() { _selectedPlanId = null; _step++; });
              },
            child: const Text('Salta - registra senza abbonamento',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    final planName = _selectedPlanId != null
        ? _plans
            .firstWhere(
              (p) => p['id']?.toString() == _selectedPlanId,
              orElse: () => {'name': '-'},
            )['name']
            ?.toString()
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Riepilogo',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            children: [
              _summaryRow('Cliente', _nameController.text),
              _summaryRow('Username', _usernameController.text),
              _summaryRow('Telefono', _phoneController.text),
              if (_emailController.text.isNotEmpty)
                _summaryRow('Email', _emailController.text),
              _summaryRow('Piano', planName ?? 'Nessuno'),
            ],
          ),
        ),
        if (_selectedPlanId != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Metodo di Pagamento',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _paymentOption('cash', Icons.payments_rounded, 'Contanti'),
              const SizedBox(width: 8),
              _paymentOption('terminal', Icons.contactless_rounded, 'POS'),
            ],
          ),
        ],
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _paymentOption(String method, IconData icon, String label) {
    final isSelected = _paymentMethod == method;
    return Expanded(
      child: GlassCard(
        onTap: () => setState(() => _paymentMethod = method),
        variant: isSelected ? GlassVariant.accent : GlassVariant.base,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(icon,
                size: 28,
                color:
                    isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  PLAN SELECTOR WITH PRORATION & PAYMENT
// ═══════════════════════════════════════════════════════════
class _PlanSelectorSheet extends StatefulWidget {
  final List<Map<String, dynamic>> plans;
  final String memberId;
  final bool hasSubscription;
  final StaffService service;
  final VoidCallback onSuccess;
  final BuildContext parentContext;

  const _PlanSelectorSheet({
    required this.plans,
    required this.memberId,
    required this.hasSubscription,
    required this.service,
    required this.onSuccess,
    required this.parentContext,
  });

  @override
  State<_PlanSelectorSheet> createState() => _PlanSelectorSheetState();
}

class _PlanSelectorSheetState extends State<_PlanSelectorSheet> {
  // null = plan list, non-null = confirmation step
  Map<String, dynamic>? _selectedPlan;
  Map<String, dynamic>? _preview;
  String _paymentMethod = 'cash';
  bool _busy = false;

  // POS terminal state
  String? _posState; // null, 'processing', 'success', 'error'
  String? _paymentIntentId;
  bool _isTestMode = false;
  String? _posError;

  @override
  void dispose() {
    _paymentIntentId = null; // stop polling
    super.dispose();
  }

  Future<void> _selectPlan(Map<String, dynamic> plan) async {
    if (!widget.hasSubscription) {
      // No existing sub — assign directly
      setState(() => _busy = true);
      try {
        await widget.service.subscribeClient(
          widget.memberId,
          plan['id'].toString(),
        );
        widget.onSuccess();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(widget.parentContext).showSnackBar(
            SnackBar(content: Text('Piano ${plan['name']} assegnato')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _busy = false);
          ScaffoldMessenger.of(widget.parentContext).showSnackBar(
            SnackBar(content: Text('Errore: $e')),
          );
        }
      }
      return;
    }

    // Has existing sub — fetch proration preview
    setState(() => _busy = true);
    try {
      final preview = await widget.service.previewSubscriptionChange(
        widget.memberId,
        plan['id'].toString(),
      );
      if (mounted) {
        setState(() {
          _selectedPlan = plan;
          _preview = preview;
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  Future<void> _confirmChange() async {
    final amountDue = (_preview?['amount_due'] as num?)?.toDouble() ?? 0;

    if (_paymentMethod == 'pos' && amountDue > 0) {
      // Start terminal payment flow
      await _startTerminalPayment(amountDue);
      return;
    }

    // Cash or no amount — proceed directly
    await _finalizeChange();
  }

  Future<void> _startTerminalPayment(double amount) async {
    setState(() {
      _posState = 'processing';
      _posError = null;
      _busy = true;
    });

    try {
      final result = await widget.service.processTerminalPayment(
        amount: amount,
        description:
            'Cambio piano: ${_preview?['old_plan_name'] ?? '-'} → ${_selectedPlan!['name']}',
        metadata: {
          'client_id': widget.memberId,
          'plan_id': _selectedPlan!['id'].toString(),
          'type': 'subscription_change',
        },
      );

      final intentId = result['payment_intent_id']?.toString();
      final testMode = result['is_test_mode'] == true;

      if (intentId == null) throw Exception('No payment intent returned');

      if (mounted) {
        setState(() {
          _paymentIntentId = intentId;
          _isTestMode = testMode;
          _busy = false;
        });
        _pollPaymentStatus(intentId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _posState = 'error';
          _posError = e.toString();
          _busy = false;
        });
      }
    }
  }

  Future<void> _pollPaymentStatus(String intentId) async {
    while (mounted && _paymentIntentId == intentId) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || _paymentIntentId != intentId) return;

      try {
        final result =
            await widget.service.getTerminalPaymentStatus(intentId);
        final status = result['status']?.toString();

        if (!mounted || _paymentIntentId != intentId) return;

        if (status == 'succeeded') {
          setState(() => _posState = 'success');
          await _finalizeChange(stripePaymentIntentId: intentId);
          return;
        } else if (status == 'canceled') {
          setState(() {
            _posState = 'error';
            _posError = 'Pagamento annullato';
          });
          return;
        }
        // requires_payment_method / requires_confirmation → keep polling
      } catch (e) {
        if (mounted && _paymentIntentId == intentId) {
          setState(() {
            _posState = 'error';
            _posError = e.toString();
          });
          return;
        }
      }
    }
  }

  Future<void> _simulateCardTap() async {
    try {
      await widget.service.simulateTerminalPayment();
    } catch (_) {}
  }

  Future<void> _cancelPosPayment() async {
    final intentId = _paymentIntentId;
    setState(() {
      _paymentIntentId = null;
      _posState = null;
      _posError = null;
      _busy = false;
    });
    if (intentId != null) {
      try {
        await widget.service.cancelTerminalPayment(intentId);
      } catch (_) {}
    }
  }

  Future<void> _finalizeChange({String? stripePaymentIntentId}) async {
    setState(() => _busy = true);
    try {
      await widget.service.changeSubscription(
        widget.memberId,
        _selectedPlan!['id'].toString(),
        _paymentMethod,
      );
      widget.onSuccess();
      if (mounted) {
        Navigator.pop(context);
        final amountPaid = _preview?['amount_due'] ?? 0;
        final methodLabel = _paymentMethod == 'pos' ? 'POS' : 'Contanti';
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text(
              'Piano ${_selectedPlan!['name']} assegnato'
              '${(amountPaid as num) > 0 ? ' — €${(amountPaid as num).toStringAsFixed(2)} ($methodLabel)' : ''}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _posState != null
          ? _buildPosProcessing()
          : _selectedPlan != null
              ? _buildConfirmation()
              : _buildPlanList(),
    );
  }

  Widget _buildPlanList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seleziona Piano di Abbonamento',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (widget.plans.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Nessun piano disponibile.\nI piani vengono creati dal proprietario.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ),
          )
        else
          ...widget.plans.map((plan) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  onTap: () => _selectPlan(plan),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan['name']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (plan['description'] != null)
                              Text(
                                plan['description'].toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '€${plan['price']?.toString() ?? '0'}/${plan['billing_interval'] == 'year' ? 'anno' : 'mese'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildConfirmation() {
    final preview = _preview!;
    final oldName = preview['old_plan_name']?.toString() ?? '-';
    final newName = preview['new_plan_name']?.toString() ?? '';
    final newPrice = (preview['new_plan_price'] as num?)?.toDouble() ?? 0;
    final credit = (preview['credit'] as num?)?.toDouble() ?? 0;
    final amountDue = (preview['amount_due'] as num?)?.toDouble() ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() {
                _selectedPlan = null;
                _preview = null;
              }),
              child: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textSecondary, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'Conferma Cambio Piano',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Proration summary
        GlassCard(
          child: Column(
            children: [
              _summaryRow('Piano attuale', oldName),
              const Divider(color: AppColors.borderLight, height: 16),
              _summaryRow('Nuovo piano', newName),
              const Divider(color: AppColors.borderLight, height: 16),
              _summaryRow('Prezzo nuovo piano', '€${newPrice.toStringAsFixed(2)}'),
              if (credit > 0) ...[
                const Divider(color: AppColors.borderLight, height: 16),
                _summaryRow(
                  'Credito residuo',
                  '-€${credit.toStringAsFixed(2)}',
                  valueColor: AppColors.success,
                ),
              ],
              const Divider(color: AppColors.borderLight, height: 16),
              _summaryRow(
                'Importo dovuto',
                '€${amountDue.toStringAsFixed(2)}',
                valueColor: AppColors.primary,
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Payment method selector (only if amount > 0)
        if (amountDue > 0) ...[
          const Text(
            'Metodo di pagamento',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _paymentOption('cash', Icons.payments_rounded, 'Contanti'),
              const SizedBox(width: 10),
              _paymentOption('pos', Icons.credit_card_rounded, 'POS'),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Confirm button
        if (_busy)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else
          FilledButton(
            onPressed: _confirmChange,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(
              amountDue > 0
                  ? 'Conferma e Registra Pagamento'
                  : 'Conferma Cambio Piano',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),

        const SizedBox(height: 8),
        if (amountDue > 0)
          Center(
            child: Text(
              'Il cliente riceverà una notifica e un\'email di conferma',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPosProcessing() {
    final amountDue = (_preview?['amount_due'] as num?)?.toDouble() ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        if (_posState == 'processing') ...[
          // Waiting for card tap
          const Icon(Icons.contactless_rounded,
              size: 64, color: AppColors.primary),
          const SizedBox(height: 20),
          const Text(
            'In attesa del pagamento...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Avvicina la carta al POS — €${amountDue.toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 24),
          if (_isTestMode) ...[
            OutlinedButton.icon(
              onPressed: _simulateCardTap,
              icon: const Icon(Icons.science_rounded, size: 18),
              label: const Text('Simula Carta (Test)'),
            ),
            const SizedBox(height: 8),
          ],
          TextButton(
            onPressed: _cancelPosPayment,
            child: const Text('Annulla',
                style: TextStyle(color: AppColors.danger)),
          ),
        ] else if (_posState == 'success') ...[
          // Success
          const Icon(Icons.check_circle_rounded,
              size: 64, color: AppColors.success),
          const SizedBox(height: 16),
          const Text(
            'Pagamento completato!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 8),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          else
            const Text(
              'Aggiornamento abbonamento...',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
        ] else if (_posState == 'error') ...[
          // Error
          const Icon(Icons.error_rounded, size: 64, color: AppColors.danger),
          const SizedBox(height: 16),
          const Text(
            'Pagamento non riuscito',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
          if (_posError != null) ...[
            const SizedBox(height: 8),
            Text(
              _posError!,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelPosPayment,
                  child: const Text('Annulla'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final amount = amountDue;
                    setState(() {
                      _posState = null;
                      _posError = null;
                      _paymentIntentId = null;
                    });
                    _startTerminalPayment(amount);
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: const Text('Riprova'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _summaryRow(String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentOption(String method, IconData icon, String label) {
    final isSelected = _paymentMethod == method;
    return Expanded(
      child: GlassCard(
        onTap: () => setState(() => _paymentMethod = method),
        variant: isSelected ? GlassVariant.accent : GlassVariant.base,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(icon,
                size: 26,
                color:
                    isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
