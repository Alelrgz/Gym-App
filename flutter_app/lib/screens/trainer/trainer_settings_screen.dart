import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/trainer_profile.dart';
import '../../providers/trainer_provider.dart';
import '../../widgets/glass_card.dart';

class TrainerSettingsScreen extends ConsumerStatefulWidget {
  const TrainerSettingsScreen({super.key});

  @override
  ConsumerState<TrainerSettingsScreen> createState() => _TrainerSettingsScreenState();
}

class _TrainerSettingsScreenState extends ConsumerState<TrainerSettingsScreen> {
  bool _uploadingPic = false;

  // Spotify
  bool _spotifyConnected = false;
  bool _spotifyLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSpotifyStatus();
  }

  Future<void> _checkSpotifyStatus() async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(ApiConfig.spotifyStatus);
      if (mounted) {
        setState(() {
          _spotifyConnected = response.data['connected'] == true && response.data['expired'] != true;
          _spotifyLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _spotifyLoading = false);
    }
  }

  Future<void> _changeProfilePicture() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (picked == null) return;

    setState(() => _uploadingPic = true);
    try {
      final bytes = await picked.readAsBytes();
      final api = ref.read(apiClientProvider);
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes.toList(), filename: picked.name, contentType: DioMediaType.parse('image/jpeg')),
      });
      await api.upload(ApiConfig.profilePicture, formData);
      ref.invalidate(trainerDataProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profilo aggiornata'), backgroundColor: Color(0xFF22C55E)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore upload: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPic = false);
    }
  }

  Future<void> _deleteProfilePicture() async {
    try {
      final api = ref.read(apiClientProvider);
      await api.delete(ApiConfig.profilePicture);
      ref.invalidate(trainerDataProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profilo rimossa'), backgroundColor: Color(0xFF22C55E)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _connectSpotify() async {
    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.spotifyAuthorize}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _disconnectSpotify() async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post(ApiConfig.spotifyDisconnect);
      if (mounted) {
        setState(() => _spotifyConnected = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spotify disconnesso'), backgroundColor: Color(0xFF22C55E)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  void _showPictureOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                title: const Text('Cambia Foto', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () { Navigator.pop(ctx); _changeProfilePicture(); },
              ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: AppColors.danger),
                title: const Text('Rimuovi Foto', style: TextStyle(color: AppColors.danger)),
                onTap: () { Navigator.pop(ctx); _deleteProfilePicture(); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEditProfile() {
    final trainer = ref.read(trainerDataProvider).valueOrNull;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditProfileSheet(
        initialBio: trainer?.bio ?? '',
        initialSpecialties: trainer?.specialties ?? '',
        onSave: (bio, specialties) async {
          final service = ref.read(trainerServiceProvider);
          await service.saveBio(bio);
          await service.saveSpecialties(specialties.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList());
          ref.invalidate(trainerDataProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trainerAsync = ref.watch(trainerDataProvider);
    final authState = ref.watch(authProvider);
    final isDesktop = MediaQuery.of(context).size.width > 1024;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: isDesktop
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Impostazioni', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: _buildContent(trainerAsync, authState),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : _buildContent(trainerAsync, authState),
      ),
    );
  }

  Widget _buildContent(AsyncValue<TrainerProfile> trainerAsync, AuthState authState) {
    final trainer = trainerAsync.valueOrNull;
    final username = authState.user?.username ?? trainer?.name ?? 'Trainer';
    final profilePicUrl = trainer?.profilePicture != null
        ? (trainer!.profilePicture!.startsWith('http')
            ? trainer.profilePicture!
            : '${ApiConfig.baseUrl}${trainer.profilePicture}')
        : null;
    final bio = trainer?.bio;
    final specialties = trainer?.specialties;
    final specialtyList = specialties != null && specialties.isNotEmpty
        ? specialties.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MediaQuery.of(context).size.width <= 1024) ...[
            const Text('Impostazioni', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 20),
          ],

          // ── Profile Preview (as clients see it) ──────────
          Row(
            children: [
              Icon(Icons.visibility_rounded, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text('ANTEPRIMA PROFILO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 1.0)),
              const Spacer(),
              GestureDetector(
                onTap: _openEditProfile,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, size: 13, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text('Modifica', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Client-view profile card
          GlassCard(
            variant: GlassVariant.primary,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // Header with gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.12),
                        Colors.purple.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      GestureDetector(
                        onTap: _uploadingPic ? null : _changeProfilePicture,
                        onLongPress: profilePicUrl != null ? _showPictureOptions : null,
                        child: Stack(
                          children: [
                            Container(
                              width: 88, height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.1),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 3),
                              ),
                              child: _uploadingPic
                                  ? const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)))
                                  : profilePicUrl != null
                                      ? ClipOval(
                                          child: Image.network(profilePicUrl, width: 88, height: 88, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _buildInitial(username)),
                                        )
                                      : _buildInitial(username),
                            ),
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.background, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Trainer', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),

                // Bio section
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (bio != null && bio.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(bio, style: TextStyle(fontSize: 13, color: Colors.grey[400], height: 1.4)),
                        const SizedBox(height: 12),
                      ] else ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _openEditProfile,
                          child: Row(
                            children: [
                              Icon(Icons.add_rounded, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text('Aggiungi una bio...', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Specialties
                      if (specialtyList.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: specialtyList.map((s) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          )).toList(),
                        )
                      else
                        GestureDetector(
                          onTap: _openEditProfile,
                          child: Row(
                            children: [
                              Icon(Icons.add_rounded, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text('Aggiungi specializzazioni...', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),

                      // Mock client action buttons (preview only)
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.grey[500]),
                                  const SizedBox(width: 6),
                                  Text('Messaggio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey[500]),
                                  const SizedBox(width: 6),
                                  Text('Prenota', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                                ],
                              ),
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
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text('Cosi ti vedono i tuoi clienti', style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic)),
          ),
          const SizedBox(height: 28),

          // ── Disponibilita ────────────────────────────
          _sectionLabel('DISPONIBILITA'),
          const SizedBox(height: 8),
          GlassCard(
            onTap: _showAvailabilityModal,
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFF3B82F6)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Disponibilita 1-on-1', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text('Orari settimanali per le prenotazioni', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey[600]),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Spotify ──────────────────────────────────
          _sectionLabel('INTEGRAZIONI'),
          const SizedBox(height: 8),
          GlassCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.music_note_rounded, size: 20, color: Color(0xFF1DB954)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Spotify', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          Text('Musica durante i corsi', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    if (_spotifyLoading)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1DB954)))
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _spotifyConnected ? const Color(0xFF1DB954).withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _spotifyConnected ? const Color(0xFF1DB954) : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _spotifyConnected ? 'Connesso' : 'Non connesso',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _spotifyConnected ? const Color(0xFF1DB954) : Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: _spotifyConnected
                      ? OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.danger.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _disconnectSpotify,
                          child: const Text('Disconnetti Spotify', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.danger)),
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1DB954),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _connectSpotify,
                          icon: const Icon(Icons.link_rounded, size: 18, color: Colors.white),
                          label: const Text('Connetti Spotify Premium', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                ),
                if (!_spotifyConnected && !_spotifyLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Spotify Premium richiesto', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Logout ───────────────────────────────────
          GlassCard(
            onTap: () => ref.read(authProvider.notifier).logout(),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.logout_rounded, size: 20, color: AppColors.danger),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Esci', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.danger)),
                      Text('Disconnetti il tuo account', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey[600]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitial(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primary),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 1.0));
  }

  // ── Availability Modal ──────────────────────────
  final List<_DaySlot> _availability = List.generate(7, (i) => _DaySlot(dayIndex: i));
  final _rateCtrl = TextEditingController();

  void _showAvailabilityModal() {
    const dayNames = ['Lunedi', 'Martedi', 'Mercoledi', 'Giovedi', 'Venerdi', 'Sabato', 'Domenica'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (ctx, scrollCtrl) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: ListView(
              controller: scrollCtrl,
              children: [
                const Text('Disponibilita Settimanale', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                ...List.generate(7, (i) {
                  final slot = _availability[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24, height: 24,
                            child: Checkbox(
                              value: slot.enabled,
                              activeColor: AppColors.primary,
                              onChanged: (v) => setModalState(() => slot.enabled = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: Text(dayNames[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: slot.enabled ? AppColors.textPrimary : Colors.grey[600])),
                          ),
                          if (slot.enabled) ...[
                            Expanded(
                              child: Row(
                                children: [
                                  _TimeField(value: slot.start, onChanged: (v) => setModalState(() => slot.start = v)),
                                  Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('-', style: TextStyle(color: Colors.grey[500]))),
                                  _TimeField(value: slot.end, onChanged: (v) => setModalState(() => slot.end = v)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: _rateCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Tariffa Oraria Sessione (\u20ac)',
                    hintText: 'es. 50.00',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    hintStyle: TextStyle(color: Colors.grey[700]),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      try {
                        await ref.read(trainerServiceProvider).saveAvailability({
                          'slots': _availability.map((s) => <String, dynamic>{
                            'day_of_week': s.dayIndex,
                            'is_available': s.enabled,
                            'start_time': s.start,
                            'end_time': s.end,
                          }).toList(),
                          'session_rate': double.tryParse(_rateCtrl.text) ?? 0,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Disponibilita salvata'), backgroundColor: Color(0xFF22C55E)),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
                        }
                      }
                    },
                    child: const Text('Salva Disponibilita', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  EDIT PROFILE SHEET
// ═══════════════════════════════════════════════════════════

class _EditProfileSheet extends StatefulWidget {
  final String initialBio;
  final String initialSpecialties;
  final Future<void> Function(String bio, String specialties) onSave;

  const _EditProfileSheet({
    required this.initialBio,
    required this.initialSpecialties,
    required this.onSave,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _bioCtrl;
  bool _saving = false;

  final _allSpecialties = [
    'Dimagrimento', 'Massa Muscolare', 'Allenamento Forza',
    'HIIT', 'Yoga', 'Nutrizione', 'Calisthenics', 'Bodybuilding',
    'Cardio', 'Pilates', 'Riabilitazione',
  ];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _bioCtrl = TextEditingController(text: widget.initialBio);
    if (widget.initialSpecialties.isNotEmpty) {
      _selected.addAll(widget.initialSpecialties.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty));
    }
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Modifica Profilo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text('Queste informazioni saranno visibili ai tuoi clienti', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 20),

            // Bio
            Text('Bio', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[400])),
            const SizedBox(height: 8),
            TextField(
              controller: _bioCtrl,
              maxLines: 4,
              maxLength: 300,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Racconta ai clienti di te...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[700]),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
                counterStyle: TextStyle(fontSize: 10, color: Colors.grey[700]),
              ),
            ),
            const SizedBox(height: 16),

            // Specialties
            Text('Specializzazioni', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[400])),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allSpecialties.map((s) {
                final selected = _selected.contains(s);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) _selected.remove(s); else _selected.add(s);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.2), Colors.deepOrange.withValues(alpha: 0.1)])
                          : null,
                      color: selected ? null : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? AppColors.primary.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selected) ...[
                          const Icon(Icons.check_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                        ],
                        Text(s, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : Colors.grey[500])),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saving ? null : () async {
                  setState(() => _saving = true);
                  try {
                    await widget.onSave(_bioCtrl.text, _selected.join(', '));
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profilo aggiornato'), backgroundColor: Color(0xFF22C55E)),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
                    }
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Salva Profilo', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════

class _DaySlot {
  final int dayIndex;
  bool enabled;
  String start;
  String end;
  _DaySlot({required this.dayIndex, this.enabled = false, this.start = '09:00', this.end = '17:00'});
}

class _TimeField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _TimeField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 36,
      child: TextField(
        controller: TextEditingController(text: value),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
