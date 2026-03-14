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
              color: const Color(0xFF1A1E2A),
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final navBarTotal = 72.0 + bottomPadding;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Quick Actions',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return Stack(
          children: [
            // Blurred background (stops above nav bar)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: navBarTotal,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 8 * curved.value,
                    sigmaY: 8 * curved.value,
                  ),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3 * curved.value),
                  ),
                ),
              ),
            ),
            // Actions sliding up above nav bar
            Positioned(
              left: 16,
              right: 16,
              bottom: navBarTotal + 12,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(curved),
                child: FadeTransition(
                  opacity: curved,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1E2A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _QuickAction(
                            icon: Icons.qr_code_scanner_rounded,
                            label: 'Scansiona QR',
                            onTap: () {
                              Navigator.pop(ctx);
                              onFabAction?.call('qr');
                            },
                          ),
                          _QuickAction(
                            icon: Icons.camera_alt_rounded,
                            label: 'Scansiona Pasto',
                            onTap: () {
                              Navigator.pop(ctx);
                              onFabAction?.call('meal_scan');
                            },
                          ),
                          _QuickAction(
                            icon: Icons.photo_camera_front_rounded,
                            label: 'Foto Fisico',
                            onTap: () {
                              Navigator.pop(ctx);
                              onFabAction?.call('physique_photo');
                            },
                          ),
                          _QuickAction(
                            icon: Icons.monitor_weight_rounded,
                            label: 'Registra Peso',
                            onTap: () {
                              Navigator.pop(ctx);
                              onFabAction?.call('log_weight');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _QuickAction(
              icon: Icons.calendar_month_rounded,
              label: 'Prenota Appuntamento',
              onTap: () {
                Navigator.pop(ctx);
                onFabAction?.call('book_appointment');
              },
            ),
          ],
        );
      },
      pageBuilder: (ctx, _, _) => const SizedBox.shrink(),
    );
  }
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

  const _FabButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryHover],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(label, style: const TextStyle(color: AppColors.textPrimary)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
