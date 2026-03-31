import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../providers/client_provider.dart';
import '../providers/websocket_provider.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/dashboard_sheets.dart';
import 'dashboard_screen.dart';
import 'diet_screen.dart';
import 'community_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const HomeScreen({super.key, required this.navigationShell});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription? _coopInviteSub;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.navigationShell.currentIndex);
    // Ensure WebSocket is connected
    final ws = ref.read(websocketServiceProvider);
    ws.connect();

    // Listen for incoming CO-OP invites
    _coopInviteSub = ws.coopInvites.listen((msg) {
      if (!mounted) return;
      final fromId = msg['from_id']?.toString() ?? '';
      final fromName = msg['from_name']?.toString() ?? '';
      final fromPic = msg['from_picture']?.toString();
      _showCoopInviteDialog(fromId, fromName, fromPic);
    });
  }

  int get _currentPage => _pageController.hasClients ? (_pageController.page?.round() ?? 0) : 0;

@override
  void dispose() {
    _coopInviteSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _showCoopInviteDialog(String fromId, String fromName, String? fromPic) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.2),
              backgroundImage: fromPic != null
                  ? NetworkImage(fromPic.startsWith('http') ? fromPic : '${ApiConfig.baseUrl}$fromPic')
                  : null,
              child: fromPic == null
                  ? const Icon(Icons.person, size: 36, color: Color(0xFF7C3AED))
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              '$fromName vuole allenarsi con te!',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Allenamento CO-OP',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      final ws = ref.read(websocketServiceProvider);
                      ws.sendCoopDecline(fromId);
                      ref.read(coopProvider.notifier).reset();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: const Center(
                        child: Text('Rifiuta', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      final ws = ref.read(websocketServiceProvider);
                      ws.sendCoopAccept(fromId);
                      ref.read(coopProvider.notifier).setActive(fromId, fromName, fromPic);
                      // Navigate to workout with CO-OP params
                      final params = 'partner_id=$fromId&partner_name=${Uri.encodeComponent(fromName)}'
                          '${fromPic != null ? '&partner_picture=${Uri.encodeComponent(fromPic)}' : ''}';
                      context.go('/workouts?$params');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('Accetta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhysiquePhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Foto Fisico',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.primary),
                title: const Text('Scatta Foto',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
                title: const Text('Galleria',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty || !mounted) return;

    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await ref.read(clientServiceProvider).uploadPhysiquePhotoBytes(
        bytes: bytes,
        fileName: 'physique_$dateStr.jpg',
        mimeType: 'image/jpeg',
        photoDate: dateStr,
      );
      if (mounted) showSnack(context, 'Foto fisico salvata!');
    } catch (e) {
      if (mounted) showSnack(context, 'Errore nel salvare la foto', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    void onNavTap(int navIdx) {
      const navToPage = [0, 1, 2, 4];
      _pageController.animateToPage(navToPage[navIdx], duration: AppAnim.medium, curve: AppAnim.pageCurve);
    }

    void onFabAction(String action) {
      switch (action) {
        case 'qr':
          showQrAccessDialog(context, ref);
          break;
        case 'meal_scan':
          ref.read(pendingMealScanProvider.notifier).state = true;
          context.go('/diet');
          break;
        case 'physique_photo':
          _takePhysiquePhoto();
          break;
        case 'log_weight':
          showLogWeightDialog(context, ref);
          break;
        case 'book_appointment':
          showBookAppointmentSheet(context, ref);
          break;
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // If not on first page, go to first page
        if (_currentPage != 0) {
          _pageController.animateToPage(0, duration: AppAnim.medium, curve: AppAnim.pageCurve);
          return;
        }
        // On first tab: show exit confirmation
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1024;

          if (isDesktop) {
            return Scaffold(
              backgroundColor: AppColors.background,
              body: Row(
                children: [
                  // Left sidebar
                  _DesktopSidebar(
                    currentIndex: _currentPage.clamp(0, 3),
                    onTap: (idx) {
                      _pageController.animateToPage(idx, duration: AppAnim.medium, curve: AppAnim.pageCurve);
                    },
                    onFabAction: onFabAction,
                  ),
                  // Main content
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 1, color: Colors.white.withValues(alpha: 0.04)),
                          SizedBox(
                            width: 640,
                            child: Column(
                              children: [
                                _PersistentTopBar(pageController: _pageController),
                                Expanded(
                                  child: PageView(
                                    controller: _pageController,
                                    allowImplicitScrolling: true,
                                    onPageChanged: (index) {
                                      setState(() {});
                                      widget.navigationShell.goBranch(index, initialLocation: index == widget.navigationShell.currentIndex);
                                    },
                                    children: [
                                      _KeepAlivePage(child: const DashboardScreen()),
                                      _KeepAlivePage(child: const DietScreen()),
                                      _KeepAlivePage(child: const CommunityScreen()),
                                      _KeepAlivePage(child: const ProfileScreen()),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, color: Colors.white.withValues(alpha: 0.04)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Mobile layout (unchanged)
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Column(
              children: [
                _PersistentTopBar(pageController: _pageController),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    allowImplicitScrolling: true,
                    onPageChanged: (index) {
                      setState(() {});
                      widget.navigationShell.goBranch(index, initialLocation: index == widget.navigationShell.currentIndex);
                    },
                    children: [
                      _KeepAlivePage(child: const DashboardScreen()),
                      _KeepAlivePage(child: const DietScreen()),
                      _KeepAlivePage(child: const CommunityScreen()),
                      _KeepAlivePage(child: const ProfileScreen()),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: AppBottomNav(
              currentIndex: _currentPage.clamp(0, 3),
              onTap: (navIdx) {
                _pageController.animateToPage(navIdx, duration: AppAnim.medium, curve: AppAnim.pageCurve);
              },
              onFabAction: onFabAction,
            ),
          );
        },
      ),
    );
  }
}

/// Keeps a page alive in PageView so it doesn't rebuild when swiped away.
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ─── DESKTOP SIDEBAR ────────────────────────────────────────────

class _DesktopSidebar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final ValueChanged<String>? onFabAction;

  const _DesktopSidebar({
    required this.currentIndex,
    required this.onTap,
    this.onFabAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Logo
            Image.asset('assets/heavens-hand.png', height: 26),
            const SizedBox(height: 32),
            // Nav items
            _SidebarIcon(icon: Icons.home_rounded, label: 'Home',
                isActive: currentIndex == 0, onTap: () => onTap(0)),
            const SizedBox(height: 4),
            _SidebarIcon(icon: Icons.restaurant_rounded, label: 'Dieta',
                isActive: currentIndex == 1, onTap: () => onTap(1)),
            const SizedBox(height: 4),
            _SidebarIcon(icon: Icons.forum_rounded, label: 'Community',
                isActive: currentIndex == 2, onTap: () => onTap(2)),
            const SizedBox(height: 4),
            _SidebarIcon(icon: Icons.person_rounded, label: 'Profilo',
                isActive: currentIndex == 3, onTap: () => onTap(3)),
            const Spacer(),
            // Quick actions (no access button on desktop)
            _SidebarIcon(icon: Icons.calendar_month_rounded, label: 'Prenota',
                isActive: false, isAction: true,
                onTap: () => onFabAction?.call('book_appointment')),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SidebarIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isAction;
  final VoidCallback onTap;

  const _SidebarIcon({
    required this.icon,
    required this.label,
    required this.isActive,
    this.isAction = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22,
                color: isActive ? AppColors.primary
                    : isAction ? Colors.grey[500]
                    : Colors.grey[600]),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.primary : Colors.grey[600],
                )),
          ],
        ),
      ),
    );
  }
}

// ─── PERSISTENT TOP BAR ─────────────────────────────────────────

class _PersistentTopBar extends ConsumerWidget {
  final PageController pageController;
  const _PersistentTopBar({required this.pageController});

  int get _currentPage => pageController.hasClients ? (pageController.page?.round() ?? 0) : 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hide on profile page (index 3)
    if (_currentPage == 3) return const SizedBox.shrink();

    final unreadMessages = ref.watch(unreadMessagesProvider);
    final unreadNotifications = ref.watch(unreadNotificationsProvider);
    final top = MediaQuery.of(context).padding.top;

    final isDesktop = MediaQuery.of(context).size.width > 1024;

    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(top: isDesktop ? 10 : top + 10, left: 20, right: 20, bottom: 6),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Image.asset('assets/heavens-hand.png', height: isDesktop ? 28 : 30),
            const Spacer(),
            if (!isDesktop)
              _TopIcon(
                icon: Icons.login_rounded,
                onTap: () => showQrAccessDialog(context, ref),
              ),
            if (!isDesktop) const SizedBox(width: 8),
            _TopIconBadge(
              icon: Icons.notifications_none_rounded,
              count: unreadNotifications.valueOrNull ?? 0,
              onTap: () => showNotificationsSheet(context, ref),
            ),
            const SizedBox(width: 8),
            _TopIconBadge(
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

class _TopIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5),
        ),
        child: Icon(icon, size: 19, color: AppColors.textSecondary),
      ),
    );
  }
}

class _TopIconBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  const _TopIconBadge({required this.icon, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.5),
              ),
              child: Icon(icon, size: 19, color: AppColors.textSecondary),
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
