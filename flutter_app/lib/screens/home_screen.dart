import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../providers/client_provider.dart';
import '../providers/websocket_provider.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/dashboard_sheets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const HomeScreen({super.key, required this.navigationShell});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription? _coopInviteSub;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _coopInviteSub?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final navIndex = widget.navigationShell.currentIndex;

    void onNavTap(int index) {
      widget.navigationShell.goBranch(index, initialLocation: index == widget.navigationShell.currentIndex);
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
          showSnack(context, 'Foto fisico — Prossimamente');
          break;
        case 'log_weight':
          showLogWeightDialog(context, ref);
          break;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: widget.navigationShell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: navIndex,
        onTap: onNavTap,
        onFabAction: onFabAction,
      ),
    );
  }
}
