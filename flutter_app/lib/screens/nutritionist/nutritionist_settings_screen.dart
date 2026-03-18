import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nutritionist_provider.dart';
import '../../services/nutritionist_service.dart';
import '../../widgets/glass_card.dart';

const Color _kCyan = Color(0xFF06B6D4);

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
        color: _kCyan,
        backgroundColor: AppColors.surface,
        onRefresh: () async => ref.invalidate(nutritionistDataProvider),
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              title: Text(
                'Impostazioni',
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
                child: nutriAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: _kCyan)),
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
                    final displayName =
                        data['name'] ?? user?.username ?? 'Nutrizionista';

                    return Column(
                      children: [
                        const SizedBox(height: 8),

                        // ── Profile Header ───────────────────
                        GlassCard(
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    _kCyan,
                                    _kCyan.withValues(alpha: 0.6),
                                  ]),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Center(
                                  child: data['profile_picture'] !=
                                          null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: Image.network(
                                            data['profile_picture'],
                                            width: 72,
                                            height: 72,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (_, __, ___) => Text(
                                              displayName[0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                  fontSize: 28,
                                                  fontWeight:
                                                      FontWeight.w800,
                                                  color: Colors.white),
                                            ),
                                          ),
                                        )
                                      : Text(
                                          displayName[0].toUpperCase(),
                                          style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(displayName,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      _kCyan.withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: const Text('Nutrizionista',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _kCyan)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Profile Card ─────────────────────
                        GlassCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text('Profilo',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                              const SizedBox(height: 12),
                              const Text('Bio',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textTertiary)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _bioCtrl,
                                maxLines: 3,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white),
                                decoration: InputDecoration(
                                  hintText:
                                      'Racconta ai clienti di te...',
                                  hintStyle: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13),
                                  filled: true,
                                  fillColor: Colors.white
                                      .withValues(alpha: 0.04),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.08)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.08)),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.all(12),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text('Specializzazioni',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textTertiary)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _specialtyOptions
                                    .map((opt) =>
                                        _buildSpecialtyChip(
                                            opt.$1, opt.$2))
                                    .toList(),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _saveProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _kCyan,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(
                                            vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(
                                                12)),
                                  ),
                                  child: const Text('Salva Profilo',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Account ──────────────────────────
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          child: Row(
                            children: [
                              const Text('Account',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => ref
                                    .read(authProvider.notifier)
                                    .logout(),
                                icon: const Icon(
                                    Icons.logout_rounded,
                                    size: 16,
                                    color: AppColors.danger),
                                label: const Text('Esci',
                                    style: TextStyle(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
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
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? _kCyan.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? _kCyan.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? _kCyan : Colors.grey[500])),
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
