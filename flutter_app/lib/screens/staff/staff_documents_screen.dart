import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/stat_card.dart';

class StaffDocumentsScreen extends ConsumerStatefulWidget {
  const StaffDocumentsScreen({super.key});

  @override
  ConsumerState<StaffDocumentsScreen> createState() =>
      _StaffDocumentsScreenState();
}

class _StaffDocumentsScreenState extends ConsumerState<StaffDocumentsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _activeFilter; // 'valid', 'expiring', 'expired', 'missing', 'pending' or null

  final Map<String, Map<String, dynamic>> _memberDetails = {};
  bool _loadingDetails = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMemberDetails(List<Map<String, dynamic>> members) async {
    if (_loadingDetails) return;
    _loadingDetails = true;

    final service = ref.read(staffServiceProvider);
    for (final m in members) {
      final id = m['id']?.toString();
      if (id == null || _memberDetails.containsKey(id)) continue;
      try {
        final detail = await service.getMember(id);
        if (mounted) {
          setState(() => _memberDetails[id] = detail);
        }
      } catch (_) {}
    }
    _loadingDetails = false;
  }

  // ── Open certificate detail sheet ──────────────────────
  void _openCertificateSheet(Map<String, dynamic> member) {
    final id = member['id']?.toString();
    if (id == null) return;
    final detail = _memberDetails[id];
    final cert = detail?['medical_certificate'] as Map<String, dynamic>?;
    final name =
        member['name']?.toString() ?? member['username']?.toString() ?? '?';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CertificateDetailSheet(
        memberId: id,
        memberName: name,
        certificate: cert,
        ref: ref,
        onChanged: () {
          // Reload this member's details
          _memberDetails.remove(id);
          final service = ref.read(staffServiceProvider);
          service.getMember(id).then((data) {
            if (mounted) setState(() => _memberDetails[id] = data);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(staffMembersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          _memberDetails.clear();
          ref.invalidate(staffMembersProvider);
        },
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              title: Text(
                'Documenti',
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
                    const Text(
                      'Certificati medici e documentazione dei clienti',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),

                    // ── Stats row ─────────────────────────
                    membersAsync.when(
                      data: (members) {
                        int valid = 0, expiring = 0, expired = 0, missing = 0, pending = 0;
                        for (final m in members) {
                          final id = m['id']?.toString();
                          if (id == null) continue;
                          final detail = _memberDetails[id];
                          if (detail == null) continue;
                          final cert = detail['medical_certificate']
                              as Map<String, dynamic>?;
                          if (cert == null) {
                            missing++;
                          } else if (cert['approval_status']?.toString() == 'pending') {
                            pending++;
                          } else if (cert['approval_status']?.toString() == 'rejected') {
                            missing++; // rejected = needs re-upload
                          } else {
                            switch (cert['status']?.toString()) {
                              case 'expired':
                                expired++;
                              case 'expiring':
                                expiring++;
                              default:
                                valid++;
                            }
                          }
                        }
                        return Column(
                          children: [
                            if (pending > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GestureDetector(
                                  onTap: () => setState(() => _activeFilter =
                                      _activeFilter == 'pending' ? null : 'pending'),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAB308).withValues(alpha: _activeFilter == 'pending' ? 0.2 : 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFEAB308).withValues(alpha: _activeFilter == 'pending' ? 0.6 : 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.hourglass_top_rounded, color: Color(0xFFEAB308), size: 22),
                                        const SizedBox(width: 10),
                                        Text('$pending certificat${pending == 1 ? 'o' : 'i'} da verificare',
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFEAB308))),
                                        const Spacer(),
                                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFEAB308)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                    child: GestureDetector(
                                        onTap: () => setState(() => _activeFilter =
                                            _activeFilter == 'valid'
                                                ? null
                                                : 'valid'),
                                        child: StatCard(
                                            label: 'Validi',
                                            value: '$valid',
                                            icon: Icons.check_circle_rounded,
                                            valueColor: AppColors.success,
                                            highlighted:
                                                _activeFilter == 'valid'))),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: GestureDetector(
                                        onTap: () => setState(() => _activeFilter =
                                            _activeFilter == 'expiring'
                                                ? null
                                                : 'expiring'),
                                        child: StatCard(
                                            label: 'In scadenza',
                                            value: '$expiring',
                                            icon: Icons.warning_rounded,
                                            valueColor: AppColors.warning,
                                            highlighted:
                                                _activeFilter == 'expiring'))),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: GestureDetector(
                                        onTap: () => setState(() => _activeFilter =
                                            _activeFilter == 'expired'
                                                ? null
                                                : 'expired'),
                                        child: StatCard(
                                            label: 'Scaduti',
                                            value: '$expired',
                                            icon: Icons.cancel_rounded,
                                            valueColor: AppColors.danger,
                                            highlighted:
                                                _activeFilter == 'expired'))),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: GestureDetector(
                                        onTap: () => setState(() => _activeFilter =
                                            _activeFilter == 'missing'
                                                ? null
                                                : 'missing'),
                                        child: StatCard(
                                            label: 'Mancanti',
                                            value: '$missing',
                                            icon: Icons.help_outline_rounded,
                                            highlighted:
                                                _activeFilter == 'missing'))),
                              ],
                            ),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),

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
            membersAsync.when(
              data: (members) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _loadMemberDetails(members);
                });

                var displayList = members.where((m) {
                  final id = m['id']?.toString();
                  return id != null && _memberDetails.containsKey(id);
                }).toList();

                // Sort: expired > expiring > missing > valid
                displayList.sort((a, b) {
                  final certA = _memberDetails[a['id']?.toString()]
                      ?['medical_certificate'] as Map<String, dynamic>?;
                  final certB = _memberDetails[b['id']?.toString()]
                      ?['medical_certificate'] as Map<String, dynamic>?;
                  return _certPriority(certA) - _certPriority(certB);
                });

                // Apply status filter from stat card tap
                if (_activeFilter != null) {
                  displayList = displayList.where((m) {
                    final cert = _memberDetails[m['id']?.toString()]
                        ?['medical_certificate'] as Map<String, dynamic>?;
                    final approval = cert?['approval_status']?.toString();
                    if (_activeFilter == 'pending') return approval == 'pending';
                    if (_activeFilter == 'missing') return cert == null || approval == 'rejected';
                    if (cert == null || approval == 'pending' || approval == 'rejected') return false;
                    final status = cert['status']?.toString();
                    if (_activeFilter == 'valid') {
                      return status != 'expired' && status != 'expiring';
                    }
                    return status == _activeFilter;
                  }).toList();
                }

                final loadingCount = members.length - displayList.length;

                if (_searchQuery.length >= 2) {
                  final q = _searchQuery.toLowerCase();
                  displayList = displayList
                      .where((m) =>
                          (m['name']?.toString() ?? '')
                              .toLowerCase()
                              .contains(q) ||
                          (m['username']?.toString() ?? '')
                              .toLowerCase()
                              .contains(q))
                      .toList();
                }

                if (displayList.isEmpty && _memberDetails.isNotEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description_outlined,
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.2)),
                          const SizedBox(height: 12),
                          const Text('Nessun documento trovato',
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
                      (ctx, i) {
                        if (i < displayList.length) {
                          return _buildDocumentTile(displayList[i]);
                        }
                        if (loadingCount > 0 && i == displayList.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'Caricamento $loadingCount clienti...',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textTertiary),
                              ),
                            ),
                          );
                        }
                        return null;
                      },
                      childCount:
                          displayList.length + (loadingCount > 0 ? 1 : 0),
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary)),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                    child: Text('Errore: $e',
                        style: const TextStyle(color: AppColors.danger))),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _approvalBadge(String status) {
    final isPending = status == 'pending';
    final color = isPending ? const Color(0xFFEAB308) : AppColors.danger;
    final label = isPending ? 'Da verificare' : 'Rifiutato';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  int _certPriority(Map<String, dynamic>? cert) {
    if (cert == null) return 3;
    final approval = cert['approval_status']?.toString();
    if (approval == 'pending') return -1; // pending first
    if (approval == 'rejected') return 0;
    switch (cert['status']?.toString()) {
      case 'expired':
        return 1;
      case 'expiring':
        return 2;
      case 'valid':
        return 4;
      default:
        return 4;
    }
  }

  Widget _buildDocumentTile(Map<String, dynamic> member) {
    final name =
        member['name']?.toString() ?? member['username']?.toString() ?? '?';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final id = member['id']?.toString();
    final detail = id != null ? _memberDetails[id] : null;
    final cert = detail?['medical_certificate'] as Map<String, dynamic>?;
    final hasCert = cert != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassCard(
        onTap: () => _openCertificateSheet(member),
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
                  if (hasCert) ...[
                    Text(
                      cert['filename']?.toString() ?? 'Certificato',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    if (cert['expiration_date'] != null)
                      Text(
                        'Scadenza: ${cert['expiration_date']}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textTertiary),
                      ),
                  ] else if (detail == null)
                    const Text('Caricamento...',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textTertiary))
                  else
                    const Text('Nessun certificato',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning)),
                ],
              ),
            ),
            if (hasCert) ...[
              if (cert['approval_status']?.toString() == 'pending')
                _approvalBadge('pending')
              else if (cert['approval_status']?.toString() == 'rejected')
                _approvalBadge('rejected')
              else
                certStatusBadge(cert['status']?.toString() ?? ''),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textTertiary),
            ] else if (detail != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_rounded,
                        size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('Carica',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Shared badge widget ──────────────────────────────────
Widget certStatusBadge(String status) {
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

// ═══════════════════════════════════════════════════════════
//  CERTIFICATE DETAIL SHEET
// ═══════════════════════════════════════════════════════════
class _CertificateDetailSheet extends StatefulWidget {
  final String memberId;
  final String memberName;
  final Map<String, dynamic>? certificate;
  final WidgetRef ref;
  final VoidCallback onChanged;

  const _CertificateDetailSheet({
    required this.memberId,
    required this.memberName,
    required this.certificate,
    required this.ref,
    required this.onChanged,
  });

  @override
  State<_CertificateDetailSheet> createState() =>
      _CertificateDetailSheetState();
}

class _CertificateDetailSheetState extends State<_CertificateDetailSheet> {
  bool _busy = false;
  late Map<String, dynamic>? _cert;

  @override
  void initState() {
    super.initState();
    _cert = widget.certificate != null ? Map<String, dynamic>.from(widget.certificate!) : null;
  }

  String get _fullUrl {
    final fileUrl = _cert?['file_url']?.toString() ?? '';
    if (fileUrl.isEmpty) return '';
    return fileUrl.startsWith('http') ? fileUrl : '${ApiConfig.baseUrl}$fileUrl';
  }

  bool get _isImage {
    final url = _fullUrl.toLowerCase();
    return url.contains('.jpg') ||
        url.contains('.jpeg') ||
        url.contains('.png');
  }

  // ── Open file in browser ────────────────────────────────
  Future<void> _openFile() async {
    if (_fullUrl.isEmpty) return;
    final uri = Uri.parse(_fullUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il file')),
      );
    }
  }

  // ── Upload new certificate ──────────────────────────────
  Future<void> _uploadCertificate() async {
    // Pick file first
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2800,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    // Then pick expiration date
    final expDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Scadenza certificato',
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (expDate == null || !mounted) return;

    final expString =
        '${expDate.year}-${expDate.month.toString().padLeft(2, '0')}-${expDate.day.toString().padLeft(2, '0')}';

    setState(() => _busy = true);

    try {
      final bytes = await picked.readAsBytes();
      final b64 = base64Encode(bytes);
      final ext = picked.path.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final dataUrl = 'data:$mimeType;base64,$b64';
      final filename =
          'certificato_medico_${widget.memberName.toLowerCase().replaceAll(' ', '_')}.$ext';

      final service = widget.ref.read(staffServiceProvider);
      await service.uploadCertificate(
        widget.memberId,
        fileData: dataUrl,
        filename: filename,
        expirationDate: expString,
      );

      widget.onChanged();
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificato caricato')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  // ── Update expiration date ──────────────────────────────
  Future<void> _updateExpiry() async {
    DateTime initial;
    try {
      initial = DateTime.parse(
          _cert?['expiration_date']?.toString() ?? '');
    } catch (_) {
      initial = DateTime.now().add(const Duration(days: 365));
    }

    final newDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Nuova scadenza',
    );
    if (newDate == null || !mounted) return;

    final expString =
        '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}';

    setState(() => _busy = true);
    try {
      final service = widget.ref.read(staffServiceProvider);
      await service.updateCertificateExpiry(widget.memberId, expString);
      widget.onChanged();
      if (mounted) {
        setState(() {
          _busy = false;
          _cert?['expiration_date'] = expString;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scadenza aggiornata')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  // ── Delete certificate ──────────────────────────────────
  Future<void> _deleteCertificate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Elimina Certificato',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Eliminare il certificato di ${widget.memberName}? Questa azione non è reversibile.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final service = widget.ref.read(staffServiceProvider);
      await service.deleteCertificate(widget.memberId);
      widget.onChanged();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificato eliminato')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  Future<void> _approveCertificate() async {
    final certId = _cert?['id'];
    if (certId == null) return;
    setState(() => _busy = true);
    try {
      final service = widget.ref.read(staffServiceProvider);
      await service.approveCertificate(certId as int);
      widget.onChanged();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificato approvato')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  Future<void> _rejectCertificate() async {
    final certId = _cert?['id'];
    if (certId == null) return;

    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rifiuta Certificato',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rifiutare il certificato di ${widget.memberName}?',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Motivo del rifiuto (opzionale)',
                hintStyle: TextStyle(color: AppColors.textTertiary),
              ),
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Rifiuta'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final service = widget.ref.read(staffServiceProvider);
      await service.rejectCertificate(certId as int, reason: reasonCtrl.text.trim());
      widget.onChanged();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificato rifiutato')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cert = _cert;
    final hasCert = cert != null;
    final status = cert?['status']?.toString() ?? '';
    final filename = cert?['filename']?.toString() ?? '';
    final expiration = cert?['expiration_date']?.toString();
    final approvalStatus = cert?['approval_status']?.toString() ?? 'approved';
    final isPending = approvalStatus == 'pending';

    return DraggableScrollableSheet(
      initialChildSize: hasCert ? 0.65 : 0.4,
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
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.memberName,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text('Certificato Medico',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          if (hasCert) ...[
            // ── Certificate info card ─────────────────
            GlassCard(
              child: Column(
                children: [
                  // Preview / icon
                  if (_isImage && _fullUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _fullUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fileIcon(filename),
                      ),
                    )
                  else
                    _fileIcon(filename),
                  const SizedBox(height: 16),
                  // Info rows
                  _infoRow('File', filename),
                  if (isPending) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Stato',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAB308).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFFEAB308)),
                              SizedBox(width: 4),
                              Text('In attesa di verifica',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFEAB308))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (expiration != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Scadenza',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13)),
                        Row(
                          children: [
                            Text(expiration,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13)),
                            if (!isPending) ...[
                              const SizedBox(width: 8),
                              certStatusBadge(status),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Action buttons ────────────────────────
            if (_busy)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.primary),
              ))
            else ...[
              // View / Download
              FilledButton.icon(
                onPressed: _fullUrl.isNotEmpty ? _openFile : null,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Visualizza Documento'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 8),

              // ── Approve / Reject for pending certificates ──
              if (isPending) ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _approveCertificate,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Approva'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _rejectCertificate,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Rifiuta'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _updateExpiry,
                      icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                      label: const Text('Modifica Scadenza'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _uploadCertificate,
                      icon: const Icon(Icons.upload_rounded, size: 18),
                      label: const Text('Sostituisci'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _deleteCertificate,
                icon: const Icon(Icons.delete_rounded,
                    size: 18, color: AppColors.danger),
                label: const Text('Elimina Certificato',
                    style: TextStyle(color: AppColors.danger)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ],
          ] else ...[
            // ── No certificate state ──────────────────
            GlassCard(
              child: Column(
                children: [
                  Icon(Icons.description_outlined,
                      size: 48,
                      color: Colors.white.withValues(alpha: 0.15)),
                  const SizedBox(height: 12),
                  const Text(
                    'Nessun certificato medico',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Carica un certificato medico sportivo per questo cliente',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (_busy)
                    const CircularProgressIndicator(color: AppColors.primary)
                  else
                    FilledButton.icon(
                      onPressed: _uploadCertificate,
                      icon: const Icon(Icons.upload_rounded, size: 18),
                      label: const Text('Carica Certificato'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fileIcon(String filename) {
    final isPdf = filename.toLowerCase().endsWith('.pdf');
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
            size: 40,
            color: isPdf ? Colors.red[400] : AppColors.primary,
          ),
          const SizedBox(height: 8),
          Text(
            filename,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        Flexible(
          child: Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
