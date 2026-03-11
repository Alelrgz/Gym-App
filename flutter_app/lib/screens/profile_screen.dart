import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/client_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/dashboard_sheets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Avatar
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: user?.profilePicture != null
                    ? ClipOval(
                        child: Image.network(
                          user!.profilePicture!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, s) => const Icon(
                            Icons.person,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : const Icon(Icons.person, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text(
                user?.username ?? '',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (user?.email != null)
                Text(
                  user!.email!,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              const SizedBox(height: 32),

              // Settings
              GlassCard(
                child: Column(
                  children: [
                    _SettingsItem(
                      icon: Icons.person_outline,
                      label: 'Modifica Profilo',
                      onTap: () => _showEditProfile(context, ref),
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    _SettingsItem(
                      icon: Icons.lock_outline,
                      label: 'Privacy',
                      onTap: () => _showPrivacySettings(context, ref),
                    ),
                    const Divider(color: AppColors.border, height: 1),
                    _SettingsItem(
                      icon: Icons.notifications_none,
                      label: 'Notifiche',
                      onTap: () => showNotificationsSheet(context, ref),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Logout
              GlassCard(
                onTap: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Esci',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfile(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditProfileSheet(ref: ref),
    );
  }

  void _showPrivacySettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PrivacySheet(ref: ref),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// EDIT PROFILE SHEET
// ════════════════════════════════════════════════════════════════

class _EditProfileSheet extends StatefulWidget {
  final WidgetRef ref;
  const _EditProfileSheet({required this.ref});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _passwordCtrl;
  bool _saving = false;
  bool _uploadingPic = false;

  @override
  void initState() {
    super.initState();
    final user = widget.ref.read(authProvider).user;
    _nameCtrl = TextEditingController(text: user?.username ?? '');
    _emailCtrl = TextEditingController(text: user?.email ?? '');
    _passwordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (name.isEmpty) {
      showSnack(context, 'Il nome non può essere vuoto');
      return;
    }

    setState(() => _saving = true);
    try {
      final service = widget.ref.read(clientServiceProvider);
      final data = <String, dynamic>{
        'name': name,
        'email': email,
      };
      if (password.isNotEmpty) data['password'] = password;
      await service.updateProfile(data);
      if (mounted) {
        showSnack(context, 'Profilo aggiornato');
        Navigator.pop(context);
        // Refresh client data
        widget.ref.invalidate(clientDataProvider);
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Errore: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeProfilePicture() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (picked == null) return;

    setState(() => _uploadingPic = true);
    try {
      final bytes = await picked.readAsBytes();
      final service = widget.ref.read(clientServiceProvider);
      await service.uploadProfilePicture(bytes.toList(), picked.name);
      if (mounted) {
        showSnack(context, 'Foto profilo aggiornata');
        widget.ref.invalidate(clientDataProvider);
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Errore upload: $e');
    } finally {
      if (mounted) setState(() => _uploadingPic = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.ref.watch(authProvider).user;
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Modifica Profilo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 24),

            // Profile picture
            GestureDetector(
              onTap: _uploadingPic ? null : _changeProfilePicture,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: _uploadingPic
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : user?.profilePicture != null
                            ? ClipOval(
                                child: Image.network(user!.profilePicture!, width: 88, height: 88, fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(Icons.person, size: 44, color: AppColors.primary)),
                              )
                            : const Icon(Icons.person, size: 44, color: AppColors.primary),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Cambia foto', style: TextStyle(fontSize: 12, color: AppColors.primary)),
            const SizedBox(height: 20),

            // Name
            _buildField('Nome Completo', _nameCtrl, Icons.person_outline),
            const SizedBox(height: 12),
            // Email
            _buildField('Email', _emailCtrl, Icons.email_outlined,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            // Password
            _buildField('Nuova Password (opzionale)', _passwordCtrl, Icons.lock_outline,
                obscure: true),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('SALVA MODIFICHE', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon,
      {bool obscure = false, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 20),
        filled: true,
        fillColor: AppColors.elevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PRIVACY SETTINGS SHEET
// ════════════════════════════════════════════════════════════════

class _PrivacySheet extends StatefulWidget {
  final WidgetRef ref;
  const _PrivacySheet({required this.ref});

  @override
  State<_PrivacySheet> createState() => _PrivacySheetState();
}

class _PrivacySheetState extends State<_PrivacySheet> {
  String _currentMode = 'public';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacy();
  }

  Future<void> _loadPrivacy() async {
    try {
      final service = widget.ref.read(clientServiceProvider);
      final mode = await service.getPrivacyMode();
      if (mounted) setState(() { _currentMode = mode; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setMode(String mode) async {
    if (mode == _currentMode) return;
    setState(() { _saving = true; _currentMode = mode; });
    try {
      final service = widget.ref.read(clientServiceProvider);
      await service.setPrivacyMode(mode);
      if (mounted) showSnack(context, 'Privacy aggiornata');
    } catch (e) {
      if (mounted) showSnack(context, 'Errore: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Impostazioni Privacy',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Scegli chi può contattarti',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 24),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            )
          else ...[
            _PrivacyOption(
              icon: Icons.public_rounded,
              iconColor: const Color(0xFF22C55E),
              title: 'Pubblico',
              subtitle: 'Chiunque nella tua palestra può scriverti',
              isSelected: _currentMode == 'public',
              onTap: () => _setMode('public'),
            ),
            const SizedBox(height: 12),
            _PrivacyOption(
              icon: Icons.lock_rounded,
              iconColor: const Color(0xFFEAB308),
              title: 'Privato',
              subtitle: 'Richiede approvazione prima che altri possano scriverti',
              isSelected: _currentMode == 'private',
              onTap: () => _setMode('private'),
            ),
            const SizedBox(height: 12),
            _PrivacyOption(
              icon: Icons.shield_rounded,
              iconColor: const Color(0xFFEF4444),
              title: 'Solo Staff',
              subtitle: 'Solo trainer e staff della palestra possono scriverti',
              isSelected: _currentMode == 'staff_only',
              onTap: () => _setMode('staff_only'),
            ),
          ],

          if (_saving)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PrivacyOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _PrivacyOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.elevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SETTINGS ITEM
// ════════════════════════════════════════════════════════════════

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(label, style: const TextStyle(color: AppColors.textPrimary)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
