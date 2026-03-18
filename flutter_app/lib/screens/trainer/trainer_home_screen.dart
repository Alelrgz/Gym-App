import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

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

    if (isDesktop) {
      return Scaffold(
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
    }

    // ── Mobile: Bottom Nav ─────────────────────────────
    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: _MobileBottomNav(
        currentIndex: navIndex,
        onTap: goTo,
      ),
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
                SvgPicture.asset('assets/fitos-logo.svg', height: 36),
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
          duration: const Duration(milliseconds: 200),
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
