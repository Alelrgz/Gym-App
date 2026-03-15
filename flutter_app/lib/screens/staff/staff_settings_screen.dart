import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/staff_provider.dart';
import '../../widgets/glass_card.dart';

class StaffSettingsScreen extends ConsumerWidget {
  const StaffSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymInfo = ref.watch(staffGymInfoProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async => ref.invalidate(staffGymInfoProvider),
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
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // ── Profile Card ─────────────────────
                    GlassCard(
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                AppColors.primary,
                                AppColors.primary.withValues(alpha: 0.6),
                              ]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                (user?.username ?? '?')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          gymInfo.when(
                            data: (info) => Text(
                              info['staff_name']?.toString() ??
                                  user?.username ??
                                  '',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            loading: () => const Text('...',
                                style:
                                    TextStyle(color: AppColors.textSecondary)),
                            error: (_, __) => Text(
                              user?.username ?? '',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Reception / Staff',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Info Grid ────────────────────────
                    GlassCard(
                      child: Column(
                        children: [
                          _infoRow(
                            Icons.badge_rounded,
                            'Ruolo',
                            'Staff / Reception',
                          ),
                          const Divider(
                              color: AppColors.borderLight, height: 16),
                          _infoRow(
                            Icons.fitness_center_rounded,
                            'Palestra',
                            gymInfo.when(
                              data: (info) =>
                                  info['gym_name']?.toString() ?? '-',
                              loading: () => '...',
                              error: (_, __) => '-',
                            ),
                          ),
                          const Divider(
                              color: AppColors.borderLight, height: 16),
                          _infoRow(
                            Icons.circle,
                            'Stato',
                            'Attivo',
                            valueColor: AppColors.success,
                          ),
                          const Divider(
                              color: AppColors.borderLight, height: 16),
                          _infoRow(
                            Icons.lock_open_rounded,
                            'Accesso',
                            'Completo',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Logout ───────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            ref.read(authProvider.notifier).logout(),
                        icon: const Icon(Icons.logout_rounded,
                            color: Color(0xFFF87171)),
                        label: const Text('Esci',
                            style: TextStyle(color: Color(0xFFF87171))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFF87171)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
