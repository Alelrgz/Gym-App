import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/client_service.dart';
import 'consent_dialog.dart';

/// Bottom sheet for managing (viewing/revoking) data consents.
/// Shown from the client's profile/settings screen.
class ConsentManagementSheet extends StatefulWidget {
  final ClientService clientService;

  const ConsentManagementSheet({super.key, required this.clientService});

  @override
  State<ConsentManagementSheet> createState() => _ConsentManagementSheetState();
}

class _ConsentManagementSheetState extends State<ConsentManagementSheet> {
  List<Map<String, dynamic>>? _consents;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConsents();
  }

  Future<void> _loadConsents() async {
    try {
      final consents = await widget.clientService.getConsents();
      if (mounted) setState(() { _consents = consents; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'nutritionist': return 'Nutrizionista';
      case 'trainer': return 'Trainer';
      case 'both': return 'Trainer / Nutrizionista';
      default: return role ?? '';
    }
  }

  String _scopeLabel(String key) {
    for (final s in allConsentScopes) {
      if (s.key == key) return s.label;
    }
    return key;
  }

  Future<void> _revokeConsent(Map<String, dynamic> consent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Revoca consenso'),
        content: Text(
          'Vuoi revocare l\'accesso ai tuoi dati per ${consent['professional_name']}?\n\n'
          'Il professionista non potra\' piu\' visualizzare i dati condivisi. '
          'Questo non annulla eventuali abbonamenti attivi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoca', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.clientService.revokeConsent(consentId: consent['id'] as int);
      _loadConsents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consenso revocato')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Gestione Consensi',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(child: _buildContent(controller)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ScrollController controller) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(child: Text('Errore: $_error', style: const TextStyle(color: AppColors.danger)));
    }
    if (_consents == null || _consents!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            const Text('Nessun consenso attivo',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('I consensi verranno creati quando selezioni un trainer o nutrizionista',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          ],
        ),
      );
    }

    final active = _consents!.where((c) => c['status'] == 'active').toList();
    final revoked = _consents!.where((c) => c['status'] != 'active').toList();

    return ListView(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (active.isNotEmpty) ...[
          _sectionHeader('Attivi'),
          ...active.map((c) => _consentTile(c, isActive: true)),
        ],
        if (revoked.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionHeader('Revocati'),
          ...revoked.map((c) => _consentTile(c, isActive: false)),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: AppColors.textTertiary, letterSpacing: 0.5)),
    );
  }

  Widget _consentTile(Map<String, dynamic> consent, {required bool isActive}) {
    final scopes = (consent['scopes'] as List?)?.cast<String>() ?? [];
    final role = consent['professional_role'] as String?;
    final name = consent['professional_name'] as String? ?? 'Sconosciuto';
    final grantedAt = consent['granted_at'] as String?;

    String dateStr = '';
    if (grantedAt != null) {
      try {
        final dt = DateTime.parse(grantedAt);
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + role + date
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isActive ? AppColors.success : AppColors.danger,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                      Text('${_roleLabel(role)}  ·  $dateStr',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
                if (isActive)
                  TextButton(
                    onPressed: () => _revokeConsent(consent),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Revoca', style: TextStyle(fontSize: 13)),
                  ),
              ],
            ),
            // Scopes
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: scopes.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.textTertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _scopeLabel(s),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isActive ? AppColors.primary : AppColors.textTertiary,
                  ),
                ),
              )).toList(),
            ),
            // Revoked reason
            if (!isActive && consent['revoked_reason'] != null) ...[
              const SizedBox(height: 8),
              Text('Motivo: ${consent['revoked_reason']}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }
}
