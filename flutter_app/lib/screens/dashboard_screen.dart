import 'dart:math' show sin;
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/client_profile.dart';
import '../providers/client_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/dashboard_sheets.dart';
import 'workout_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _welcomeChecked = false;

  void _checkWelcome(BuildContext context, ClientProfile profile) {
    if (_welcomeChecked) return;
    _welcomeChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();

      // Show path choice every time for gymless free users until they choose
      if (profile.gymId == null && profile.accountType == 'free' && context.mounted) {
        _showPathChoiceModal(context);
        return;
      }

      // Then: welcome modal for first-time users who already have a gym
      final seen = prefs.getBool('welcome_seen') ?? false;
      if (!seen && context.mounted) {
        await prefs.setBool('welcome_seen', true);
        if (context.mounted) _showWelcomeModal(context, profile);
        return;
      }

      // Then: onboarding (goal + body stats) if not completed yet
      final onboarded = prefs.getBool('onboarding_done') ?? false;
      if (!onboarded && profile.fitnessGoal == null && context.mounted) {
        _showOnboardingFlow(context);
      }
    });
  }

  void _showOnboardingFlow(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _OnboardingSheet(
        onComplete: (goal, weight, height, gender) async {
          final service = ref.read(clientServiceProvider);
          await service.updateProfile({
            'fitness_goal': goal,
            'weight': weight,
            'height_cm': height,
            'gender': gender,
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('onboarding_done', true);
          ref.invalidate(clientDataProvider);
        },
      ),
    );
  }

  void _showPathChoiceModal(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: AppAnim.dialog,
      pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Come vuoi allenarti?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Scegli come iniziare il tuo percorso',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                const SizedBox(height: 24),

                // Option 1: Join a Gym
                _PathOptionCard(
                  icon: Icons.group_rounded,
                  title: 'Unisciti a una palestra',
                  subtitle: 'Trainer, corsi, comunità e molto altro',
                  tag: 'Incluso nell\'abbonamento',
                  isPrimary: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    showJoinGymDialog(context, ref);
                  },
                ),
                const SizedBox(height: 12),

                // Option 2: Solo
                _PathOptionCard(
                  icon: Icons.person_rounded,
                  title: 'Allenati da solo',
                  subtitle: 'Workout AI, dieta personalizzata, tracking',
                  tag: '€4.99/mese',
                  isPrimary: false,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSoloPaywall(context);
                  },
                ),

                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Decidi dopo',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSoloPaywall(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: AppAnim.dialog,
      pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Allenati da solo',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Scegli il piano che fa per te',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),

                // Solo plan — €4.99
                _SoloPlanCard(
                  title: 'Solo',
                  price: '€4.99',
                  period: '/mese',
                  features: const [
                    'Crea i tuoi allenamenti',
                    'Diario alimentare',
                    'Tracking progressi',
                    'Programmazione settimanale',
                  ],
                  isPro: false,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _startCheckout(context, 'solo');
                  },
                ),
                const SizedBox(height: 12),

                // Solo Pro plan — €9.99
                _SoloPlanCard(
                  title: 'Solo Pro',
                  price: '€9.99',
                  period: '/mese',
                  features: const [
                    'Tutto di Solo, più:',
                    'Workout generati con AI',
                    'Piano alimentare AI personalizzato',
                    'Analisi avanzata progressi',
                  ],
                  isPro: true,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _startCheckout(context, 'solo_pro');
                  },
                ),
                const SizedBox(height: 16),

                // Free trial
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showTrialFlow(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text.rich(
                        TextSpan(
                          text: 'Prova gratis per 15 giorni ',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                          children: [
                            TextSpan(
                              text: '(richiede email)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Non ora', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  Future<void> _startCheckout(BuildContext context, String plan) async {
    try {
      final service = ref.read(clientServiceProvider);
      final checkoutUrl = await service.createSoloCheckout(plan: plan);
      if (context.mounted) {
        await launchUrl(Uri.parse(checkoutUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nel pagamento'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showTrialFlow(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrialSignupSheet(
        onComplete: () {
          ref.invalidate(clientDataProvider);
        },
        ref: ref,
      ),
    );
  }

  void _showWelcomeModal(BuildContext context, ClientProfile profile) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: AppAnim.dialog,
      pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
              contentPadding: const EdgeInsets.all(24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    "Benvenuto su Heaven's!",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ecco come iniziare:',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 20),
                  _WelcomeStep(
                    icon: Icons.fitness_center_rounded,
                    title: profile.gymId != null ? 'Palestra connessa' : 'Unisciti a una palestra',
                    subtitle: profile.gymId != null ? 'Sei già iscritto!' : 'Inserisci il codice della tua palestra',
                    done: profile.gymId != null,
                  ),
                  const SizedBox(height: 10),
                  _WelcomeStep(
                    icon: Icons.calendar_today_rounded,
                    title: 'Prenota un appuntamento',
                    subtitle: 'Conosci il tuo trainer',
                    done: profile.trainerName != null,
                  ),
                  const SizedBox(height: 10),
                  _WelcomeStep(
                    icon: Icons.directions_run_rounded,
                    title: 'Inizia ad allenarti',
                    subtitle: 'Completa il tuo primo workout',
                    done: false,
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      child: const Text('Iniziamo!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final clientData = ref.watch(clientDataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: clientData.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              const Text('Errore nel caricamento',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text('$error',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(clientDataProvider),
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
        data: (profile) {
          _checkWelcome(context, profile);
          return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(clientDataProvider);
            ref.invalidate(unreadMessagesProvider);
            ref.invalidate(unreadNotificationsProvider);
          },
          child: CustomScrollView(
            slivers: [
              // --- CONTENT ---
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // 1. Streak + Gems (tap to open streak page)
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        AppAnim.pageRoute(_StreakPage(streak: profile.streak, gems: profile.gems)),
                      ),
                      child: _StreakGemsCard(streak: profile.streak, gems: profile.gems),
                    ),
                    const SizedBox(height: 16),

                    // 2. Workout Card
                    _WorkoutCard(profile: profile),
                    const SizedBox(height: 16),

                    // 3. Photo + Meals Grid
                    _PhotoMealsGrid(profile: profile, onProgress: () => showProgressSheet(context, ref)),
                    const SizedBox(height: 16),

                    // 4. Trainer Card
                    if (profile.trainerName != null) ...[
                      _TrainerCard(
                        profile: profile,
                        onChat: () => showConversationsSheet(context, ref),
                        onCalendar: () => showAppointmentsSheet(context, ref),
                      ),
                      const SizedBox(height: 16),
                    ] else if (profile.gymId != null) ...[
                      _NoTrainerCard(onBook: () => showBookAppointmentSheet(context, ref)),
                      const SizedBox(height: 16),
                    ],


                    // 7. Leaderboard Link
                    _LeaderboardLinkCard(),
                    const SizedBox(height: 16),

                    // No gym prompt
                    if (profile.gymId == null) _NoGymCard(onJoin: () => showJoinGymDialog(context, ref)),
                    // Solo upgrade prompt for free gymless users
                    if (profile.gymId == null && profile.accountType == 'free') ...[
                      const SizedBox(height: 12),
                      GlassCard(
                        onTap: () => _showSoloPaywall(context),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Allenati da solo con FitOS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  Text('Workout AI e dieta personalizzata — €4.99/mese', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: Colors.grey[600], size: 20),
                          ],
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        );},
      ),
    );
  }
}

// ─── 1. WORKOUT CARD ─────────────────────────────────────────────

class _WorkoutCard extends ConsumerWidget {
  final ClientProfile profile;

  const _WorkoutCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = profile.todayWorkout;
    final hasWorkout = workout != null;
    final isCompleted = workout?['completed'] == true;
    final title = hasWorkout ? (workout['title'] ?? 'Workout') : 'Nessun allenamento';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent bar
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: isCompleted
                  ? const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF16A34A)])
                  : const LinearGradient(colors: [AppColors.primary, Color(0xFFE07A00)]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF22C55E).withValues(alpha: 0.10)
                            : AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isCompleted ? Icons.check_rounded : Icons.fitness_center_rounded,
                        size: 20,
                        color: isCompleted ? const Color(0xFF22C55E) : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Allenamento di Oggi',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textTertiary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasWorkout)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_horiz_rounded, size: 20, color: Colors.grey[500]),
                        color: AppColors.surface,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (v) {
                          if (v == 'edit') {
                            Navigator.of(context).push(AppAnim.pageRoute(WorkoutBuilderPage(
                              existingWorkout: workout,
                              onSaved: () {
                                ref.invalidate(clientDataProvider);
                                Navigator.of(context).pop();
                              },
                            )));
                          } else if (v == 'list') {
                            context.go('/workouts');
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Modifica allenamento', style: TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                          const PopupMenuItem(value: 'list', child: Text('I miei allenamenti', style: TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                        ],
                      ),
                  ],
                ),

                // Metadata chips
                if (hasWorkout) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _MetadataChip(
                        icon: Icons.timer_outlined,
                        label: workout['duration']?.toString() ?? '0 min',
                      ),
                      const SizedBox(width: 8),
                      _MetadataChip(
                        icon: Icons.signal_cellular_alt_rounded,
                        label: workout['difficulty']?.toString() ?? 'Relax',
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    'Nessun allenamento assegnato per oggi.',
                    style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => context.go('/workouts'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      child: const Text(
                        'Crea il tuo allenamento',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (hasWorkout && !isCompleted) {
                            showGeneralDialog(
                              context: context,
                              barrierDismissible: true,
                              barrierLabel: '',
                              barrierColor: Colors.black54,
                              transitionDuration: AppAnim.dialog,
                              transitionBuilder: (ctx, anim, anim2, child) {
                                final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
                                return ScaleTransition(
                                  scale: curve,
                                  child: FadeTransition(opacity: anim, child: child),
                                );
                              },
                              pageBuilder: (ctx, anim, anim2) => Dialog(
                                backgroundColor: AppColors.surface,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                insetPadding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Vuoi iniziare "$title"?',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: GestureDetector(
                                              onTap: () {
                                                Navigator.of(ctx).pop();
                                                Navigator.of(context).push(AppAnim.pageRoute(
                                                  WorkoutScreen(initialWorkout: workout),
                                                ));
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary,
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                                child: const Center(
                                                  child: Text('Inizia', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            flex: 2,
                                            child: GestureDetector(
                                              onTap: () {
                                                Navigator.of(ctx).pop();
                                                context.go('/workouts');
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                                decoration: BoxDecoration(
                                                  color: AppColors.elevated,
                                                  borderRadius: BorderRadius.circular(14),
                                                  // no border
                                                ),
                                                child: const Center(
                                                  child: Text('Cambia', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                                                ),
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
                          } else {
                            context.go('/workouts');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? const Color(0xFF22C55E)
                                : AppColors.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isCompleted) ...[
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                isCompleted ? 'Completato' : (hasWorkout ? 'Inizia' : 'I Miei Allenamenti'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => showCoopModal(context, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          // no border
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.people_rounded, size: 18, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text('Co-op', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
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
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetadataChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        // no border
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ─── 2. STREAK & GEMS CARD ──────────────────────────────────────

class _StreakGemsCard extends StatefulWidget {
  final int streak;
  final int gems;

  const _StreakGemsCard({required this.streak, required this.gems});

  @override
  State<_StreakGemsCard> createState() => _StreakGemsCardState();
}

class _StreakGemsCardState extends State<_StreakGemsCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flameController;

  @override
  void initState() {
    super.initState();
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _flameController.dispose();
    super.dispose();
  }

  int get _weeks => widget.streak ~/ 7;

  String _streakDisplay() => '$_weeks';

  String _streakLabel() {
    return _weeks == 1 ? 'SETTIMANA DI\nSERIE' : 'SETTIMANE DI\nSERIE';
  }

  String _nextGoal() {
    const milestones = [2, 4, 8, 12, 16, 24, 36, 52];
    final weeks = _weeks;
    final next = milestones.cast<int?>().firstWhere((m) => m! > weeks, orElse: () => null);
    final target = next ?? (weeks + 4);
    final remaining = target - weeks;
    return '$remaining SETTIMANE';
  }

  static const _lucideFlame = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 3q1 4 4 6.5t3 5.5a1 1 0 0 1-14 0 5 5 0 0 1 1-3 1 1 0 0 0 5 0c0-2-1.5-3-1.5-5q0-2 2.5-4"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Top row: flame + number + label + gems
          Row(
            children: [
              // Animated flame icon (Lucide SVG)
              AnimatedBuilder(
                animation: _flameController,
                builder: (context, child) {
                  final t = _flameController.value;
                  final scaleY = 1.0 + 0.08 * sin(t * 2 * 3.14159 * 2);
                  final scaleX = 1.0 - 0.03 * sin(t * 2 * 3.14159 * 3);
                  final rotation = 0.035 * sin(t * 2 * 3.14159 * 2.5);
                  return Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..scale(scaleX, scaleY)
                      ..rotateZ(rotation),
                    child: child,
                  );
                },
                child: SvgPicture.string(
                  _lucideFlame.replaceAll('currentColor', '#FF8C00'),
                  width: 34,
                  height: 34,
                ),
              ),
              const SizedBox(width: 14),
              // Large streak number
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFF8C00), Color(0xFFFFB347), Color(0xFFFF8C00)],
                ).createShader(bounds),
                child: Text(
                  _streakDisplay(),
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Label to the right of the number
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _streakLabel(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                    height: 1.3,
                  ),
                ),
              ),
              const Spacer(),
              // Gems badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFEAB308).withValues(alpha: 0.2),
                      const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔶', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.gems}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          // Next goal row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Prossimo Obiettivo',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                _nextGoal(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── STREAK PAGE (Duolingo-style) ──────────────────────────────

class _StreakPage extends ConsumerStatefulWidget {
  final int streak;
  final int gems;

  const _StreakPage({required this.streak, required this.gems});

  @override
  ConsumerState<_StreakPage> createState() => _StreakPageState();
}

class _StreakPageState extends ConsumerState<_StreakPage> with SingleTickerProviderStateMixin {
  late final AnimationController _flameController;
  int _currentMonth = DateTime.now().month;
  int _currentYear = DateTime.now().year;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _flameController.dispose();
    super.dispose();
  }

  static const _lucideFlame = '''
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 3q1 4 4 6.5t3 5.5a1 1 0 0 1-14 0 5 5 0 0 1 1-3 1 1 0 0 0 5 0c0-2-1.5-3-1.5-5q0-2 2.5-4"/>
</svg>
''';

  int get _weeks => widget.streak ~/ 7;

  int get _nextMilestone {
    const milestones = [2, 4, 8, 12, 16, 24, 36, 52];
    return milestones.cast<int?>().firstWhere((m) => m! > _weeks, orElse: () => null) ?? (_weeks + 4);
  }

  static const _monthNames = ['Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'];
  static const _dayHeaders = ['LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'];

  Set<String> get _completedDates {
    final asyncProfile = ref.read(clientDataProvider);
    if (!asyncProfile.hasValue) return {};
    return asyncProfile.value!.calendarEvents
        .where((e) => e.completed)
        .map((e) => e.date)
        .toSet();
  }

  Set<String> get _workoutDates {
    final asyncProfile = ref.read(clientDataProvider);
    if (!asyncProfile.hasValue) return {};
    return asyncProfile.value!.calendarEvents
        .where((e) => e.type == 'workout')
        .map((e) => e.date)
        .toSet();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _buildWeekStreak() {
    final now = DateTime.now();
    // Get Monday of current week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dayLabels = ['LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'];
    final completed = _completedDates;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        // no border
      ),
      child: Column(
        children: [
          const Text('Questa Settimana', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final day = monday.add(Duration(days: i));
              final dateStr = _fmtDate(day);
              final isDone = completed.contains(dateStr);
              final isToday = day.day == now.day && day.month == now.month && day.year == now.year;
              final isPast = day.isBefore(DateTime(now.year, now.month, now.day));

              return Column(
                children: [
                  Text(
                    dayLabels[i],
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDone
                          ? AppColors.primary
                          : isToday
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: isToday && !isDone ? Border.all(color: AppColors.primary, width: 1.5) : null,
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                          : Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isPast ? Colors.grey[600] : AppColors.textPrimary,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCalendar() {
    final completed = _completedDates;
    final workouts = _workoutDates;
    final now = DateTime.now();
    // Monday-first: 0=Mon..6=Sun
    final firstDay = DateTime(_currentYear, _currentMonth, 1);
    final firstDayOffset = (firstDay.weekday - 1) % 7; // Mon=0
    final daysInMonth = DateTime(_currentYear, _currentMonth + 1, 0).day;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        // no border
      ),
      child: Column(
        children: [
          // Month header with arrows
          Row(
            children: [
              Text(
                '${_monthNames[_currentMonth - 1]} $_currentYear',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _currentMonth--;
                  if (_currentMonth < 1) { _currentMonth = 12; _currentYear--; }
                }),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.chevron_left_rounded, color: AppColors.primary, size: 24),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _currentMonth++;
                  if (_currentMonth > 12) { _currentMonth = 1; _currentYear++; }
                }),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Day headers
          Row(
            children: _dayHeaders.map((d) => Expanded(
              child: Center(
                child: Text(d, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[600])),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          // Calendar grid
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.0,
            mainAxisSpacing: 4,
            crossAxisSpacing: 0,
            children: [
              // Empty cells for offset
              for (var i = 0; i < firstDayOffset; i++)
                const SizedBox.shrink(),
              // Day cells
              for (var day = 1; day <= daysInMonth; day++)
                _buildStreakDayCell(day, now, completed, workouts),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakDayCell(int day, DateTime now, Set<String> completed, Set<String> workouts) {
    final date = DateTime(_currentYear, _currentMonth, day);
    final dateStr = _fmtDate(date);
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isCompleted = completed.contains(dateStr);
    final hasWorkout = workouts.contains(dateStr);
    final isPast = date.isBefore(DateTime(now.year, now.month, now.day));
    final isSelected = _selectedDay != null &&
        date.year == _selectedDay!.year && date.month == _selectedDay!.month && date.day == _selectedDay!.day;

    return GestureDetector(
      onTap: () => setState(() => _selectedDay = date),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : isToday
                      ? AppColors.primary
                      : isSelected
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.transparent,
              border: (isToday && !isCompleted) || isSelected
                  ? Border.all(color: AppColors.primary, width: 2)
                  : null,
            ),
            child: isCompleted
                ? SvgPicture.string(
                    _lucideFlame.replaceAll('currentColor', '#FF8C00'),
                    width: 16, height: 16, fit: BoxFit.scaleDown,
                  )
                : Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: (isToday || isSelected) ? FontWeight.w700 : FontWeight.w400,
                        color: isToday
                            ? Colors.white
                            : (hasWorkout || isSelected)
                                ? AppColors.textPrimary
                                : isPast
                                    ? Colors.grey[700]
                                    : AppColors.textTertiary,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _eventsForSelectedDay() {
    if (_selectedDay == null) return [];
    final asyncProfile = ref.read(clientDataProvider);
    if (!asyncProfile.hasValue) return [];
    final dateStr = _fmtDate(_selectedDay!);
    return asyncProfile.value!.calendarEvents
        .where((e) => e.date == dateStr)
        .toList();
  }

  static const _italianDays = ['Domenica', 'Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato'];
  static const _italianMonths = ['Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'];

  Widget _buildSelectedDayDetails() {
    if (_selectedDay == null) return const SizedBox.shrink();

    final events = _eventsForSelectedDay();
    final dayName = _italianDays[_selectedDay!.weekday % 7];
    final label = '$dayName ${_selectedDay!.day} ${_italianMonths[_selectedDay!.month - 1]}'.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 1.0)),
          const SizedBox(height: 8),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Nessun evento programmato.', style: TextStyle(fontSize: 13, color: Colors.grey[500], fontStyle: FontStyle.italic)),
            )
          else
            ...events.map((event) {
              final statusText = event.completed ? 'COMPLETATO' : 'PROGRAMMATO';
              final statusColor = event.completed ? const Color(0xFF4ADE80) : AppColors.primary;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  // no border
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        event.type == 'workout' ? Icons.fitness_center_rounded
                            : event.type == 'course' ? Icons.school_rounded
                            : event.type == 'appointment' ? Icons.event_rounded
                            : Icons.event_note_rounded,
                        color: statusColor, size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          if (event.details != null && event.details!.isNotEmpty && !event.details!.startsWith('{'))
                            Text(event.details!, style: TextStyle(fontSize: 12, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _weeks / _nextMilestone;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('La Tua Serie', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          children: [
            // ── Big flame + streak number ──
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _flameController,
              builder: (context, child) {
                final t = _flameController.value;
                final scaleY = 1.0 + 0.06 * sin(t * 2 * 3.14159 * 2);
                final scaleX = 1.0 - 0.02 * sin(t * 2 * 3.14159 * 3);
                return Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()..scale(scaleX, scaleY),
                  child: child,
                );
              },
              child: SvgPicture.string(
                _lucideFlame.replaceAll('currentColor', '#FF8C00'),
                width: 80,
                height: 80,
              ),
            ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFF8C00), Color(0xFFFFB347), Color(0xFFFF8C00)],
              ).createShader(bounds),
              child: Text(
                '$_weeks',
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
            Text(
              _weeks == 1 ? 'settimana di serie' : 'settimane di serie',
              style: TextStyle(fontSize: 16, color: Colors.grey[400], fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 36),

            // ── Week Streak ──
            _buildWeekStreak(),
            const SizedBox(height: 16),

            // ── Next milestone progress ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                // no border
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Prossimo obiettivo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text('$_nextMilestone settimane', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_nextMilestone - _weeks} settimane rimanenti',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Gems ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                // no border
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAB308).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: Text('🔶', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${widget.gems}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        Text('Gemme totali', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 3. PHOTO + MEALS GRID ──────────────────────────────────────

String? _resolveUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http')) return url;
  return '${ApiConfig.baseUrl}$url';
}

class _PhotoMealsGrid extends ConsumerWidget {
  final ClientProfile profile;
  final VoidCallback onProgress;

  const _PhotoMealsGrid({required this.profile, required this.onProgress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // Left: Physique Photo / Progress
        Expanded(
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: GestureDetector(
              onTap: onProgress,
              child: FutureBuilder<Map<String, dynamic>>(
                future: ref.read(clientServiceProvider).getPhysiquePhotos(),
                builder: (context, snap) {
                  final photos = (snap.data?['photos'] as List<dynamic>?)?.whereType<Map<String, dynamic>>().toList() ?? [];
                  final latestUrl = photos.isNotEmpty ? _resolveUrl(photos.first['photo_url'] as String?) : null;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (latestUrl != null && latestUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            child: Image.network(latestUrl, fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Center(child: Icon(Icons.camera_alt_rounded, size: 32, color: AppColors.textTertiary))),
                          )
                        else
                          const Center(child: Icon(Icons.camera_alt_rounded, size: 32, color: AppColors.textTertiary)),
                        Positioned(
                          left: 12, right: 12, bottom: 12,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.50),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'PROGRESSI',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary, letterSpacing: 1.0),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Right: Today's Meals from weekly plan
        Expanded(
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: GlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(12),
              child: _TodayMealsCard(ref: ref),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 3b. TODAY'S MEALS (from weekly plan) ────────────────────────

class _TodayMealsCard extends StatefulWidget {
  final WidgetRef ref;
  const _TodayMealsCard({required this.ref});

  @override
  State<_TodayMealsCard> createState() => _TodayMealsCardState();
}

class _TodayMealsCardState extends State<_TodayMealsCard> {
  List<Map<String, dynamic>> _todayMeals = [];
  bool _loading = true;

  static const _mealIcons = {
    'colazione': Icons.free_breakfast_rounded,
    'spuntino_mattina': Icons.apple_rounded,
    'pranzo': Icons.restaurant_rounded,
    'spuntino_pomeriggio': Icons.cookie_rounded,
    'cena': Icons.dinner_dining_rounded,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = widget.ref.read(clientServiceProvider);
      final data = await service.getWeeklyMealPlan();
      final plan = data['plan'] as Map<String, dynamic>? ?? {};
      final todayIndex = DateTime.now().weekday - 1; // 0=Mon, 6=Sun
      final dayKey = todayIndex.toString();
      final dayMeals = plan[dayKey];
      if (dayMeals is List) {
        setState(() {
          _todayMeals = dayMeals.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PASTI DI OGGI',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.35),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)))
              : _todayMeals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.restaurant_menu_rounded, color: Colors.grey[700], size: 28),
                          const SizedBox(height: 8),
                          Text('Nessun pasto', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _todayMeals.length,
                      separatorBuilder: (_, _) => Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
                      itemBuilder: (_, i) {
                        final m = _todayMeals[i];
                        final type = m['meal_type']?.toString() ?? '';
                        final name = m['meal_name']?.toString() ?? '';
                        final cals = (m['calories'] as num?)?.toInt() ?? 0;
                        final icon = _mealIcons[type] ?? Icons.restaurant_rounded;
                        final typeLabel = type.replaceAll('_', ' ').toUpperCase();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(icon, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      typeLabel,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.45), letterSpacing: 0.5),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (cals > 0) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '$cals kcal',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                name,
                                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => context.go('/diet'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              // no border
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'DIETA',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }

}

// ─── 4. TRAINER CARD ─────────────────────────────────────────────

class _TrainerCard extends StatelessWidget {
  final ClientProfile profile;
  final VoidCallback? onChat;
  final VoidCallback? onCalendar;

  const _TrainerCard({required this.profile, this.onChat, this.onCalendar});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              child: profile.trainerPicture != null
                  ? ClipOval(
                      child: Image.network(
                        profile.trainerPicture!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, s) => const Icon(Icons.person, size: 20, color: AppColors.textTertiary),
                      ),
                    )
                  : const Icon(Icons.person, size: 20, color: AppColors.textTertiary),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IL MIO TRAINER',
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.35), fontWeight: FontWeight.w500, letterSpacing: 1.2),
                  ),
                  Text(
                    profile.trainerName ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            // Message button
            _CircleButton(icon: Icons.chat_bubble_outline_rounded, onTap: onChat ?? () {}),
            const SizedBox(width: 8),
            // Calendar button
            _CircleButton(icon: Icons.calendar_today_rounded, onTap: onCalendar ?? () {}),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.05),
          // no border
        ),
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }
}

// ─── 7. LEADERBOARD LINK ─────────────────────────────────────────

class _LeaderboardLinkCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.push('/leaderboard'),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.primary.withValues(alpha: 0.10),
            ),
            child: Icon(Icons.emoji_events_rounded, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sfide Giornaliere & Classifiche',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                SizedBox(height: 2),
                Text(
                  'Completa sfide per guadagnare gemme',
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey[600]),
        ],
      ),
    );
  }
}

// ─── NO GYM PROMPT ───────────────────────────────────────────────

class _NoGymCard extends StatelessWidget {
  final VoidCallback? onJoin;
  const _NoGymCard({this.onJoin});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      variant: GlassVariant.accent,
      child: Column(
        children: [
          const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Unisciti a una palestra',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Inserisci il codice della tua palestra per iniziare',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onJoin,
            child: const Text('Inserisci Codice'),
          ),
        ],
      ),
    );
  }
}

// ─── NO TRAINER PROMPT ──────────────────────────────────────────

class _NoTrainerCard extends StatelessWidget {
  final VoidCallback? onBook;
  const _NoTrainerCard({this.onBook});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          const Icon(Icons.person_search_rounded, color: AppColors.primary, size: 36),
          const SizedBox(height: 10),
          const Text(
            'Prenota il tuo primo appuntamento',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Conosci un trainer e inizia il tuo percorso',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onBook,
            icon: const Icon(Icons.calendar_today_rounded, size: 16),
            label: const Text('Prenota'),
          ),
        ],
      ),
    );
  }
}

// ─── WELCOME STEP ───────────────────────────────────────────────

class _WelcomeStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;

  const _WelcomeStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: done ? AppColors.primary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            done ? Icons.check_rounded : icon,
            size: 18,
            color: done ? AppColors.primary : AppColors.textTertiary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: done ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── PATH CHOICE CARD ───────────────────────────────────────────

class _PathOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;
  final bool isPrimary;
  final VoidCallback onTap;

  const _PathOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(height: 6),
                  Text(tag, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isPrimary ? AppColors.primary : Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[600], size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── SOLO PLAN CARD ─────────────────────────────────────────────

class _SoloPlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final List<String> features;
  final bool isPro;
  final VoidCallback onTap;

  const _SoloPlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    required this.isPro,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPro
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPro
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
            width: isPro ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (isPro) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('AI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ),
                ],
                const Spacer(),
                Text(price, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isPro ? AppColors.primary : AppColors.textPrimary)),
                Text(period, style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
            const SizedBox(height: 10),
            for (final f in features)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_rounded, size: 14, color: isPro ? AppColors.primary : AppColors.textTertiary),
                    const SizedBox(width: 8),
                    Flexible(child: Text(f, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── ONBOARDING SHEET (Goal + Body Stats) ───────────────────────

class _OnboardingSheet extends StatefulWidget {
  final Future<void> Function(String goal, double weight, double height, String gender) onComplete;

  const _OnboardingSheet({required this.onComplete});

  @override
  State<_OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<_OnboardingSheet> {
  int _step = 0; // 0 = goal, 1 = body stats
  String? _goal;
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String _gender = 'male';
  bool _saving = false;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final weight = double.tryParse(_weightCtrl.text.trim());
    final height = double.tryParse(_heightCtrl.text.trim());
    if (_goal == null || weight == null || height == null) return;

    setState(() => _saving = true);
    try {
      await widget.onComplete(_goal!, weight, height, _gender);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
            ),

            // Step indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepDot(active: _step == 0),
                const SizedBox(width: 8),
                _StepDot(active: _step == 1),
              ],
            ),
            const SizedBox(height: 20),

            if (_step == 0) ...[
              // ── GOAL SELECTION ──
              const Text(
                'Qual è il tuo obiettivo?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Questo ci aiuta a personalizzare la tua esperienza',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _GoalOption(icon: Icons.trending_down_rounded, label: 'Perdere peso', value: 'lose_weight', selected: _goal, onTap: (v) => setState(() => _goal = v)),
              const SizedBox(height: 10),
              _GoalOption(icon: Icons.fitness_center_rounded, label: 'Aumentare massa', value: 'build_muscle', selected: _goal, onTap: (v) => setState(() => _goal = v)),
              const SizedBox(height: 10),
              _GoalOption(icon: Icons.favorite_rounded, label: 'Mantenersi in forma', value: 'stay_active', selected: _goal, onTap: (v) => setState(() => _goal = v)),
              const SizedBox(height: 10),
              _GoalOption(icon: Icons.sports_soccer_rounded, label: 'Preparazione sportiva', value: 'sport', selected: _goal, onTap: (v) => setState(() => _goal = v)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _goal != null ? () => setState(() => _step = 1) : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _goal != null ? AppColors.primary : Colors.grey[800],
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  child: const Text('Avanti',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ] else ...[
              // ── BODY STATS ──
              const Text(
                'I tuoi dati',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Servono per calcolare il tuo piano personalizzato',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Gender
              Row(
                children: [
                  _GenderChip(label: 'Uomo', value: 'male', selected: _gender, onTap: (v) => setState(() => _gender = v)),
                  const SizedBox(width: 10),
                  _GenderChip(label: 'Donna', value: 'female', selected: _gender, onTap: (v) => setState(() => _gender = v)),
                ],
              ),
              const SizedBox(height: 20),

              // Weight
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Peso (kg)',
                        labelStyle: TextStyle(color: AppColors.textTertiary),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _heightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Altezza (cm)',
                        labelStyle: TextStyle(color: AppColors.textTertiary),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => _step = 0),
                    child: const Text('Indietro', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _saving ? null : _complete,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: _saving ? Colors.grey[800] : AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Iniziamo!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool active;
  const _StepDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: active ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _GoalOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? selected;
  final ValueChanged<String> onTap;

  const _GoalOption({required this.icon, required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textTertiary, size: 22),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isSelected ? AppColors.primary : AppColors.textPrimary)),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  const _GenderChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          child: Center(
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? AppColors.primary : AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }
}

// ─── TRIAL SIGNUP SHEET ─────────────────────────────────────────

class _TrialSignupSheet extends StatefulWidget {
  final VoidCallback onComplete;
  final WidgetRef ref;

  const _TrialSignupSheet({required this.onComplete, required this.ref});

  @override
  State<_TrialSignupSheet> createState() => _TrialSignupSheetState();
}

class _TrialSignupSheetState extends State<_TrialSignupSheet> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  int _step = 0; // 0 = enter email, 1 = enter code
  bool _loading = false;
  String? _error;
  bool _termsAccepted = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Inserisci un\'email valida');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final service = widget.ref.read(clientServiceProvider);
      await service.trialSendCode(email);
      if (mounted) setState(() { _step = 1; _loading = false; });
    } catch (e) {
      if (mounted) {
        String msg = 'Errore nell\'invio';
        if (e is DioException && e.response?.data is Map) {
          msg = (e.response!.data as Map)['detail']?.toString() ?? msg;
        }
        setState(() { _error = msg; _loading = false; });
      }
    }
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Inserisci il codice a 6 cifre');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final service = widget.ref.read(clientServiceProvider);
      await service.trialVerify(_emailCtrl.text.trim(), code);
      widget.onComplete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prova gratuita di 15 giorni attivata!'), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Codice non valido';
        if (e is DioException && e.response?.data is Map) {
          msg = (e.response!.data as Map)['detail']?.toString() ?? msg;
        }
        setState(() { _error = msg; _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomInset),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
          ),

          Icon(
            _step == 0 ? Icons.email_rounded : Icons.pin_rounded,
            color: AppColors.primary,
            size: 36,
          ),
          const SizedBox(height: 14),
          Text(
            _step == 0 ? 'Prova gratuita 15 giorni' : 'Verifica email',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            _step == 0
                ? 'Inserisci la tua email per attivare la prova'
                : 'Inserisci il codice a 6 cifre inviato a ${_emailCtrl.text.trim()}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          if (_step == 0)
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'email@esempio.com',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.email_outlined, size: 20, color: AppColors.textTertiary),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _sendCode(),
            )
          else
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, letterSpacing: 6),
              textAlign: TextAlign.center,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: TextStyle(color: Colors.grey[700]),
                counterText: '',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _verify(),
            ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),

          if (_step == 0) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() => _termsAccepted = !_termsAccepted),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: _termsAccepted ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _termsAccepted ? AppColors.primary : Colors.grey[600]!,
                        width: 1.5,
                      ),
                    ),
                    child: _termsAccepted
                        ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Accetto i ',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        children: const [
                          TextSpan(
                            text: 'Termini di Servizio',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: ' e la '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          GestureDetector(
            onTap: _loading ? null : (_step == 0
                ? (_termsAccepted ? _sendCode : null)
                : _verify),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: (_step == 0 && !_termsAccepted) || _loading
                    ? Colors.grey[800]
                    : AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: _loading
                  ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                  : Text(
                      _step == 0 ? 'Invia codice' : 'Attiva prova gratuita',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
            ),
          ),

          if (_step == 1)
            TextButton(
              onPressed: () => setState(() { _step = 0; _error = null; }),
              child: const Text('Cambia email', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
