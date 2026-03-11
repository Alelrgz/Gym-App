import 'dart:math' show pi, min;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../models/diet_data.dart';
import '../providers/client_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/dashboard_sheets.dart';
import '../widgets/camera_scanner.dart';

// ─── Meal type metadata ──────────────────────────────────────────

String _mealEmoji(String type) => switch (type) {
  'colazione' => '\u{1F305}',
  'spuntino_mattina' => '\u{1F34E}',
  'pranzo' => '\u{1F35D}',
  'spuntino_pomeriggio' => '\u{1F964}',
  'cena' => '\u{1F319}',
  _ => '\u{1F37D}',
};

Color _mealColor(String type) => switch (type) {
  'colazione' => const Color(0xFFFBBF24),
  'spuntino_mattina' => const Color(0xFF34D399),
  'pranzo' => const Color(0xFFF97316),
  'spuntino_pomeriggio' => const Color(0xFF818CF8),
  'cena' => const Color(0xFF60A5FA),
  _ => Colors.grey,
};

String _mealLabel(String type) => switch (type) {
  'colazione' => 'Colazione',
  'spuntino_mattina' => 'Spuntino Mattina',
  'pranzo' => 'Pranzo',
  'spuntino_pomeriggio' => 'Merenda',
  'cena' => 'Cena',
  _ => type,
};

const _typeOrder = ['colazione', 'spuntino_mattina', 'pranzo', 'spuntino_pomeriggio', 'cena'];

String _fullDayName(int dayIndex) => switch (dayIndex) {
  0 => 'Lunedì', 1 => 'Martedì', 2 => 'Mercoledì', 3 => 'Giovedì',
  4 => 'Venerdì', 5 => 'Sabato', 6 => 'Domenica', _ => '',
};

// ─── MAIN SCREEN ─────────────────────────────────────────────────

