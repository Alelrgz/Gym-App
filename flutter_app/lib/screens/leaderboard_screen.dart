import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/client_provider.dart';
import '../widgets/dashboard_sheets.dart';
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  Timer? _countdownTimer;
  String _countdown = '';
  bool _questsExpanded = true;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) => _updateCountdown());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final dayOfWeek = now.weekday; // 1=Mon .. 7=Sun
    int daysUntilMonday = (8 - dayOfWeek) % 7;
    if (daysUntilMonday == 0) daysUntilMonday = 7;
    final nextMonday = DateTime(now.year, now.month, now.day + daysUntilMonday);
    final diff = nextMonday.difference(now);
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    if (mounted) setState(() => _countdown = '${days}d ${hours}h ${minutes}m');
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final clientAsync = ref.watch(clientDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: leaderboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Errore: $e', style: const TextStyle(color: AppColors.danger))),
        data: (data) {
          final users = (data['users'] as List<dynamic>?) ?? [];
          final challenge = data['weekly_challenge'] as Map<String, dynamic>? ?? {};
          final league = data['league'] as Map<String, dynamic>? ?? {};
          final currentTier = league['current_tier'] as Map<String, dynamic>? ?? {};
          final allTiers = (league['all_tiers'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          final advanceCount = league['advance_count'] as int? ?? 10;

          // Gems from client data
          final gems = clientAsync.valueOrNull?.gems ?? 0;
          // Daily quests from client data (raw JSON)

          return CustomScrollView(
            slivers: [
              // ── Header ──
              SliverToBoxAdapter(child: _buildHeader(context, gems)),
              // ── League Tiers ──
              SliverToBoxAdapter(child: _buildLeagueTiers(allTiers, currentTier)),
              // ── League Name + Subtitle ──
              SliverToBoxAdapter(child: _buildLeagueInfo(currentTier, allTiers, users.length, advanceCount)),
              // ── Countdown ──
              SliverToBoxAdapter(child: _buildCountdown()),
              // ── Weekly Challenge ──
              SliverToBoxAdapter(child: _buildWeeklyChallenge(challenge)),
              // ── Rankings Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text(
                    'CLASSIFICHE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[500],
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              // ── Rankings List ──
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildUserRow(users[index] as Map<String, dynamic>),
                    ),
                    childCount: users.length,
                  ),
                ),
              ),
              // ── Daily Quests ──
              SliverToBoxAdapter(child: _buildDailyQuestsSection()),
              // ── Bottom padding ──
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // HEADER
  // ════════════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context, int gems) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 54, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.canPop() ? context.pop() : context.go('/'),
            child: const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
            ),
          ),
          const Text('Classifica', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          const Spacer(),
          // Gem counter pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEAB308).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEAB308).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('\u{1F536}', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  '$gems',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFACC15)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Chat icon
          _headerIconButton(Icons.chat_bubble_outline_rounded, () {
            showConversationsSheet(context, ref);
          }),
          const SizedBox(width: 8),
          // Notification bell
          _headerIconButton(Icons.notifications_outlined, () {
            showNotificationsSheet(context, ref);
          }),
        ],
      ),
    );
  }

  Widget _headerIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // LEAGUE TIERS (5 badges)
  // ════════════════════════════════════════════════════════════════
  Widget _buildLeagueTiers(List<Map<String, dynamic>> allTiers, Map<String, dynamic> currentTier) {
    final tierIcons = [Icons.shield_outlined, Icons.shield_outlined, Icons.workspace_premium_rounded, Icons.diamond_outlined, Icons.diamond_rounded];
    final currentLevel = currentTier['level'] as int? ?? 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(allTiers.length, (idx) {
          final tier = allTiers[idx];
          final tierLevel = tier['level'] as int? ?? (idx + 1);
          final isCurrent = tierLevel == currentLevel;
          final isUnlocked = tierLevel <= currentLevel;
          final colorStr = tier['color'] as String? ?? '#D97706';
          final color = _hexToColor(colorStr);

          final size = isCurrent ? 56.0 : 40.0;
          final iconSize = isCurrent ? 24.0 : 16.0;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Opacity(
              opacity: isCurrent ? 1.0 : isUnlocked ? 0.7 : 0.25,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TierBadge(
                    size: size,
                    iconSize: iconSize,
                    icon: tierIcons[idx.clamp(0, tierIcons.length - 1)],
                    color: color,
                    isCurrent: isCurrent,
                  ),
                  if (isCurrent) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    tier['name'] as String? ?? '',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: isCurrent ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // LEAGUE INFO
  // ════════════════════════════════════════════════════════════════
  Widget _buildLeagueInfo(Map<String, dynamic> currentTier, List<Map<String, dynamic>> allTiers, int userCount, int advanceCount) {
    final tierName = currentTier['name'] as String? ?? 'Bronze';
    final tierLevel = currentTier['level'] as int? ?? 1;
    final effectiveAdvance = min(advanceCount, userCount);

    String subtitle;
    if (tierLevel >= 5) {
      subtitle = 'Hai raggiunto la lega piu alta!';
    } else {
      subtitle = 'I primi $effectiveAdvance avanzano alla lega successiva';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(
            '$tierName League',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // COUNTDOWN
  // ════════════════════════════════════════════════════════════════
  Widget _buildCountdown() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFEAB308)),
          const SizedBox(width: 6),
          Text(
            _countdown,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFEAB308)),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // WEEKLY CHALLENGE
  // ════════════════════════════════════════════════════════════════
  Widget _buildWeeklyChallenge(Map<String, dynamic> challenge) {
    final title = challenge['title'] as String? ?? 'Weekly Workout Challenge';
    final progress = challenge['progress'] as int? ?? 0;
    final target = challenge['target'] as int? ?? 5;
    final reward = challenge['reward_gems'] as int? ?? 200;
    final pct = target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: GlassDecoration.card(borderRadius: 16),
        child: Stack(
          children: [
            // Purple glow blob (top-right)
            Positioned(
              top: -32,
              right: -32,
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFA855F7).withValues(alpha: 0.1),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: label + reward
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.gps_fixed_rounded, size: 16, color: Colors.purple[300]),
                          const SizedBox(width: 8),
                          Text(
                            'SFIDA SETTIMANALE',
                            style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500, letterSpacing: 1.2),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text('$reward', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFACC15))),
                          const SizedBox(width: 4),
                          const Text('\u{1F536}', style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Challenge title
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 10),
                  // Progress bar + fraction
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: pct,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFA855F7), Color(0xFFEC4899)]),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$progress/$target',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // USER ROW
  // ════════════════════════════════════════════════════════════════
  Widget _buildUserRow(Map<String, dynamic> user) {
    final rank = user['rank'] as int? ?? 0;
    final name = user['name'] as String? ?? '';
    final streak = user['streak'] as int? ?? 0;
    final gems = user['gems'] as int? ?? 0;
    final isCurrentUser = user['isCurrentUser'] as bool? ?? false;
    final profilePic = user['profile_picture'] as String?;
    final userId = user['user_id']?.toString();

    return GestureDetector(
      onTap: !isCurrentUser && userId != null
          ? () => _openMemberProfile(userId, name, profilePic)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isCurrentUser ? 0.0 : 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrentUser
                ? const Color(0xFF84CC16).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
          ),
          // Lime background tint for current user
          gradient: isCurrentUser
              ? LinearGradient(colors: [
                  const Color(0xFF84CC16).withValues(alpha: 0.1),
                  const Color(0xFF84CC16).withValues(alpha: 0.05),
                ])
              : null,
        ),
        child: Row(
          children: [
            // Rank badge
            _buildRankBadge(rank),
            const SizedBox(width: 12),
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              clipBehavior: Clip.antiAlias,
              child: profilePic != null && profilePic.isNotEmpty
                  ? Image.network(profilePic, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _avatarFallback(name))
                  : _avatarFallback(name),
            ),
            const SizedBox(width: 12),
            // Name + streak
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCurrentUser ? '$name (Tu)' : name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isCurrentUser ? const Color(0xFFBEF264) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, size: 12, color: Color(0xFFFB923C)),
                      const SizedBox(width: 3),
                      Text('$streak', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
            ),
            // Gems
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('\u{1F536}', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Text(
                  '$gems',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFFACC15)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFEAB308).withValues(alpha: 0.2),
        ),
        child: const Icon(Icons.workspace_premium_rounded, size: 18, color: Color(0xFFFBBF24)),
      );
    } else if (rank == 2) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF9CA3AF).withValues(alpha: 0.2),
        ),
        child: const Icon(Icons.military_tech_rounded, size: 18, color: Color(0xFFD1D5DB)),
      );
    } else if (rank == 3) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFB45309).withValues(alpha: 0.2),
        ),
        child: const Icon(Icons.military_tech_rounded, size: 18, color: Color(0xFFD97706)),
      );
    } else {
      return SizedBox(
        width: 32,
        child: Center(
          child: Text(
            '$rank',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[600]),
          ),
        ),
      );
    }
  }

  Widget _avatarFallback(String name) {
    return Image.network(
      'https://api.dicebear.com/7.x/avataaars/svg?seed=$name',
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // DAILY QUESTS (collapsible)
  // ════════════════════════════════════════════════════════════════
  Widget _buildDailyQuestsSection() {
    // Get quests from the raw client data
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          // Header row (tap to collapse)
          GestureDetector(
            onTap: () => setState(() => _questsExpanded = !_questsExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, size: 16, color: Color(0xFFFB923C)),
                  const SizedBox(width: 8),
                  Text(
                    'SFIDE GIORNALIERE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[500],
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _QuestProgressBadge(),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _questsExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          // Quest list
          AnimatedCrossFade(
            firstChild: _QuestList(),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _questsExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // MEMBER PROFILE (bottom sheet)
  // ════════════════════════════════════════════════════════════════
  void _openMemberProfile(String userId, String name, String? profilePic) {
    showMemberProfileSheet(context, ref, userId);
  }

  static Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

// ════════════════════════════════════════════════════════════════
// TIER BADGE with pulsing glow animation
// ════════════════════════════════════════════════════════════════
class _TierBadge extends StatefulWidget {
  final double size;
  final double iconSize;
  final IconData icon;
  final Color color;
  final bool isCurrent;

  const _TierBadge({
    required this.size,
    required this.iconSize,
    required this.icon,
    required this.color,
    required this.isCurrent,
  });

  @override
  State<_TierBadge> createState() => _TierBadgeState();
}

class _TierBadgeState extends State<_TierBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    if (widget.isCurrent) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrent) {
      return _badge(14.0);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final glowRadius = 14.0 + _controller.value * 10.0;
        return _badge(glowRadius);
      },
    );
  }

  Widget _badge(double glowRadius) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.color.withValues(alpha: 0.3),
          width: widget.isCurrent ? 2 : 1,
        ),
        boxShadow: widget.isCurrent
            ? [BoxShadow(color: widget.color.withValues(alpha: 0.3), blurRadius: glowRadius, spreadRadius: 0)]
            : null,
      ),
      child: Icon(widget.icon, size: widget.iconSize, color: widget.color),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// AnimatedBuilder helper (AnimatedWidget wrapper)
// ════════════════════════════════════════════════════════════════
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) => builder(context, null);
}

