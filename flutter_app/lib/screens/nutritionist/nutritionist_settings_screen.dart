import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nutritionist_provider.dart';
import '../../services/nutritionist_service.dart';

class NutritionistSettingsScreen extends ConsumerStatefulWidget {
  const NutritionistSettingsScreen({super.key});

  @override
  ConsumerState<NutritionistSettingsScreen> createState() =>
      _NutritionistSettingsScreenState();
}

class _NutritionistSettingsScreenState
    extends ConsumerState<NutritionistSettingsScreen> {
  final _bioCtrl = TextEditingController();
  final _specialties = <String>{};
  bool _loaded = false;

  static const _specialtyOptions = [
    ('Sports Nutrition', 'Nutrizione Sportiva'),
    ('Weight Management', 'Gestione Peso'),
    ('Clinical Nutrition', 'Nutrizione Clinica'),
    ('Vegan', 'Vegano'),
    ('Food Allergies', 'Intolleranze'),
    ('Meal Planning', 'Piani Alimentari'),
  ];

  NutritionistService get _service =>
      ref.read(nutritionistServiceProvider);

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  void _populateFromData(Map<String, dynamic> data) {
    if (_loaded) return;
    _loaded = true;
    _bioCtrl.text = data['bio']?.toString() ?? '';
    final specs = data['specialties'];
    if (specs != null) {
      final list = specs is String
          ? specs.split(',').map((s) => s.trim()).toList()
          : (specs as List).cast<String>();
      _specialties.addAll(list);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nutriAsync = ref.watch(nutritionistDataProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async => ref.invalidate(nutritionistDataProvider),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              title: const Text(
                'Impostazioni',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: _saveProfile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Salva',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: nutriAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary)),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                            child: Text('Errore: $e',
                                style: const TextStyle(
                                    color: AppColors.textSecondary))),
                      ),
                      data: (data) {
                        _populateFromData(data);
                        final displayName = data['name'] ??
                            user?.username ??
                            'Nutrizionista';

                        return Column(
                          children: [
                            const SizedBox(height: 16),

                            // ── Profile Avatar ────────────────
                            _buildAvatar(displayName, data['profile_picture']),
                            const SizedBox(height: 24),

                            // ── Bio Section ───────────────────
                            _buildSection(
                              'Bio',
                              child: TextField(
                                controller: _bioCtrl,
                                maxLines: 3,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.white),
                                decoration: InputDecoration(
                                  hintText:
                                      'Racconta ai clienti di te...',
                                  hintStyle: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14),
                                  filled: true,
                                  fillColor: Colors.white
                                      .withValues(alpha: 0.05),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding:
                                      const EdgeInsets.all(14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ── Specialties Section ───────────
                            _buildSection(
                              'Specializzazioni',
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _specialtyOptions
                                    .map((opt) => _buildSpecialtyChip(
                                        opt.$1, opt.$2))
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // ── Logout ────────────────────────
                            GestureDetector(
                              onTap: () => ref
                                  .read(authProvider.notifier)
                                  .logout(),
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.logout_rounded,
                                        size: 16,
                                        color: AppColors.danger
                                            .withValues(alpha: 0.7)),
                                    const SizedBox(width: 8),
                                    Text('Esci',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.danger
                                                .withValues(alpha: 0.7))),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, String? pictureUrl) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
          ),
          child: pictureUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    pictureUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(initial,
                          style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70)),
                    ),
                  ),
                )
              : Center(
                  child: Text(initial,
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70)),
                ),
        ),
        const SizedBox(height: 12),
        Text(name,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text('Nutrizionista',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildSection(String title, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400])),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _buildSpecialtyChip(String value, String label) {
    final selected = _specialties.contains(value);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selected) {
            _specialties.remove(value);
          } else {
            _specialties.add(value);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected
                    ? AppColors.primary
                    : Colors.grey[500])),
      ),
    );
  }

  Future<void> _saveProfile() async {
    try {
      await _service.updateProfile(
        bio: _bioCtrl.text,
        specialties: _specialties.join(', '),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profilo salvato!'),
              duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Errore: $e'),
              duration: const Duration(seconds: 2)),
        );
      }
    }
  }
}