class DietScreen extends ConsumerStatefulWidget {
  const DietScreen({super.key});
  @override
  ConsumerState<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends ConsumerState<DietScreen> {
  int _selectedDay = DateTime.now().weekday - 1;
  int _heroPage = 0;

  @override
  void initState() {
    super.initState();
    // Check for pending meal scan from FAB action
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(pendingMealScanProvider)) {
        ref.read(pendingMealScanProvider.notifier).state = false;
        _scanMeal(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final clientData = ref.watch(clientDataProvider);
    final unreadMessages = ref.watch(unreadMessagesProvider);
    final unreadNotifications = ref.watch(unreadNotificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: clientData.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, s) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              const Text('Errore nel caricamento', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => ref.invalidate(clientDataProvider), child: const Text('Riprova')),
            ],
          ),
        ),
        data: (profile) {
          final diet = profile.dietProgress;
          final score = profile.healthScore?.toInt() ?? 0;
          final calsTarget = diet?.calories.target.toInt() ?? 2000;
          final calsCurrent = diet?.calories.current.toInt() ?? 0;

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
                // ── TOP BAR (FitOS logo + action icons) ──
                SliverAppBar(
                  floating: true,
                  backgroundColor: AppColors.background,
                  surfaceTintColor: Colors.transparent,
                  toolbarHeight: 60,
                  title: Text.rich(TextSpan(children: [
                    const TextSpan(text: 'Fit', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5)),
                    TextSpan(text: 'OS', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFFF15A24), letterSpacing: -0.5)),
                  ])),
                  centerTitle: false,
                  actions: [
                    _TopBarIcon(icon: Icons.calendar_today_rounded, onTap: () => showCalendarSheet(context, ref)),
                    const SizedBox(width: 8),
                    _TopBarIconBadge(icon: Icons.notifications_none_rounded, count: unreadNotifications.valueOrNull ?? 0, onTap: () => showNotificationsSheet(context, ref)),
                    const SizedBox(width: 8),
                    _TopBarIconBadge(icon: Icons.send_rounded, count: unreadMessages.valueOrNull ?? 0, onTap: () => showConversationsSheet(context, ref)),
                    const SizedBox(width: 16),
                  ],
                ),

                // ── CONTENT ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // A. Hero Carousel (minimal side padding for wider card)
                      _buildHeroCarousel(diet, score, calsCurrent, calsTarget),
                      const SizedBox(height: 8),
                      _buildDots(),
                      const SizedBox(height: 16),

                      // B-E: Regular content with extra padding
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            // B. Quick Actions
                            _QuickActions(
                              onAddMeal: () => _showManualMealDialog(context),
                              onScanMeal: () => _scanMeal(context),
                              onSearch: () => showSnack(context, 'Ricerca — Prossimamente'),
                            ),
                            const SizedBox(height: 16),

                            // C. Calendar + Meal Plan (one card like web app)
                            _CalendarMealPlanCard(
                              selectedDay: _selectedDay,
                              onDaySelected: (d) => setState(() => _selectedDay = d),
                            ),
                            const SizedBox(height: 16),

                            // D. Today's Diet Log
                            _TodaysDietLog(dietLog: diet?.dietLog),
                            const SizedBox(height: 24),

                            // E. Footer
                            _buildFooter(),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroCarousel(DietProgress? diet, int score, int calsCurrent, int calsTarget) {
    return SizedBox(
      height: 200,
      child: PageView(
        onPageChanged: (i) => setState(() => _heroPage = i),
        children: [
          _DietHeroCard(score: score, calsCurrent: calsCurrent, calsTarget: calsTarget, diet: diet),
          _WeightHeroCard(),
          _ConsistencyHeroCard(diet: diet),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) => Container(
        width: 8, height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: i == _heroPage ? Colors.white.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.2),
        ),
      )),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Termini', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text('  \u00b7  ', style: TextStyle(color: Colors.grey[700])),
          Text('Privacy', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text('  \u00b7  ', style: TextStyle(color: Colors.grey[700])),
          Text('Cookie', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Future<void> _showManualMealDialog(BuildContext context) async {
    final result = await showDialog<bool>(context: context, builder: (_) => _ManualMealDialog());
    if (result == true && mounted) ref.invalidate(clientDataProvider);
  }

  Future<void> _scanMeal(BuildContext ctx) async {
    // Open camera scanner modal (photo + barcode modes)
    final scanResult = await CameraScannerModal.show(ctx);
    if (scanResult == null || !mounted) return;

    // Use widget's own context (not the passed one which may be stale)
    final myContext = context;
    final service = ref.read(clientServiceProvider);

    try {
      if (scanResult.mode == 'barcode' && scanResult.barcode != null) {
        // ── Barcode flow ─────────────────────────────────────────
        debugPrint('[Diet] Barcode scanned: ${scanResult.barcode}');
        if (!mounted) return;
        showDialog(
          context: myContext,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (_) => const _AnalyzingOverlay(message: 'Cercando prodotto...'),
        );

        debugPrint('[Diet] Looking up barcode...');
        final result = await service.lookupBarcode(scanResult.barcode!);
        debugPrint('[Diet] Lookup result: ${result['status']}');

        if (mounted) Navigator.of(myContext, rootNavigator: true).pop(); // close loading
        if (!mounted) return;

        if (result['status'] == 'not_found' || (result['status'] != 'success' && result['found'] != true)) {
          showSnack(myContext, 'Prodotto non trovato per codice ${scanResult.barcode}', isError: true);
          return;
        }

        final product = result['data'] as Map<String, dynamic>? ?? result['product'] as Map<String, dynamic>? ?? result;
        debugPrint('[Diet] Product found: ${product['name']}');

        final logged = await showDialog<bool>(
          context: myContext,
          useRootNavigator: true,
          builder: (_) => _ScanResultDialog(
            initialName: product['name']?.toString() ?? product['product_name']?.toString() ?? 'Prodotto',
            initialCals: _toInt(product['kcal'] ?? product['calories'] ?? product['energy_kcal']),
            initialProtein: _toInt(product['protein'] ?? product['proteins']),
            initialCarbs: _toInt(product['carbs'] ?? product['carbohydrates']),
            initialFat: _toInt(product['fat'] ?? product['fats']),
            confidence: 'high',
            source: 'Barcode',
            items: null,
            per100g: product['per_100g'] as Map<String, dynamic>?,
            portionSize: product['portion_size']?.toString() ?? product['serving_size']?.toString(),
          ),
        );
        if (logged == true && mounted) ref.invalidate(clientDataProvider);

      } else if (scanResult.imageBytes != null) {
        // ── Photo flow ───────────────────────────────────────────
        if (!mounted) return;
        showDialog(
          context: myContext,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (_) => const _AnalyzingOverlay(),
        );

        final result = await service.scanMeal(scanResult.imageBytes!, 'meal.jpg');

        if (mounted) Navigator.of(myContext, rootNavigator: true).pop(); // close loading
        if (!mounted) return;

        final data = result['data'] as Map<String, dynamic>? ?? result;
        final method = result['method']?.toString() ?? data['source']?.toString() ?? 'AI';

        final logged = await showDialog<bool>(
          context: myContext,
          useRootNavigator: true,
          builder: (_) => _ScanResultDialog(
            initialName: data['meal_name']?.toString() ?? data['name']?.toString() ?? 'Pasto scansionato',
            initialCals: _toInt(data['total_kcal'] ?? data['cals']),
            initialProtein: _toInt(data['total_protein'] ?? data['protein']),
            initialCarbs: _toInt(data['total_carbs'] ?? data['carbs']),
            initialFat: _toInt(data['total_fat'] ?? data['fat']),
            confidence: data['confidence']?.toString() ?? 'medium',
            source: method,
            items: data['items'] as List<dynamic>?,
            per100g: data['per_100g'] as Map<String, dynamic>?,
            portionSize: data['portion_size']?.toString(),
          ),
        );
        if (logged == true && mounted) ref.invalidate(clientDataProvider);
      }
    } catch (e, st) {
      debugPrint('[Diet] Scan error: $e');
      debugPrint('[Diet] Stack: $st');
      if (mounted) {
        try { Navigator.of(myContext, rootNavigator: true).pop(); } catch (_) {}
        showSnack(myContext, 'Errore nella scansione: $e', isError: true);
      }
    }
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }
}

// ─── TOP BAR ICONS (matching dashboard_screen.dart) ──────────────

class _TopBarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopBarIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
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
        width: 40, height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Icon(icon, size: 20, color: AppColors.textPrimary),
            ),
            if (count > 0)
              Positioned(
                top: -2, right: -2,
                child: Container(
                  width: 18, height: 18,
                  decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                  child: Center(child: Text(count > 99 ? '99' : '$count', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── HERO PAGE 1: DIET + MACROS ──────────────────────────────────

class _DietHeroCard extends StatelessWidget {
  final int score;
  final int calsCurrent;
  final int calsTarget;
  final DietProgress? diet;
  const _DietHeroCard({required this.score, required this.calsCurrent, required this.calsTarget, required this.diet});

  @override
  Widget build(BuildContext context) {
    final pct = calsTarget > 0 ? ((calsCurrent / calsTarget) * 100).toInt() : 0;
    final motivation = score >= 90 ? 'Eccellente!' : score >= 75 ? 'Ottimi progressi!' : score >= 50 ? 'Continua così!' : score >= 25 ? 'Buon inizio!' : 'Iniziamo!';
    final motivColor = score >= 75 ? const Color(0xFF4ADE80) : score >= 50 ? const Color(0xFFFBBF24) : score >= 25 ? AppColors.primary : const Color(0xFFEF4444);

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Orange glow (top-right, like web: bg-orange-500/10 blur-3xl = blur(64px))
          Positioned(
            top: -40, right: -40,
            child: Container(
              width: 128, height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 64,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: Ring + stats
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Diet progress ring (64x64 — compact to give macros more room)
                        SizedBox(
                          width: 64, height: 64,
                          child: CustomPaint(
                            painter: _RingPainter(
                              progress: (score / 100).clamp(0.0, 1.0),
                              color: AppColors.primary,  // ORANGE, not grey
                              trackColor: Colors.white.withValues(alpha: 0.1),
                              strokeWidth: 6,
                            ),
                            child: Center(child: Icon(Icons.restaurant_rounded, size: 20, color: const Color(0xFFFB923C))),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DIETA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 1.2)),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('$score', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.textPrimary, height: 1.1)),
                                Text('%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
                              ],
                            ),
                            Text(motivation, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: motivColor)),
                            const SizedBox(height: 4),
                            // Kcal pill badge (like web: bg-white/10 rounded-full)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('$calsCurrent', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  Text(' / ', style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                                  Text('$calsTarget', style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                                  Text(' kcal', style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    // Vertical divider (like web: w-px h-16 bg-white/10)
                    Container(width: 1, height: 56, color: Colors.white.withValues(alpha: 0.1)),
                    const SizedBox(width: 10),
                    // Macro rings (like web: conic gradient circles)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _MacroRingSmall(label: 'Carbs', value: '${diet?.carbs.current.toInt() ?? 0}g', color: const Color(0xFFF97316), progress: diet?.carbs.percentage ?? 0),
                          _MacroRingSmall(label: 'Grassi', value: '${diet?.fat.current.toInt() ?? 0}g', color: const Color(0xFF60A5FA), progress: diet?.fat.percentage ?? 0),
                          _MacroRingSmall(label: 'Pro', value: '${diet?.protein.current.toInt() ?? 0}g', color: const Color(0xFFF472B6), progress: diet?.protein.percentage ?? 0),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // VAI A DIETA button (like web: py-3.5 bg-orange-500 rounded-xl)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('VAI A DIETA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Macro mini ring matching web app's conic-gradient style
class _MacroRingSmall extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final double progress;
  const _MacroRingSmall({required this.label, required this.value, required this.color, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 48, height: 48,
          child: CustomPaint(
            painter: _RingPainter(progress: progress.clamp(0.0, 1.0), color: color, trackColor: const Color(0xFF333333), strokeWidth: 3.5),
            child: Center(
              // Value text in the ring's OWN color (not white)
              child: Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.grey[400])),
      ],
    );
  }
}

// ─── HERO PAGE 2: WEIGHT ─────────────────────────────────────────

class _WeightHeroCard extends ConsumerWidget {
  const _WeightHeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(clientServiceProvider).getWeightHistory(period: 'month'),
      builder: (context, snap) {
        final data = (snap.data?['data'] as List<dynamic>?) ?? [];
        // Parse weight entries: [{date, weight}, ...]
        final entries = data.map((e) {
          final m = e as Map<String, dynamic>;
          return _WeightEntry(
            date: m['date']?.toString() ?? '',
            weight: (m['weight'] as num?)?.toDouble() ?? 0,
          );
        }).toList();

        final current = entries.isNotEmpty ? entries.last.weight : 0.0;
        final change = entries.length >= 2 ? entries.last.weight - entries.first.weight : 0.0;
        final changeStr = change >= 0 ? '+${change.toStringAsFixed(1)}' : change.toStringAsFixed(1);
        final changeColor = change <= 0 ? const Color(0xFF4ADE80) : const Color(0xFFEF4444);

        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PESO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 1.2)),
                  if (entries.length >= 2)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: changeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: Text('$changeStr kg', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: changeColor)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(current > 0 ? current.toStringAsFixed(1) : '--', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary, height: 1.1)),
                  const SizedBox(width: 4),
                  Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('kg', style: TextStyle(fontSize: 14, color: Colors.grey[500]))),
                ],
              ),
              const SizedBox(height: 12),
              // Mini weight chart
              Expanded(
                child: entries.length >= 2
                  ? CustomPaint(
                      size: const Size(double.infinity, double.infinity),
                      painter: _WeightChartPainter(entries: entries),
                    )
                  : Center(child: Text('Registra il peso per vedere il grafico', style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeightEntry {
  final String date;
  final double weight;
  const _WeightEntry({required this.date, required this.weight});
}

class _WeightChartPainter extends CustomPainter {
  final List<_WeightEntry> entries;
  _WeightChartPainter({required this.entries});

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2) return;
    final weights = entries.map((e) => e.weight).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b) - 0.5;
    final maxW = weights.reduce((a, b) => a > b ? a : b) + 0.5;
    final range = maxW - minW;

    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.primary.withValues(alpha: 0.3), AppColors.primary.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < entries.length; i++) {
      final x = (i / (entries.length - 1)) * size.width;
      final y = size.height - ((weights[i] - minW) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Draw last point dot
    final lastX = size.width;
    final lastY = size.height - ((weights.last - minW) / range) * size.height;
    canvas.drawCircle(Offset(lastX, lastY), 4, Paint()..color = AppColors.primary);
    canvas.drawCircle(Offset(lastX, lastY), 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─── HERO PAGE 3: CONSISTENCY ────────────────────────────────────

class _ConsistencyHeroCard extends StatelessWidget {
  final DietProgress? diet;
  const _ConsistencyHeroCard({required this.diet});

  @override
  Widget build(BuildContext context) {
    final scores = diet?.weeklyHealthScores ?? [];
    final days = ['LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'];
    final avg = scores.isNotEmpty ? (scores.reduce((a, b) => a + b) / scores.length).round() : 0;
    final target = diet?.consistencyTarget ?? 80;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('COSTANZA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 1.2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                child: Text('Media: $avg%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[400])),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$target', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary, height: 1.1)),
              const SizedBox(width: 4),
              Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('% target', style: TextStyle(fontSize: 14, color: Colors.grey[500]))),
            ],
          ),
          const SizedBox(height: 16),
          // Weekly bars with day labels
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final val = i < scores.length ? scores[i] : 0;
                final barPct = (val / 100.0).clamp(0.05, 1.0);
                final color = val >= 80 ? const Color(0xFF4ADE80) : val >= 60 ? const Color(0xFFFBBF24) : val >= 40 ? AppColors.primary : val > 0 ? const Color(0xFFEF4444) : Colors.white.withValues(alpha: 0.1);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: FractionallySizedBox(
                            heightFactor: val > 0 ? barPct : 0.05,
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(days[i], style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── BENTO GRID: HYDRATION + MACROS ─────────────────────────────

class _BentoGrid extends ConsumerWidget {
  final DietProgress? diet;
  const _BentoGrid({required this.diet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = diet?.hydration.current.toInt() ?? 0;
    final target = diet?.hydration.target.toInt() ?? 2500;
    final pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final cals = diet?.calories ?? const MacroValue(current: 0, target: 0);
    final remaining = cals.remaining.toInt();

    return Row(
      children: [
        // Hydration card
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IDRATAZIONE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 1.0)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$current', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary, height: 1.1)),
                    const SizedBox(width: 2),
                    Padding(padding: const EdgeInsets.only(bottom: 2), child: Text('ml', style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
                  ],
                ),
                Text('/ ${target}ml', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: const Color(0xFF60A5FA).withValues(alpha: 0.15), valueColor: const AlwaysStoppedAnimation(Color(0xFF60A5FA))),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    try { await ref.read(clientServiceProvider).addWater(); ref.invalidate(clientDataProvider); } catch (_) {}
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFF60A5FA).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Text('+ 250ml', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF60A5FA))),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Macros detail card
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MACROS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 1.0)),
                const SizedBox(height: 4),
                Text('$remaining kcal', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MacroRingLarge(label: 'Pro', current: diet?.protein.current ?? 0, target: diet?.protein.target ?? 0, color: const Color(0xFF4ADE80)),
                    _MacroRingLarge(label: 'Carb', current: diet?.carbs.current ?? 0, target: diet?.carbs.target ?? 0, color: const Color(0xFF60A5FA)),
                    _MacroRingLarge(label: 'Fat', current: diet?.fat.current ?? 0, target: diet?.fat.target ?? 0, color: const Color(0xFFF472B6)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MacroRingLarge extends StatelessWidget {
  final String label;
  final double current;
  final double target;
  final Color color;
  const _MacroRingLarge({required this.label, required this.current, required this.target, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        SizedBox(
          width: 48, height: 48,
          child: CustomPaint(
            painter: _RingPainter(progress: pct, color: color, trackColor: const Color(0xFF333333), strokeWidth: 4),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(fontSize: 7, color: Colors.grey[500])),
                  Text('${current.toInt()}g', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── QUICK ACTIONS ───────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final VoidCallback onAddMeal;
  final VoidCallback onScanMeal;
  final VoidCallback onSearch;
  const _QuickActions({required this.onAddMeal, required this.onScanMeal, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ActionPill(icon: Icons.edit_rounded, label: 'AGGIUNGI PASTO', onTap: onAddMeal)),
        const SizedBox(width: 8),
        Expanded(child: _ActionPill(icon: Icons.camera_alt_rounded, label: 'SCANSIONA PASTO', onTap: onScanMeal)),
        const SizedBox(width: 8),
        Expanded(child: _ActionPill(icon: Icons.search_rounded, label: 'CERCA', onTap: onSearch)),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionPill({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),  // rounded-full
          border: Border.all(color: AppColors.primary, width: 2),  // border-2 border-orange-500
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFFB923C)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFFB923C), letterSpacing: 0.3), overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CALENDAR + MEAL PLAN (single glass card like web) ───────────

class _CalendarMealPlanCard extends ConsumerStatefulWidget {
  final int selectedDay;
  final ValueChanged<int> onDaySelected;
  const _CalendarMealPlanCard({required this.selectedDay, required this.onDaySelected});
  @override
  ConsumerState<_CalendarMealPlanCard> createState() => _CalendarMealPlanCardState();
}

class _CalendarMealPlanCardState extends ConsumerState<_CalendarMealPlanCard> {
  Map<String, dynamic>? _plan;
  bool _loading = true;
  final Set<String> _checkedMeals = {};

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    try {
      final service = ref.read(clientServiceProvider);
      final result = await service.getWeeklyMealPlan();
      if (mounted) setState(() { _plan = result['plan'] as Map<String, dynamic>?; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleMealCheck(String mealId, Map<String, dynamic> meal) {
    setState(() {
      if (_checkedMeals.contains(mealId)) {
        _checkedMeals.remove(mealId);
      } else {
        _checkedMeals.add(mealId);
        ref.read(clientServiceProvider).logMeal({
          'name': meal['meal_name'] ?? '', 'meal_type': meal['meal_type'] ?? 'Snack',
          'cals': meal['calories'] ?? 0, 'protein': meal['protein'] ?? 0, 'carbs': meal['carbs'] ?? 0, 'fat': meal['fat'] ?? 0,
        }).catchError((_) {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Calendar strip (p-4 pb-3 like web)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _buildCalendar(),
          ),
          // Divider (border-t border-white/10 like web)
          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          // Meal plan section
          _buildMealPlan(),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    const labels = ['LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final date = monday.add(Duration(days: i));
        final isToday = date.day == now.day && date.month == now.month && date.year == now.year;
        final isSelected = i == widget.selectedDay;

        return GestureDetector(
          onTap: () => widget.onDaySelected(i),
          child: Column(
            children: [
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday ? AppColors.primary : Colors.transparent,
                  boxShadow: isToday ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))] : null,
                ),
                child: Center(
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isToday ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildMealPlan() {
    final isToday = widget.selectedDay == DateTime.now().weekday - 1;
    final dayLabel = isToday ? 'Oggi' : _fullDayName(widget.selectedDay);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row (like web: px-4 pt-3 pb-2)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PIANO ALIMENTARE - ${dayLabel.toUpperCase()}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)))
          else
            _buildMeals(),
        ],
      ),
    );
  }

  Widget _buildMeals() {
    final dayMeals = _plan?[widget.selectedDay.toString()] as List<dynamic>?;
    if (dayMeals == null || dayMeals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Nessun piano assegnato per questo giorno', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.3))),
      );
    }

    // Group by meal type
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final meal in dayMeals) {
      if (meal is Map<String, dynamic>) {
        final type = meal['meal_type'] as String? ?? 'altro';
        grouped.putIfAbsent(type, () => []).add(meal);
      }
    }

    final sortedTypes = grouped.keys.toList()
      ..sort((a, b) {
        final ai = _typeOrder.indexOf(a);
        final bi = _typeOrder.indexOf(b);
        return (ai == -1 ? 99 : ai).compareTo(bi == -1 ? 99 : bi);
      });

    return Column(
      children: [
        for (final type in sortedTypes)
          for (final m in grouped[type]!)
            _buildMealRow(type, m, grouped[type]!),
      ],
    );
  }

  Widget _buildMealRow(String type, Map<String, dynamic> m, List<Map<String, dynamic>> meals) {
    final mealId = '${type}_${m['meal_name']}_${m['id'] ?? meals.indexOf(m)}';
    final isChecked = _checkedMeals.contains(mealId);
    final emoji = _mealEmoji(type);
    final color = _mealColor(type);
    final label = _mealLabel(type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: isChecked ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isChecked ? const Color(0xFF4ADE80).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              // Checkoff circle (like web: w-5 h-5 border-2)
              GestureDetector(
                onTap: () => _toggleMealCheck(mealId, m),
                child: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isChecked ? const Color(0xFF4ADE80) : Colors.transparent,
                    border: Border.all(color: isChecked ? const Color(0xFF4ADE80) : Colors.white.withValues(alpha: 0.15), width: 2),
                  ),
                  child: isChecked ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
                ),
              ),
              const SizedBox(width: 10),
              // Emoji box (like web: w-8 h-8 rounded-lg bg-white/5)
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 10),
              // Meal details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(label.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.3)),
                        Text('${m['calories'] ?? 0} kcal', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      m['meal_name'] as String? ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        decoration: isChecked ? TextDecoration.lineThrough : null,
                        decorationColor: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── TODAY'S DIET LOG ────────────────────────────────────────────

class _TodaysDietLog extends StatelessWidget {
  final Map<String, List<DietItem>>? dietLog;
  const _TodaysDietLog({this.dietLog});

  @override
  Widget build(BuildContext context) {
    if (dietLog == null || dietLog!.isEmpty) return const SizedBox.shrink();
    final sortedTypes = dietLog!.keys.where((k) => dietLog![k]!.isNotEmpty).toList()
      ..sort((a, b) {
        final ai = _typeOrder.indexOf(a.toLowerCase());
        final bi = _typeOrder.indexOf(b.toLowerCase());
        return (ai == -1 ? 99 : ai).compareTo(bi == -1 ? 99 : bi);
      });
    if (sortedTypes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text('PASTI DI OGGI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 1.0)),
        ),
        ...sortedTypes.map((type) {
          final meals = dietLog![type]!;
          final typeLower = type.toLowerCase();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Row(children: [
                  Text(_mealEmoji(typeLower), style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Text(_mealLabel(typeLower).toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _mealColor(typeLower), letterSpacing: 0.5)),
                ]),
              ),
              ...meals.map((meal) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(meal.meal, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      if (meal.time.isNotEmpty) Text(meal.time, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    ])),
                    Text('${meal.cals}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(' kcal', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ]),
                ),
              )),
              const SizedBox(height: 8),
            ],
          );
        }),
      ],
    );
  }
}

// ─── MANUAL MEAL DIALOG ──────────────────────────────────────────

class _ManualMealDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ManualMealDialog> createState() => _ManualMealDialogState();
}

class _ManualMealDialogState extends ConsumerState<_ManualMealDialog> {
  final _nameC = TextEditingController();
  final _calsC = TextEditingController();
  final _proC = TextEditingController();
  final _carbsC = TextEditingController();
  final _fatC = TextEditingController();
  String _type = 'pranzo';
  bool _submitting = false;

  static const _types = {'colazione': 'Colazione', 'pranzo': 'Pranzo', 'cena': 'Cena', 'Snack': 'Spuntino'};

  @override
  void dispose() { _nameC.dispose(); _calsC.dispose(); _proC.dispose(); _carbsC.dispose(); _fatC.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_nameC.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref.read(clientServiceProvider).logMeal({
        'name': _nameC.text.trim(), 'meal_type': _type,
        'cals': int.tryParse(_calsC.text) ?? 0, 'protein': int.tryParse(_proC.text) ?? 0,
        'carbs': int.tryParse(_carbsC.text) ?? 0, 'fat': int.tryParse(_fatC.text) ?? 0,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) { showSnack(context, 'Errore nel salvataggio', isError: true); setState(() => _submitting = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Aggiungi Pasto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Inserisci i dati nutrizionali', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 20),
              _field('Nome Pasto', _nameC, TextInputType.text),
              const SizedBox(height: 12),
              Text('Tipo Pasto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
                child: DropdownButton<String>(
                  value: _type, isExpanded: true, dropdownColor: const Color(0xFF2A2A2A), underline: const SizedBox(),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  items: _types.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) { if (v != null) setState(() => _type = v); },
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _field('Calorie', _calsC, TextInputType.number)), const SizedBox(width: 8), Expanded(child: _field('Proteine (g)', _proC, TextInputType.number))]),
              const SizedBox(height: 8),
              Row(children: [Expanded(child: _field('Carboidrati (g)', _carbsC, TextInputType.number)), const SizedBox(width: 8), Expanded(child: _field('Grassi (g)', _fatC, TextInputType.number))]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Salva Pasto', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, TextInputType type) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
      const SizedBox(height: 6),
      TextField(
        controller: c, keyboardType: type,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true, fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    ]);
  }
}

// ─── ANALYZING OVERLAY ───────────────────────────────────────────

class _AnalyzingOverlay extends StatelessWidget {
  final String message;
  const _AnalyzingOverlay({this.message = 'Analizzando il pasto...'});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 48, height: 48,
                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
                ),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'L\'IA sta analizzando la foto',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SCAN RESULT DIALOG ─────────────────────────────────────────

class _ScanResultDialog extends ConsumerStatefulWidget {
  final String initialName;
  final int initialCals;
  final int initialProtein;
  final int initialCarbs;
  final int initialFat;
  final String confidence;
  final String source;
  final List<dynamic>? items;
  final Map<String, dynamic>? per100g;
  final String? portionSize;

  const _ScanResultDialog({
    required this.initialName,
    required this.initialCals,
    required this.initialProtein,
    required this.initialCarbs,
    required this.initialFat,
    required this.confidence,
    required this.source,
    this.items,
    this.per100g,
    this.portionSize,
  });

  @override
  ConsumerState<_ScanResultDialog> createState() => _ScanResultDialogState();
}

class _ScanResultDialogState extends ConsumerState<_ScanResultDialog> {
  late final TextEditingController _nameC;
  late final TextEditingController _calsC;
  late final TextEditingController _proC;
  late final TextEditingController _carbsC;
  late final TextEditingController _fatC;
  late final TextEditingController _portionC;
  String _type = 'pranzo';
  bool _submitting = false;
  bool _showItems = false;

  static const _types = {'colazione': 'Colazione', 'pranzo': 'Pranzo', 'cena': 'Cena', 'Snack': 'Spuntino'};

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController(text: widget.initialName);
    _calsC = TextEditingController(text: widget.initialCals.toString());
    _proC = TextEditingController(text: widget.initialProtein.toString());
    _carbsC = TextEditingController(text: widget.initialCarbs.toString());
    _fatC = TextEditingController(text: widget.initialFat.toString());
    _portionC = TextEditingController(text: widget.portionSize ?? '');
    _portionC.addListener(_recalcFromPortion);

    // Auto-detect meal type based on time of day
    final hour = DateTime.now().hour;
    if (hour < 10) {
      _type = 'colazione';
    } else if (hour < 14) {
      _type = 'pranzo';
    } else if (hour < 17) {
      _type = 'Snack';
    } else {
      _type = 'cena';
    }
  }

  @override
  void dispose() {
    _nameC.dispose(); _calsC.dispose(); _proC.dispose(); _carbsC.dispose(); _fatC.dispose(); _portionC.dispose();
    super.dispose();
  }

  void _recalcFromPortion() {
    final p100 = widget.per100g;
    if (p100 == null) return;
    final portionStr = _portionC.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final grams = double.tryParse(portionStr);
    if (grams == null || grams <= 0) return;

    final factor = grams / 100.0;
    setState(() {
      _calsC.text = ((p100['cals'] as num? ?? 0) * factor).round().toString();
      _proC.text = ((p100['protein'] as num? ?? 0) * factor).round().toString();
      _carbsC.text = ((p100['carbs'] as num? ?? 0) * factor).round().toString();
      _fatC.text = ((p100['fat'] as num? ?? 0) * factor).round().toString();
    });
  }

  Future<void> _submit() async {
    if (_nameC.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref.read(clientServiceProvider).logMeal({
        'name': _nameC.text.trim(),
        'meal_type': _type,
        'cals': int.tryParse(_calsC.text) ?? 0,
        'protein': int.tryParse(_proC.text) ?? 0,
        'carbs': int.tryParse(_carbsC.text) ?? 0,
        'fat': int.tryParse(_fatC.text) ?? 0,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Errore nel salvataggio', isError: true);
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final confColor = switch (widget.confidence) {
      'high' => const Color(0xFF4ADE80),
      'medium' => const Color(0xFFFBBF24),
      _ => const Color(0xFFF87171),
    };

    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with source badge
              Row(
                children: [
                  const Expanded(
                    child: Text('Pasto Scansionato', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: confColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: confColor, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(
                          widget.confidence.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: confColor, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Analizzato via ${_sourceLabel(widget.source)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 16),

              // Items breakdown (if available)
              if (widget.items != null && widget.items!.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => setState(() => _showItems = !_showItems),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.restaurant_menu_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${widget.items!.length} alimenti rilevati',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                        Icon(_showItems ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 20, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                if (_showItems)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      children: widget.items!.map((item) {
                        final m = item as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              Text('•', style: TextStyle(color: Colors.grey[600])),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${m['food'] ?? m['name'] ?? '?'} — ${m['portion_grams'] ?? '?'}g',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                ),
                              ),
                              Text(
                                '${m['kcal'] ?? m['cals'] ?? 0} kcal',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 12),
              ],

              // Editable fields
              _field('Nome Pasto', _nameC, TextInputType.text),
              const SizedBox(height: 12),
              Text('Tipo Pasto', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
                child: DropdownButton<String>(
                  value: _type, isExpanded: true, dropdownColor: const Color(0xFF2A2A2A), underline: const SizedBox(),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  items: _types.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) { if (v != null) setState(() => _type = v); },
                ),
              ),
              const SizedBox(height: 12),

              // Portion size (if per_100g available)
              if (widget.per100g != null) ...[
                Row(
                  children: [
                    Expanded(child: _field('Porzione (g)', _portionC, TextInputType.number)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: GestureDetector(
                        onTap: _recalcFromPortion,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              Row(children: [
                Expanded(child: _field('Calorie', _calsC, TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _field('Proteine (g)', _proC, TextInputType.number)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _field('Carboidrati (g)', _carbsC, TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _field('Grassi (g)', _fatC, TextInputType.number)),
              ]),
              const SizedBox(height: 20),

              // Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Registra Pasto', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, TextInputType type) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
      const SizedBox(height: 6),
      TextField(
        controller: c, keyboardType: type,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true, fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    ]);
  }

  String _sourceLabel(String source) {
    if (source.contains('gemini')) return 'AI Vision (Gemini)';
    if (source.contains('groq')) return 'AI Vision (Groq)';
    if (source.contains('barcode') || source.contains('openfoodfacts')) return 'Open Food Facts';
    if (source.contains('nutritionix')) return 'Nutritionix';
    if (source.contains('usda')) return 'USDA Database';
    return 'AI Vision';
  }
}

// ─── RING PAINTER ────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  _RingPainter({required this.progress, required this.color, required this.trackColor, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) / 2) - strokeWidth / 2;
    canvas.drawCircle(center, radius, Paint()..color = trackColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, 2 * pi * progress, false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}
