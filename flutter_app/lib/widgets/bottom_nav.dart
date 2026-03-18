import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Callback type for FAB quick actions.
/// action is one of: 'qr', 'meal_scan', 'physique_photo', 'log_weight'
typedef FabActionCallback = void Function(String action);

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final FabActionCallback? onFabAction;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onFabAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  isActive: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
                _NavItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart_rounded,
                  label: 'Stats',
                  isActive: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
                _FabButton(onTap: () => _showQuickActions(context)),
                _NavItem(
                  icon: Icons.forum_outlined,
                  activeIcon: Icons.forum_rounded,
                  label: 'Community',
                  isActive: currentIndex == 2,
                  onTap: () => onTap(2),
                ),
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profilo',
                  isActive: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQuickActions(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Quick Actions',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        final fadeCurved = CurvedAnimation(parent: anim, curve: Curves.easeOut);

        final actions = <_FabActionData>[
          _FabActionData(Icons.camera_alt_rounded, 'Pasto', 'meal_scan'),
          _FabActionData(Icons.photo_camera_front_rounded, 'Fisico', 'physique_photo'),
          _FabActionData(Icons.qr_code_scanner_rounded, 'QR', 'qr'),
          _FabActionData(Icons.monitor_weight_rounded, 'Peso', 'log_weight'),
          _FabActionData(Icons.calendar_month_rounded, 'Prenota', 'book_appointment'),
        ];

        // Evenly spaced horizontally, gentle arc upward
        const double itemSize = 56;
        final double margin = 40.0;
        final double usableWidth = screenWidth - margin * 2 - itemSize;
        final double spacing = usableWidth / (actions.length - 1);
        // Base height above nav bar top
        const double baseY = 90.0;
        const double arcHeight = 30.0;

        return Stack(
          children: [
            // Blurred dimmed background
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: AnimatedBuilder(
                  animation: fadeCurved,
                  builder: (_, __) => BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 14 * fadeCurved.value,
                      sigmaY: 14 * fadeCurved.value,
                    ),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5 * fadeCurved.value),
                    ),
                  ),
                ),
              ),
            ),
            // Arc items — evenly spaced horizontally, parabolic curve
            ...List.generate(actions.length, (i) {
              // t goes from 0 to 1 across items
              final t = i / (actions.length - 1);
              // Parabola: peaks at center (t=0.5), zero at edges
              final arcOffset = arcHeight * 4 * t * (1 - t);
              final y = baseY + arcOffset;

              final delay = i * 0.06;
              final itemAnim = CurvedAnimation(
                parent: anim,
                curve: Interval(delay, 1.0, curve: Curves.easeOutBack),
              );
              final action = actions[i];

              return Positioned(
                left: margin + spacing * i,
                bottom: (y * itemAnim.value) + bottomPadding,
                child: AnimatedBuilder(
                  animation: itemAnim,
                  builder: (_, __) => Opacity(
                    opacity: itemAnim.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: itemAnim.value,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          onFabAction?.call(action.actionId);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Icon(action.icon, color: Colors.white, size: 24),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              action.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            // Nav bar on top
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                color: Colors.transparent,
                child: SafeArea(
                  top: false,
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF181818),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', isActive: currentIndex == 0, onTap: () { Navigator.pop(ctx); onTap(0); }),
                        _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, label: 'Stats', isActive: currentIndex == 1, onTap: () { Navigator.pop(ctx); onTap(1); }),
                        AnimatedBuilder(
                          animation: curved,
                          builder: (_, __) => _FabButton(
                            onTap: () => Navigator.pop(ctx),
                            rotation: curved.value,
                          ),
                        ),
                        _NavItem(icon: Icons.forum_outlined, activeIcon: Icons.forum_rounded, label: 'Community', isActive: currentIndex == 2, onTap: () { Navigator.pop(ctx); onTap(2); }),
                        _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profilo', isActive: currentIndex == 3, onTap: () { Navigator.pop(ctx); onTap(3); }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      pageBuilder: (ctx, _, __) => const SizedBox.shrink(),
    );
  }

}

class _FabActionData {
  final IconData icon;
  final String label;
  final String actionId;
  const _FabActionData(this.icon, this.label, this.actionId);
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 28,
              color: isActive ? AppColors.primary : Colors.white.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 4),
            Text(
              label,
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
  }
}

class _FabButton extends StatelessWidget {
  final VoidCallback onTap;
  final double rotation;

  const _FabButton({required this.onTap, this.rotation = 0});

  @override
  Widget build(BuildContext context) {
    final isOpen = rotation > 0;
    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: rotation * 0.785398, // 45 degrees in radians
        child: Container(
          width: isOpen ? 44 : 52,
          height: isOpen ? 44 : 52,
          decoration: BoxDecoration(
            gradient: isOpen
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryHover],
                  ),
            color: isOpen ? Colors.white.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(isOpen ? 14 : 16),
          ),
          child: Icon(Icons.add_rounded, color: Colors.white, size: isOpen ? 26 : 30),
        ),
      ),
    );
  }
}

