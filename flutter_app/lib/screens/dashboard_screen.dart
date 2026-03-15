import 'dart:math' show sin;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../models/client_profile.dart';
import '../providers/client_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/dashboard_sheets.dart';
import 'workout_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientData = ref.watch(clientDataProvider);
    final unreadMessages = ref.watch(unreadMessagesProvider);
    final unreadNotifications = ref.watch(unreadNotificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
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
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(clientDataProvider),
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
        data: (profile) => RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(clientDataProvider);
            ref.invalidate(unreadMessagesProvider);
            ref.invalidate(unreadNotificationsProvider);
          },
          child: CustomScrollView(
            slivers: [
              // --- TOP BAR ---
              SliverAppBar(
                floating: true,
                backgroundColor: AppColors.background,
                surfaceTintColor: Colors.transparent,
                toolbarHeight: 68,
                title: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SvgPicture.asset('assets/fitos-logo.svg', height: 34),
                ),
                centerTitle: false,
                actions: [
                  _TopBarIcon(
                    icon: Icons.qr_code_rounded,
                    onTap: () => showQrAccessDialog(context, ref),
                  ),
                  const SizedBox(width: 8),
                  _TopBarIcon(
                    icon: Icons.calendar_today_rounded,
                    onTap: () => showCalendarSheet(context, ref),
                  ),
                  const SizedBox(width: 8),
                  _TopBarIconBadge(
                    icon: Icons.notifications_none_rounded,
                    count: unreadNotifications.valueOrNull ?? 0,
                    onTap: () => showNotificationsSheet(context, ref),
                  ),
                  const SizedBox(width: 8),
                  _TopBarIconBadge(
                    icon: Icons.send_rounded,
                    count: unreadMessages.valueOrNull ?? 0,
                    onTap: () => showConversationsSheet(context, ref),
                  ),
                  const SizedBox(width: 16),
                ],
              ),

              // --- CONTENT ---
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // 1. Workout Card
                    _WorkoutCard(profile: profile),
                    const SizedBox(height: 16),

                    // 2. Streak + Gems (tap to open calendar)
                    GestureDetector(
                      onTap: () => showCalendarSheet(context, ref),
                      child: _StreakGemsCard(streak: profile.streak, gems: profile.gems),
                    ),
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
                    ],


                    // 7. Leaderboard Link
                    _LeaderboardLinkCard(),
                    const SizedBox(height: 16),

                    // No gym prompt
                    if (profile.gymId == null) _NoGymCard(onJoin: () => showJoinGymDialog(context, ref)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── TOP BAR ICONS ───────────────────────────────────────────────

class _TopBarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopBarIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

class _TopBarIconBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  const _TopBarIconBadge({required this.icon, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Icon(icon, size: 20, color: AppColors.textPrimary),
            ),
            if (count > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      count > 99 ? '99' : '$count',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── 1. WORKOUT CARD (Orange Gradient) ───────────────────────────

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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8461E), Color(0xFFF15A24), Color(0xFFF97316)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ALLENAMENTO DI OGGI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 1.2,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => WorkoutBuilderPage(
                      existingWorkout: workout,
                      onSaved: () {
                        ref.invalidate(clientDataProvider);
                        Navigator.of(context).pop();
                      },
                    ),
                  ));
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.edit_rounded, size: 16, color: Colors.white.withValues(alpha: 0.8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),

          // Duration & difficulty
          Text(
            hasWorkout
                ? '• ${workout['duration'] ?? '0 min'} • ${workout['difficulty'] ?? 'Relax'}'
                : 'Il tuo trainer non ha ancora assegnato un allenamento per oggi.',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 24),

          // Divider + Buttons (always visible)
          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.go('/workouts'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.white.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isCompleted) ...[
                          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          isCompleted ? 'COMPLETATO' : 'AVVIA ALLENAMENTO',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => showCoopModal(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.people_rounded, size: 20, color: Colors.white),
                      SizedBox(width: 8),
                      Text('CO-OP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

  String _streakDisplay() {
    if (widget.streak >= 7) {
      return '${widget.streak ~/ 7}';
    }
    return '${widget.streak}';
  }

  String _streakLabel() {
    if (widget.streak >= 7) {
      return widget.streak ~/ 7 == 1 ? 'SETTIMANA DI\nSERIE' : 'SETTIMANE DI\nSERIE';
    }
    return widget.streak == 1 ? 'GIORNO DI\nSERIE' : 'GIORNI DI\nSERIE';
  }

  String _nextGoal() {
    const milestones = [3, 7, 14, 21, 30, 60, 90, 180, 365];
    final next = milestones.cast<int?>().firstWhere((m) => m! > widget.streak, orElse: () => null);
    final target = next ?? (widget.streak + 30);
    final remaining = target - widget.streak;
    return '$remaining GIORNI';
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
                  _lucideFlame.replaceAll('currentColor', '#F97316'),
                  width: 34,
                  height: 34,
                ),
              ),
              const SizedBox(width: 14),
              // Large streak number
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFB923C), Color(0xFFF87171), Color(0xFFFB923C)],
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
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFB923C),
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
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFB923C),
                ),
              ),
            ],
          ),
        ],
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
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (latestUrl != null && latestUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
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
                                  color: Colors.black.withValues(alpha: 0.55),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'PROGRESSI',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1.0),
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
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey[500],
            letterSpacing: 1.0,
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
                      separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
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
                                  Icon(icon, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    typeLabel,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.5),
                                  ),
                                  const Spacer(),
                                  if (cals > 0)
                                    Text(
                                      '$cals kcal',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600),
                                    ),
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
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'DIETA',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
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
                    style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w600, letterSpacing: 1.0),
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
          color: Colors.white.withValues(alpha: 0.1),
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
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
              color: const Color(0xFF84CC16).withValues(alpha: 0.2),
            ),
            child: const Icon(Icons.emoji_events_rounded, size: 20, color: Color(0xFFA3E635)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sfide Giornaliere & Classifiche',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                SizedBox(height: 2),
                Text(
                  'Completa sfide per guadagnare gemme',
                  style: TextStyle(fontSize: 10, color: AppColors.textTertiary),
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
