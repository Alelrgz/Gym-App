import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../config/api_config.dart';

const double _kDesktopBreakpoint = 1024;
const double _kSidebarWidth = 200;

class StaffHomeScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const StaffHomeScreen({super.key, required this.navigationShell});

  static const _navItems = [
    (icon: Icons.calendar_today_rounded, label: 'Prenotazioni'),
    (icon: Icons.people_rounded, label: 'Utenti'),
    (icon: Icons.description_rounded, label: 'Documenti'),
    (icon: Icons.settings_rounded, label: 'Impostazioni'),
  ];

  @override
  ConsumerState<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends ConsumerState<StaffHomeScreen> {
  Timer? _notifTimer;

  @override
  void initState() {
    super.initState();
    // Only poll on mobile — desktop doesn't need to receive push-to-phone notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final width = MediaQuery.of(context).size.shortestSide;
      if (width < 600) {
        _notifTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkForActionableNotifications());
      }
    });
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkForActionableNotifications() async {
    try {
      final api = ref.read(apiClientProvider);
      debugPrint('[StaffNotifPoll] Checking...');
      final response = await api.get('${ApiConfig.notifications}?limit=5');
      final notifications = response.data as List? ?? [];

      for (final n in notifications) {
        final notif = n as Map<String, dynamic>;
        if (notif['type'] == 'send_credentials_link' && notif['read'] != true) {
          final rawData = notif['data'];
          if (rawData == null) continue;

          final Map<String, dynamic> data;
          if (rawData is Map) {
            data = Map<String, dynamic>.from(rawData);
          } else {
            data = jsonDecode(rawData.toString()) as Map<String, dynamic>;
          }
          final link = data['link']?.toString();
          final method = data['method']?.toString() ?? '';
          final clientName = data['client_name']?.toString() ?? 'cliente';

          if (link == null || link.isEmpty) continue;

          // Mark as read immediately so we don't show it again
          final notifId = notif['id']?.toString();
          if (notifId != null) {
            await api.post(ApiConfig.notificationRead(notifId));
          }

          if (!mounted) return;

          // Show a prominent overlay dialog — impossible to miss
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (ctx) {
              // Auto-dismiss after 15 seconds
              Future.delayed(const Duration(seconds: 15), () {
                if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
              });
              return AlertDialog(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      method == 'whatsapp' ? Icons.chat : Icons.sms_rounded,
                      color: method == 'whatsapp' ? const Color(0xFF25D366) : const Color(0xFF60A5FA),
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Invia credenziali a $clientName',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      method == 'whatsapp' ? 'Tocca per aprire WhatsApp' : 'Tocca per aprire SMS',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          final uri = Uri.parse(link);
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                        icon: Icon(method == 'whatsapp' ? Icons.open_in_new : Icons.sms_rounded, size: 18),
                        label: Text(method == 'whatsapp' ? 'Apri WhatsApp' : 'Apri SMS'),
                        style: FilledButton.styleFrom(
                          backgroundColor: method == 'whatsapp' ? const Color(0xFF25D366) : const Color(0xFF60A5FA),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
          return; // Handle one at a time
        }
      }
    } catch (e) {
      debugPrint('[StaffNotifPoll] Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final navIndex = widget.navigationShell.currentIndex;
    final isDesktop =
        MediaQuery.of(context).size.width > _kDesktopBreakpoint;

    void goTo(int i) =>
        widget.navigationShell.goBranch(i, initialLocation: i == navIndex);

    Widget scaffold;
    if (isDesktop) {
      scaffold = Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            _DesktopSidebar(
              currentIndex: navIndex,
              onTap: goTo,
              onLogout: () => ref.read(authProvider.notifier).logout(),
            ),
            Expanded(child: widget.navigationShell),
          ],
        ),
      );
    } else {
      scaffold = Scaffold(
        backgroundColor: AppColors.background,
        body: widget.navigationShell,
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
          widget.navigationShell.goBranch(0, initialLocation: true);
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
//  DESKTOP SIDEBAR
// ═══════════════════════════════════════════════════════════
class _DesktopSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onLogout;

  const _DesktopSidebar({
    required this.currentIndex,
    required this.onTap,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kSidebarWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Column(
              children: [
                SvgPicture.asset('assets/fitos-logo.svg', height: 36),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Staff',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: List.generate(StaffHomeScreen._navItems.length, (i) {
                final item = StaffHomeScreen._navItems[i];
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
    final inactiveColor = widget.color?.withValues(alpha: 0.6) ??
        Colors.white.withValues(alpha: 0.5);

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
              color: widget.isActive
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon,
                  size: 18,
                  color: widget.isActive
                      ? activeColor
                      : _hovering
                          ? activeColor.withValues(alpha: 0.85)
                          : inactiveColor),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.isActive
                      ? activeColor
                      : _hovering
                          ? activeColor.withValues(alpha: 0.85)
                          : inactiveColor,
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
//  MOBILE BOTTOM NAV
// ═══════════════════════════════════════════════════════════
class _MobileBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _MobileBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children:
                List.generate(StaffHomeScreen._navItems.length, (i) {
              final item = StaffHomeScreen._navItems[i];
              final isActive = i == currentIndex;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon,
                          size: 24,
                          color: isActive
                              ? AppColors.primary
                              : Colors.grey[600]),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive
                              ? AppColors.primary
                              : Colors.grey[600],
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
