import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/client_provider.dart';
import '../../widgets/dashboard_sheets.dart';

const double _kDesktopBreakpoint = 1024;
const double _kSidebarWidth = 200;

class TrainerHomeScreen extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const TrainerHomeScreen({super.key, required this.navigationShell});

  static const _navItems = [
    (icon: Icons.people_rounded, activeIcon: Icons.people_rounded, label: 'Utenti'),
    (icon: Icons.fitness_center_outlined, activeIcon: Icons.fitness_center_rounded, label: 'Allenamenti'),
    (icon: Icons.school_outlined, activeIcon: Icons.school_rounded, label: 'Corsi'),
    (icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month_rounded, label: 'Agenda'),
    (icon: Icons.forum_outlined, activeIcon: Icons.forum_rounded, label: 'Community'),
  ];

  /// Items only shown on desktop sidebar (includes settings).
  static const _desktopNavItems = [
    (icon: Icons.people_rounded, label: 'Utenti'),
    (icon: Icons.fitness_center_rounded, label: 'Allenamenti'),
    (icon: Icons.school_rounded, label: 'Corsi'),
    (icon: Icons.calendar_month_rounded, label: 'Agenda'),
    (icon: Icons.forum_rounded, label: 'Community'),
    (icon: Icons.settings_rounded, label: 'Impostazioni'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = navigationShell.currentIndex;
    final isDesktop = MediaQuery.of(context).size.width > _kDesktopBreakpoint;

    void goTo(int i) => navigationShell.goBranch(i, initialLocation: i == navIndex);

    Widget scaffold;
    if (isDesktop) {
      scaffold = Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            // ── Desktop Sidebar ────────────────────────
            _DesktopSidebar(
              currentIndex: navIndex,
              onTap: goTo,
              onLogout: () => ref.read(authProvider.notifier).logout(),
            ),
            // ── Main Content ───────────────────────────
            Expanded(child: navigationShell),
          ],
        ),
      );
    } else {
      // ── Mobile: Bottom Nav ─────────────────────────────
      scaffold = Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _ProfessionalTopBar(),
            Expanded(child: navigationShell),
          ],
        ),
        bottomNavigationBar: _MobileBottomNav(
          currentIndex: navIndex,
          onTap: goTo,
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (navIndex != 0) {
          navigationShell.goBranch(0, initialLocation: true);
          return;
        }
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Chiudi app?', style: TextStyle(color: AppColors.textPrimary)),
            content: const Text('Vuoi uscire dall\'app?', style: TextStyle(color: AppColors.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('No', style: TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  SystemNavigator.pop();
                },
                child: const Text('Sì', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
      child: scaffold,
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  DESKTOP SIDEBAR (200px, sticky, full height)
// ═══════════════════════════════════════════════════════════
class _DesktopSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onLogout;

  const _DesktopSidebar({required this.currentIndex, required this.onTap, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kSidebarWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Column(
        children: [
          // ── Logo / Brand ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Column(
              children: [
                SvgPicture.asset('assets/heavens-fit-logo.svg', height: 36),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Trainer',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Nav Items ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: List.generate(TrainerHomeScreen._desktopNavItems.length, (i) {
                final item = TrainerHomeScreen._desktopNavItems[i];
                final isActive = i == currentIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _SidebarNavItem(
                    icon: item.icon,
                    label: item.label,
                    isActive: isActive,
                    onTap: () => onTap(i),
                  ),
                );
              }),
            ),
          ),

          const Spacer(),

          // ── Logout ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            child: _SidebarNavItem(
              icon: Icons.logout_rounded,
              label: 'Esci',
              isActive: false,
              color: const Color(0xFFF87171),
              onTap: onLogout,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color? color;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.color,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? Colors.white;
    final inactiveColor = widget.color?.withValues(alpha: 0.6) ?? Colors.white.withValues(alpha: 0.5);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppAnim.fast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? Colors.white.withValues(alpha: 0.06)
                : _hovering
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isActive ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: widget.isActive ? activeColor : _hovering ? activeColor.withValues(alpha: 0.85) : inactiveColor),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.isActive ? activeColor : _hovering ? activeColor.withValues(alpha: 0.85) : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  MOBILE BOTTOM NAV (matches client AppBottomNav style)
// ═══════════════════════════════════════════════════════════
class _MobileBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _MobileBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1E2A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(TrainerHomeScreen._navItems.length, (i) {
              final item = TrainerHomeScreen._navItems[i];
              final isActive = i == currentIndex;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isActive ? item.activeIcon : item.icon,
                        size: 28,
                        color: isActive ? AppColors.primary : Colors.white.withValues(alpha: 0.45),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive ? AppColors.primary : Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── PROFESSIONAL TOP BAR (shared by trainer & nutritionist) ────

class _ProfessionalTopBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadMessages = ref.watch(unreadMessagesProvider);
    final unreadNotifications = ref.watch(unreadNotificationsProvider);
    final top = MediaQuery.of(context).padding.top;

    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(top: top + 10, left: 20, right: 20, bottom: 6),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Image.asset('assets/heavens-hand.png', height: 30),
            const Spacer(),
            _TopBarIcon(
              icon: Icons.notifications_none_rounded,
              count: unreadNotifications.valueOrNull ?? 0,
              onTap: () => showNotificationsSheet(context, ref),
            ),
            const SizedBox(width: 8),
            _TopBarIcon(
              icon: Icons.send_rounded,
              count: unreadMessages.valueOrNull ?? 0,
              onTap: () => showConversationsSheet(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBarIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  const _TopBarIcon({required this.icon, this.count = 0, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
            ),
            child: Icon(icon, size: 19, color: AppColors.textSecondary),
          ),
          if (count > 0)
            Positioned(
              top: -2, right: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: Text('$count',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