// ════════════════════════════════════════════════════════════════
// QUEST PROGRESS BADGE
// ════════════════════════════════════════════════════════════════
class _QuestProgressBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We need raw JSON to get daily_quests - use a separate raw provider
    final raw = ref.watch(_rawClientDataProvider);
    final quests = raw.valueOrNull ?? [];
    final completed = quests.where((q) => q['completed'] == true).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF97316).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$completed/${quests.length}',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFFB923C)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// QUEST LIST
// ════════════════════════════════════════════════════════════════
class _QuestList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raw = ref.watch(_rawClientDataProvider);
    return raw.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Errore caricamento sfide', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      ),
      data: (quests) {
        if (quests.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Nessuna sfida oggi', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          );
        }
        return Column(
          children: List.generate(quests.length, (index) {
            final quest = quests[index];
            return _QuestRow(quest: quest, index: index);
          }),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// QUEST ROW
// ════════════════════════════════════════════════════════════════
class _QuestRow extends ConsumerStatefulWidget {
  final Map<String, dynamic> quest;
  final int index;

  const _QuestRow({required this.quest, required this.index});

  @override
  ConsumerState<_QuestRow> createState() => _QuestRowState();
}

class _QuestRowState extends ConsumerState<_QuestRow> {
  late bool _completed;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _completed = widget.quest['completed'] as bool? ?? false;
  }

  @override
  void didUpdateWidget(_QuestRow old) {
    super.didUpdateWidget(old);
    _completed = widget.quest['completed'] as bool? ?? false;
  }

  Future<void> _toggle() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final service = ref.read(clientServiceProvider);
      await service.toggleQuest(widget.index);
      setState(() => _completed = !_completed);
      // Refresh data
      ref.invalidate(_rawClientDataProvider);
      ref.invalidate(clientDataProvider);
      ref.invalidate(leaderboardProvider);
    } catch (e) {
      // Ignore errors
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.quest['text'] as String? ?? '';
    final xp = widget.quest['xp'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: _toggle,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _completed
                  ? const Color(0xFFF97316).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              // Checkbox
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _completed ? const Color(0xFFF97316) : Colors.transparent,
                  border: _completed ? null : Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: _completed
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              // Quest text
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[300]),
                ),
              ),
              // XP badge
              Text(
                '+$xp',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFF97316)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// RAW CLIENT DATA PROVIDER (for daily_quests)
// ════════════════════════════════════════════════════════════════
final _rawClientDataProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.read(clientServiceProvider);
  // We need the raw response, not the parsed ClientProfile
  final api = service.api;
  final response = await api.get('/api/client/data');
  final data = response.data as Map<String, dynamic>;
  final quests = data['daily_quests'] as List<dynamic>? ?? [];
  return quests.cast<Map<String, dynamic>>();
});

