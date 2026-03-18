import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/nutritionist_provider.dart';
import '../../services/nutritionist_service.dart';
import '../../widgets/glass_card.dart';

const double _kDesktopBreakpoint = 1024;
const Color _kCyan = Color(0xFF06B6D4);
const Color _kAmber = Color(0xFFF59E0B);
const Color _kTeal = Color(0xFF14B8A6);
const Color _kPurple = Color(0xFFA855F7);

class NutritionistDashboardScreen extends ConsumerStatefulWidget {
  const NutritionistDashboardScreen({super.key});

  @override
  ConsumerState<NutritionistDashboardScreen> createState() =>
      _NutritionistDashboardScreenState();
}

class _NutritionistDashboardScreenState
    extends ConsumerState<NutritionistDashboardScreen> {
  String _searchQuery = '';
  String? _statFilter; // null, 'active', 'at_risk', 'total', 'diets'
  String? _selectedClientId;
  Map<String, dynamic>? _clientDetail;
  bool _loadingDetail = false;

  // Charts
  String _chartPeriod = 'month';
  String _weightTab = 'weight'; // weight | bodyfat | composition
  Map<String, dynamic>? _weightData;
  Map<String, dynamic>? _dietData;

  // Meal plan
  int _mealPlanDay = 0;
  Map<int, List<Map<String, dynamic>>> _mealPlan = {};

  // Notes
  final _noteTitleCtrl = TextEditingController();
  final _noteContentCtrl = TextEditingController();
  String? _editingNoteId;

  NutritionistService get _service =>
      ref.read(nutritionistServiceProvider);

  @override
  void dispose() {
    _noteTitleCtrl.dispose();
    _noteContentCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final nutriAsync = ref.watch(nutritionistDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: nutriAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: _kCyan)),
        error: (e, _) => Center(
            child: Text('Errore: $e',
                style: const TextStyle(color: AppColors.textSecondary))),
        data: (data) => _buildContent(data),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> data) {
    final isDesktop =
        MediaQuery.of(context).size.width > _kDesktopBreakpoint;
    if (isDesktop) return _buildDesktop(data);
    return _buildMobile(data);
  }

  // ═══════════════════════════════════════════════════════
  //  DESKTOP
  // ═══════════════════════════════════════════════════════
  Widget _buildDesktop(Map<String, dynamic> data) {
    final clients = _filteredClients(data);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(data),
            const SizedBox(height: 16),
            _buildStatsRow(data),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT: Client list + Notes (1/3)
                  SizedBox(
                    width: 320,
                    child: _buildLeftPanel(clients),
                  ),
                  const SizedBox(width: 16),
                  // RIGHT: Client detail (2/3)
                  Expanded(
                    child: _selectedClientId != null && _clientDetail != null
                        ? _buildClientDetailPanel()
                        : _buildNoClientSelected(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  MOBILE
  // ═══════════════════════════════════════════════════════
  Widget _buildMobile(Map<String, dynamic> data) {
    final clients = _filteredClients(data);

    // If a client is selected, show detail as full page
    if (_selectedClientId != null && _clientDetail != null) {
      return SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        setState(() => _selectedClientId = null),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _clientDetail!['name'] ?? '',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildClientDetailContent(),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _kCyan,
      backgroundColor: AppColors.surface,
      onRefresh: () async => ref.invalidate(nutritionistDataProvider),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(data),
                    const SizedBox(height: 16),
                    _buildStatsRow(data),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _buildClientTile(clients[i]),
                ),
                childCount: clients.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════
  Widget _buildHeader(Map<String, dynamic> data) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nutrizionista',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5),
              ),
              Text(
                data['name'] ?? 'Nutrizionista',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  //  STATS ROW
  // ═══════════════════════════════════════════════════════
  Widget _buildStatsRow(Map<String, dynamic> data) {
    final clients = data['clients'] as List? ?? [];
    final active = data['active_clients'] ?? 0;
    final atRisk = data['at_risk_clients'] ?? 0;
    final total = clients.length;
    final diets = clients
        .where((c) => c['calories_target'] != null)
        .length;

    return Row(
      children: [
        _StatCard(value: '$active', label: 'Clienti Attivi', color: AppColors.success,
            isActive: _statFilter == 'active',
            onTap: () => setState(() => _statFilter = _statFilter == 'active' ? null : 'active')),
        const SizedBox(width: 8),
        _StatCard(value: '$atRisk', label: 'A Rischio', color: AppColors.danger,
            isActive: _statFilter == 'at_risk',
            onTap: () => setState(() => _statFilter = _statFilter == 'at_risk' ? null : 'at_risk')),
        const SizedBox(width: 8),
        _StatCard(value: '$total', label: 'Totali', color: Colors.white,
            isActive: _statFilter == 'total',
            onTap: () => setState(() => _statFilter = _statFilter == 'total' ? null : 'total')),
        const SizedBox(width: 8),
        _StatCard(value: '$diets', label: 'Diete', color: AppColors.primary,
            isActive: _statFilter == 'diets',
            onTap: () => setState(() => _statFilter = _statFilter == 'diets' ? null : 'diets')),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  //  LEFT PANEL (desktop) — clients + notes
  // ═══════════════════════════════════════════════════════
  Widget _buildLeftPanel(List<Map<String, dynamic>> clients) {
    return Column(
      children: [
        _buildSearchBar(),
        const SizedBox(height: 8),
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: clients.isEmpty
                ? const Center(
                    child: Text('Nessun cliente',
                        style: TextStyle(
                            color: AppColors.textTertiary, fontSize: 13)))
                : ListView.builder(
                    itemCount: clients.length,
                    itemBuilder: (_, i) => _buildClientTile(clients[i]),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        // Quick Notes
        Expanded(
          flex: 2,
          child: _buildNotesPanel(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  //  SEARCH BAR
  // ═══════════════════════════════════════════════════════
  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        style: const TextStyle(fontSize: 13, color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Cerca clienti...',
          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
          prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textTertiary),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  CLIENT TILE
  // ═══════════════════════════════════════════════════════
  Widget _buildClientTile(Map<String, dynamic> client) {
    final id = client['id'] as String;
    final name = client['name'] as String? ?? '?';
    final status = client['status'] as String? ?? '';
    final weight = client['weight'];
    final isSelected = id == _selectedClientId;

    return GestureDetector(
      onTap: () => _selectClient(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.success.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.success : Colors.transparent,
              width: 2,
            ),
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
          ),
        ),
        child: Row(
          children: [
            _avatar(name, client['profile_picture'], 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${status == 'Active' ? 'Attivo' : status == 'At Risk' ? 'A Rischio' : status} · ${weight != null ? '${weight}kg' : 'Nessun dato'}',
                    style: TextStyle(
                        fontSize: 10,
                        color: status == 'Active'
                            ? AppColors.success
                            : AppColors.danger),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  CLIENT DETAIL PANEL
  // ═══════════════════════════════════════════════════════
  Widget _buildClientDetailPanel() {
    if (_loadingDetail) {
      return const Center(
          child: CircularProgressIndicator(color: _kCyan));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: _buildClientDetailContent(),
    );
  }

  Widget _buildClientDetailContent() {
    final d = _clientDetail!;
    final diet = d['diet'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Client header
        _buildClientHeader(d),
        const SizedBox(height: 16),

        // Current stats
        _buildCurrentStats(d),
        const SizedBox(height: 12),

        // Computed metrics (BMI/BMR/TDEE)
        if (d['bmi'] != null || d['bmr'] != null || d['tdee'] != null)
          _buildComputedMetrics(d),

        // Health profile button
        _buildHealthProfileButton(d),
        const SizedBox(height: 16),

        // Body composition form
        _buildSectionHeader('Composizione Corporea', AppColors.primary),
        const SizedBox(height: 8),
        _buildBodyCompositionForm(d),
        const SizedBox(height: 16),

        // Weight Goal + Diet Assignment
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildWeightGoalCard(d)),
            const SizedBox(width: 12),
            Expanded(child: _buildDietAssignmentCard(diet)),
          ],
        ),
        const SizedBox(height: 16),

        // Weekly Meal Plan
        _buildSectionHeader('Piano Alimentare Settimanale', _kAmber),
        const SizedBox(height: 8),
        _buildMealPlanEditor(),
        const SizedBox(height: 16),

        // Charts
        _buildChartsSection(),
      ],
    );
  }

  // ── Client Header ──────────────────────────────────────
  Widget _buildClientHeader(Map<String, dynamic> d) {
    return Row(
      children: [
        _avatar(d['name'] ?? '?', d['profile_picture'], 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d['name'] ?? '',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              Text(
                'Peso: ${d['weight'] ?? '—'}kg · Massa Grassa: ${d['body_fat_pct'] ?? '—'}%',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Current Stats ──────────────────────────────────────
  Widget _buildCurrentStats(Map<String, dynamic> d) {
    return Row(
      children: [
        _MetricTile(
            label: 'Peso (kg)', value: d['weight']?.toString() ?? '—'),
        const SizedBox(width: 8),
        _MetricTile(
            label: 'Massa Grassa %',
            value: d['body_fat_pct']?.toString() ?? '—'),
        const SizedBox(width: 8),
        _MetricTile(
            label: 'Massa Magra',
            value: d['lean_mass'] != null ? '${d['lean_mass']}kg' : '—'),
        const SizedBox(width: 8),
        _MetricTile(
            label: 'Massa Grassa',
            value: d['fat_mass'] != null ? '${d['fat_mass']}kg' : '—'),
      ],
    );
  }

  // ── Computed Metrics ───────────────────────────────────
  Widget _buildComputedMetrics(Map<String, dynamic> d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _CyanMetric(label: 'BMI', value: d['bmi']?.toString() ?? '—'),
          const SizedBox(width: 8),
          _CyanMetric(
              label: 'BMR (kcal)', value: d['bmr']?.toString() ?? '—'),
          const SizedBox(width: 8),
          _CyanMetric(
              label: 'TDEE (kcal)', value: d['tdee']?.toString() ?? '—'),
        ],
      ),
    );
  }

  // ── Health Profile Button ──────────────────────────────
  Widget _buildHealthProfileButton(Map<String, dynamic> d) {
    return GestureDetector(
      onTap: () => _showHealthProfileModal(d),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: _kCyan, width: 3)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _kCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.assignment_rounded,
                  size: 16, color: _kCyan),
            ),
            const SizedBox(width: 8),
            const Text('Health Profile',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kCyan,
                    letterSpacing: 0.5)),
            const Spacer(),
            Icon(Icons.open_in_new_rounded,
                size: 14, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  // ── Section Header ─────────────────────────────────────
  Widget _buildSectionHeader(String title, Color borderColor) {
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: borderColor, width: 3)),
      ),
      child: Text(title,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey[500],
              letterSpacing: 0.8)),
    );
  }

  // ── Body Composition Form ──────────────────────────────
  Widget _buildBodyCompositionForm(Map<String, dynamic> d) {
    final weightCtrl =
        TextEditingController(text: d['weight']?.toString() ?? '');
    final bfCtrl =
        TextEditingController(text: d['body_fat_pct']?.toString() ?? '');
    final fmCtrl =
        TextEditingController(text: d['fat_mass']?.toString() ?? '');
    final lmCtrl =
        TextEditingController(text: d['lean_mass']?.toString() ?? '');

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _field('Peso (kg) *', weightCtrl, 'bc-weight')),
              const SizedBox(width: 8),
              Expanded(
                  child: _field('Massa Grassa %', bfCtrl, 'bc-bodyfat')),
              const SizedBox(width: 8),
              Expanded(
                  child:
                      _field('Massa Grassa (kg)', fmCtrl, 'bc-fatmass')),
              const SizedBox(width: 8),
              Expanded(
                  child:
                      _field('Massa Magra (kg)', lmCtrl, 'bc-leanmass')),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final w = double.tryParse(weightCtrl.text);
                if (w == null || w <= 0) {
                  _toast('Il peso è obbligatorio');
                  return;
                }
                try {
                  await _service.addBodyComposition(
                    clientId: _selectedClientId!,
                    weight: w,
                    bodyFatPct: double.tryParse(bfCtrl.text),
                    fatMass: double.tryParse(fmCtrl.text),
                    leanMass: double.tryParse(lmCtrl.text),
                  );
                  _toast('Composizione corporea registrata!');
                  _selectClient(_selectedClientId!);
                } catch (e) {
                  _toast('Errore: $e');
                }
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Registra Misurazione',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Weight Goal Card ───────────────────────────────────
  Widget _buildWeightGoalCard(Map<String, dynamic> d) {
    final goalCtrl = TextEditingController(
        text: d['weight_goal']?.toString() ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Obiettivo Peso', _kPurple),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: 'Obiettivo attuale: ',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                TextSpan(
                    text: d['weight_goal'] != null
                        ? '${d['weight_goal']} kg'
                        : 'Non impostato',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ])),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _field(
                          'Peso obiettivo kg', goalCtrl, 'weight-goal')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final g = double.tryParse(goalCtrl.text);
                      if (g == null || g <= 0) {
                        _toast('Obiettivo non valido');
                        return;
                      }
                      try {
                        await _service.setWeightGoal(
                            _selectedClientId!, g);
                        _toast('Obiettivo impostato!');
                        _selectClient(_selectedClientId!);
                      } catch (e) {
                        _toast('Errore: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Imposta',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Diet Assignment Card ───────────────────────────────
  Widget _buildDietAssignmentCard(Map<String, dynamic> diet) {
    final calCtrl = TextEditingController(
        text: diet['calories_target']?.toString() ?? '');
    final proCtrl = TextEditingController(
        text: diet['protein_target']?.toString() ?? '');
    final carbCtrl = TextEditingController(
        text: diet['carbs_target']?.toString() ?? '');
    final fatCtrl =
        TextEditingController(text: diet['fat_target']?.toString() ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Piano Dieta', _kTeal),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _field('Calorie', calCtrl, 'diet-cal')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _field('Proteine (g)', proCtrl, 'diet-pro')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child:
                          _field('Carboidrati (g)', carbCtrl, 'diet-carb')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _field('Grassi (g)', fatCtrl, 'diet-fat')),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final cal = int.tryParse(calCtrl.text);
                    if (cal == null) {
                      _toast('Le calorie sono obbligatorie');
                      return;
                    }
                    try {
                      await _service.assignDiet(
                        clientId: _selectedClientId!,
                        calories: cal,
                        protein: int.tryParse(proCtrl.text) ?? 0,
                        carbs: int.tryParse(carbCtrl.text) ?? 0,
                        fat: int.tryParse(fatCtrl.text) ?? 0,
                      );
                      _toast('Piano dieta assegnato!');
                    } catch (e) {
                      _toast('Errore: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Assegna Dieta',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  //  WEEKLY MEAL PLAN EDITOR
  // ═══════════════════════════════════════════════════════
  static const _dayLabels = ['LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'];
  static const _mealTypes = [
    {'value': 'colazione', 'label': 'Colazione'},
    {'value': 'spuntino_mattina', 'label': 'Spuntino Mattina'},
    {'value': 'pranzo', 'label': 'Pranzo'},
    {'value': 'spuntino_pomeriggio', 'label': 'Merenda'},
    {'value': 'cena', 'label': 'Cena'},
  ];

  Widget _buildMealPlanEditor() {
    final meals = _mealPlan[_mealPlanDay] ?? [];

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(7, (i) {
                final isActive = i == _mealPlanDay;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _mealPlanDay = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? _kAmber.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _dayLabels[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isActive ? _kAmber : Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),

          // Meal entries
          if (meals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('Nessun pasto configurato per questo giorno',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ),
            )
          else
            ..._buildMealEntries(meals),

          const SizedBox(height: 8),

          // Add meal button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addMealEntry,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Aggiungi Pasto',
                  style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[500],
                side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                    style: BorderStyle.solid),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveMealPlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAmber,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Salva Piano Giornaliero',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMealEntries(List<Map<String, dynamic>> meals) {
    // Group by meal_type
    final mealOrder = _mealTypes.map((m) => m['value']).toList();
    final grouped = <String, List<_IndexedMeal>>{};
    for (var i = 0; i < meals.length; i++) {
      final type = meals[i]['meal_type'] as String? ?? 'colazione';
      grouped.putIfAbsent(type, () => []);
      grouped[type]!.add(_IndexedMeal(i, meals[i]));
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final ai = mealOrder.indexOf(a);
        final bi = mealOrder.indexOf(b);
        return (ai == -1 ? 99 : ai).compareTo(bi == -1 ? 99 : bi);
      });

    final widgets = <Widget>[];
    for (final type in sortedKeys) {
      final entries = grouped[type]!
        ..sort((a, b) => ((a.meal['alternative_index'] ?? 0) as int)
            .compareTo((b.meal['alternative_index'] ?? 0) as int));

      for (final entry in entries) {
        final isAlt = (entry.meal['alternative_index'] ?? 0) > 0;
        widgets.add(Padding(
          padding: EdgeInsets.only(
              left: isAlt ? 16 : 0, bottom: 8),
          child: _buildMealEntryCard(entry.index, entry.meal, isAlt),
        ));
      }

      // Add alternative button
      widgets.add(Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 8),
        child: GestureDetector(
          onTap: () => _addAlternativeEntry(type),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline,
                  size: 12, color: _kAmber.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text('Alternativa',
                  style: TextStyle(
                      fontSize: 10,
                      color: _kAmber.withValues(alpha: 0.5))),
            ],
          ),
        ),
      ));
    }
    return widgets;
  }

  Widget _buildMealEntryCard(
      int idx, Map<String, dynamic> meal, bool isAlt) {
    final nameCtrl =
        TextEditingController(text: meal['meal_name']?.toString() ?? '');
    final descCtrl =
        TextEditingController(text: meal['description']?.toString() ?? '');
    final calCtrl =
        TextEditingController(text: (meal['calories'] ?? 0).toString());
    final proCtrl =
        TextEditingController(text: (meal['protein'] ?? 0).toString());
    final carbCtrl =
        TextEditingController(text: (meal['carbs'] ?? 0).toString());
    final fatCtrl =
        TextEditingController(text: (meal['fat'] ?? 0).toString());

    final mealType = meal['meal_type'] as String? ?? 'colazione';
    final mealLabel =
        _mealTypes.firstWhere((m) => m['value'] == mealType,
            orElse: () => {'label': mealType})['label']!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        // left border for alternatives
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isAlt)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(mealLabel,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600])),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kAmber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                          'ALT ${meal['alternative_index']}',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _kAmber)),
                    ),
                  ],
                )
              else
                Expanded(
                  child: _mealTypeDropdown(idx, mealType),
                ),
              const Spacer(),
              GestureDetector(
                onTap: () => _removeMealEntry(idx),
                child: const Icon(Icons.delete_outline,
                    size: 16, color: AppColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _miniField('Nome pasto', nameCtrl, (v) {
            _mealPlan[_mealPlanDay]![idx]['meal_name'] = v;
          }),
          const SizedBox(height: 6),
          _miniField('Dettagli', descCtrl, (v) {
            _mealPlan[_mealPlanDay]![idx]['description'] = v;
          }, fontSize: 11),
          const SizedBox(height: 8),
          Row(
            children: [
              _macroField('Kcal', calCtrl, (v) {
                _mealPlan[_mealPlanDay]![idx]['calories'] =
                    int.tryParse(v) ?? 0;
              }),
              const SizedBox(width: 6),
              _macroField('Prot', proCtrl, (v) {
                _mealPlan[_mealPlanDay]![idx]['protein'] =
                    int.tryParse(v) ?? 0;
              }),
              const SizedBox(width: 6),
              _macroField('Carb', carbCtrl, (v) {
                _mealPlan[_mealPlanDay]![idx]['carbs'] =
                    int.tryParse(v) ?? 0;
              }),
              const SizedBox(width: 6),
              _macroField('Grassi', fatCtrl, (v) {
                _mealPlan[_mealPlanDay]![idx]['fat'] =
                    int.tryParse(v) ?? 0;
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mealTypeDropdown(int idx, String current) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: current,
        dropdownColor: AppColors.surface,
        style: const TextStyle(fontSize: 12, color: Colors.white),
        isDense: true,
        items: _mealTypes
            .map((m) => DropdownMenuItem(
                value: m['value'], child: Text(m['label']!)))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _mealPlan[_mealPlanDay]![idx]['meal_type'] = v;
          });
        },
      ),
    );
  }

  void _addMealEntry() {
    setState(() {
      _mealPlan.putIfAbsent(_mealPlanDay, () => []);
      final usedPrimary = _mealPlan[_mealPlanDay]!
          .where((m) => (m['alternative_index'] ?? 0) == 0)
          .map((m) => m['meal_type'])
          .toSet();
      final next = _mealTypes.firstWhere(
          (m) => !usedPrimary.contains(m['value']),
          orElse: () => _mealTypes.first);
      _mealPlan[_mealPlanDay]!.add({
        'meal_type': next['value'],
        'meal_name': '',
        'description': '',
        'calories': 0,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
        'alternative_index': 0,
      });
    });
  }

  void _addAlternativeEntry(String mealType) {
    setState(() {
      _mealPlan.putIfAbsent(_mealPlanDay, () => []);
      final existing = _mealPlan[_mealPlanDay]!
          .where((m) => m['meal_type'] == mealType)
          .toList();
      final maxIdx = existing.fold<int>(
          0,
          (max, m) => (m['alternative_index'] ?? 0) > max
              ? (m['alternative_index'] ?? 0) as int
              : max);
      _mealPlan[_mealPlanDay]!.add({
        'meal_type': mealType,
        'meal_name': '',
        'description': '',
        'calories': 0,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
        'alternative_index': maxIdx + 1,
      });
    });
  }

  void _removeMealEntry(int idx) {
    setState(() {
      _mealPlan[_mealPlanDay]?.removeAt(idx);
    });
  }

  Future<void> _saveMealPlan() async {
    if (_selectedClientId == null) {
      _toast('Seleziona un cliente');
      return;
    }
    final meals = _mealPlan[_mealPlanDay] ?? [];
    try {
      await _service.setClientWeeklyMealPlan(
        clientId: _selectedClientId!,
        dayOfWeek: _mealPlanDay,
        meals: meals
            .map((m) => {
                  'meal_type': m['meal_type'],
                  'meal_name': m['meal_name'],
                  'description': m['description'],
                  'calories': m['calories'],
                  'protein': m['protein'],
                  'carbs': m['carbs'],
                  'fat': m['fat'],
                  'alternative_index': m['alternative_index'] ?? 0,
                })
            .toList(),
      );
      _toast('Piano alimentare salvato!');
    } catch (e) {
      _toast('Errore: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  //  CHARTS SECTION
  // ═══════════════════════════════════════════════════════
  Widget _buildChartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child:
                    _buildSectionHeader('Grafici Progressi', const Color(0xFF60A5FA))),
            _periodToggle(),
          ],
        ),
        const SizedBox(height: 12),
        // Weight chart
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Andamento Peso',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[500],
                          letterSpacing: 0.5)),
                  const Spacer(),
                  _weightTabToggle(),
                ],
              ),
              const SizedBox(height: 12),
              _buildWeightChart(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Diet consistency chart
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Costanza Dieta',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[500],
                      letterSpacing: 0.5)),
              const SizedBox(height: 12),
              _buildDietChart(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _periodToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['week', 'month', 'year'].map((p) {
          final labels = {'week': 'Sett', 'month': 'Mese', 'year': 'Anno'};
          final isActive = _chartPeriod == p;
          return GestureDetector(
            onTap: () {
              setState(() => _chartPeriod = p);
              _loadCharts();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF2A2A2A)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(labels[p]!,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : Colors.grey[500])),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _weightTabToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ('weight', 'Weight'),
          ('bodyfat', 'Body Fat'),
          ('composition', 'Composition')
        ].map((t) {
          final isActive = _weightTab == t.$1;
          return GestureDetector(
            onTap: () => setState(() => _weightTab = t.$1),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF60A5FA).withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(t.$2,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? const Color(0xFF60A5FA)
                          : Colors.grey[600])),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeightChart() {
    if (_weightData == null) {
      return SizedBox(
        height: 160,
        child: Center(
            child: Text('Caricamento...',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
      );
    }

    final dataPoints = (_weightData!['data'] as List?) ?? [];
    if (dataPoints.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
            child: Text('Nessun dato disponibile',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
      );
    }

    List<double> values;
    Color lineColor;

    if (_weightTab == 'weight') {
      values = dataPoints
          .map<double>((d) => (d['weight'] as num?)?.toDouble() ?? 0)
          .toList();
      lineColor = AppColors.primary;
    } else if (_weightTab == 'bodyfat') {
      values = dataPoints
          .map<double>(
              (d) => (d['body_fat_pct'] as num?)?.toDouble() ?? 0)
          .toList();
      lineColor = _kAmber;
    } else {
      // Show lean mass
      values = dataPoints
          .map<double>(
              (d) => (d['lean_mass'] as num?)?.toDouble() ?? 0)
          .toList();
      lineColor = AppColors.success;
    }

    return SizedBox(
      height: 160,
      child: _SimpleLineChart(values: values, color: lineColor),
    );
  }

  Widget _buildDietChart() {
    if (_dietData == null) {
      return SizedBox(
        height: 160,
        child: Center(
            child: Text('Caricamento...',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
      );
    }

    final dataPoints = (_dietData!['data'] as List?) ?? [];
    if (dataPoints.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
            child: Text('Nessun dato disponibile',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
      );
    }

    final scores = dataPoints
        .map<double>(
            (d) => ((d['health_score'] ?? d['score'] ?? 0) as num).toDouble())
        .toList();

    return SizedBox(
      height: 160,
      child: _SimpleBarChart(values: scores),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  NOTES PANEL
  // ═══════════════════════════════════════════════════════
  Widget _buildNotesPanel() {
    final notesAsync = ref.watch(nutritionistNotesProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                        left: BorderSide(
                            color: AppColors.textTertiary, width: 3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Note Rapide',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[500],
                              letterSpacing: 0.5)),
                      Text('Promemoria & to-dos',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[700])),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Title + add
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteTitleCtrl,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Titolo nota...',
                      hintStyle: TextStyle(
                          color: AppColors.textTertiary, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _saveNote,
                  child: Text('+ Aggiungi',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              controller: _noteContentCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Scrivi una nota...',
                hintStyle: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(8),
              ),
            ),
          ),
          Divider(
              height: 1, color: Colors.white.withValues(alpha: 0.04)),
          // Notes list
          Expanded(
            child: notesAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: _kCyan, strokeWidth: 2)),
              error: (_, __) => Center(
                  child: Text('Errore',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600]))),
              data: (notes) {
                if (notes.isEmpty) {
                  return Center(
                      child: Text('Nessuna nota',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[700])));
                }
                return ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (_, i) => _buildNoteTile(notes[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteTile(Map<String, dynamic> note) {
    return GestureDetector(
      onTap: () {
        _noteTitleCtrl.text = note['title'] ?? '';
        _noteContentCtrl.text = note['content'] ?? '';
        _editingNoteId = note['id']?.toString();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
              bottom:
                  BorderSide(color: Colors.white.withValues(alpha: 0.04))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note['title'] ?? 'Untitled',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis),
                  if (note['content'] != null &&
                      (note['content'] as String).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(note['content'],
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                try {
                  await _service.deleteNote(note['id'].toString());
                  ref.invalidate(nutritionistNotesProvider);
                } catch (_) {}
              },
              child: Icon(Icons.delete_outline,
                  size: 14, color: AppColors.danger.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNote() async {
    final title = _noteTitleCtrl.text.trim();
    final content = _noteContentCtrl.text.trim();
    if (title.isEmpty && content.isEmpty) return;
    try {
      await _service.saveNote(
        id: _editingNoteId,
        title: title.isEmpty ? 'Untitled' : title,
        content: content,
      );
      _noteTitleCtrl.clear();
      _noteContentCtrl.clear();
      _editingNoteId = null;
      ref.invalidate(nutritionistNotesProvider);
    } catch (e) {
      _toast('Errore: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  //  NO CLIENT SELECTED
  // ═══════════════════════════════════════════════════════
  Widget _buildNoClientSelected() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_rounded,
                size: 48, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text('Seleziona un cliente dalla lista per visualizzare i suoi dati',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  HEALTH PROFILE MODAL
  // ═══════════════════════════════════════════════════════
  void _showHealthProfileModal(Map<String, dynamic> d) {
    final heightCtrl =
        TextEditingController(text: d['height_cm']?.toString() ?? '');
    String gender = d['gender']?.toString() ?? '';
    final dobCtrl =
        TextEditingController(text: d['date_of_birth']?.toString() ?? '');
    String activityLevel = d['activity_level']?.toString() ?? '';
    final allergiesCtrl =
        TextEditingController(text: d['allergies']?.toString() ?? '');
    final medicalCtrl = TextEditingController(
        text: d['medical_conditions']?.toString() ?? '');
    final supplementsCtrl =
        TextEditingController(text: d['supplements']?.toString() ?? '');
    final sleepCtrl =
        TextEditingController(text: d['sleep_hours']?.toString() ?? '');
    String mealFrequency = d['meal_frequency']?.toString() ?? '';
    String foodPreferences = d['food_preferences']?.toString() ?? '';
    String occupationType = d['occupation_type']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Container(
            margin: const EdgeInsets.only(top: 60),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              builder: (_, scrollCtrl) {
                return SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _kCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                                Icons.assignment_rounded,
                                size: 18,
                                color: _kCyan),
                          ),
                          const SizedBox(width: 8),
                          const Text('Health Profile',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Basic Measurements
                      _sectionLabel('Basic Measurements'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: _field(
                                  'Height (cm)', heightCtrl, 'hp-h')),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _dropdown('Gender', gender,
                                ['', 'male', 'female', 'other'],
                                ['—', 'Male', 'Female', 'Other'], (v) {
                              setModalState(() => gender = v);
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: _field(
                                  'Date of Birth', dobCtrl, 'hp-dob')),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _dropdown(
                                'Activity Level',
                                activityLevel,
                                [
                                  '',
                                  'sedentary',
                                  'light',
                                  'moderate',
                                  'active',
                                  'very_active'
                                ],
                                [
                                  '—',
                                  'Sedentary',
                                  'Lightly Active',
                                  'Moderately Active',
                                  'Active',
                                  'Very Active'
                                ], (v) {
                              setModalState(() => activityLevel = v);
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Medical & Dietary
                      _sectionLabel('Medical & Dietary'),
                      const SizedBox(height: 8),
                      _field('Allergies / Intolerances', allergiesCtrl,
                          'hp-all'),
                      const SizedBox(height: 8),
                      _field('Medical Conditions', medicalCtrl,
                          'hp-med'),
                      const SizedBox(height: 8),
                      _field('Supplements', supplementsCtrl, 'hp-sup'),
                      const SizedBox(height: 16),

                      // Lifestyle
                      _sectionLabel('Lifestyle'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: _field(
                                  'Sleep (hrs/day)', sleepCtrl, 'hp-sl')),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _dropdown(
                                'Meal Frequency',
                                mealFrequency,
                                [
                                  '',
                                  '3_meals',
                                  '5_small',
                                  'intermittent_fasting',
                                  'custom'
                                ],
                                [
                                  '—',
                                  '3 Meals',
                                  '5 Small Meals',
                                  'Intermittent Fasting',
                                  'Custom'
                                ], (v) {
                              setModalState(() => mealFrequency = v);
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _dropdown(
                                'Food Preferences',
                                foodPreferences,
                                [
                                  '',
                                  'none',
                                  'vegan',
                                  'vegetarian',
                                  'halal',
                                  'kosher',
                                  'other'
                                ],
                                [
                                  '—',
                                  'No Restrictions',
                                  'Vegan',
                                  'Vegetarian',
                                  'Halal',
                                  'Kosher',
                                  'Other'
                                ], (v) {
                              setModalState(() => foodPreferences = v);
                            }),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _dropdown(
                                'Occupation',
                                occupationType,
                                [
                                  '',
                                  'sedentary',
                                  'light_physical',
                                  'heavy_physical'
                                ],
                                [
                                  '—',
                                  'Desk Job',
                                  'Light Physical',
                                  'Heavy Physical'
                                ], (v) {
                              setModalState(() => occupationType = v);
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await _service.updateHealthData({
                                'client_id': _selectedClientId,
                                'height_cm':
                                    double.tryParse(heightCtrl.text),
                                'gender':
                                    gender.isEmpty ? null : gender,
                                'date_of_birth': dobCtrl.text.isEmpty
                                    ? null
                                    : dobCtrl.text,
                                'activity_level': activityLevel.isEmpty
                                    ? null
                                    : activityLevel,
                                'allergies': allergiesCtrl.text.isEmpty
                                    ? null
                                    : allergiesCtrl.text,
                                'medical_conditions':
                                    medicalCtrl.text.isEmpty
                                        ? null
                                        : medicalCtrl.text,
                                'supplements':
                                    supplementsCtrl.text.isEmpty
                                        ? null
                                        : supplementsCtrl.text,
                                'sleep_hours':
                                    double.tryParse(sleepCtrl.text),
                                'meal_frequency': mealFrequency.isEmpty
                                    ? null
                                    : mealFrequency,
                                'food_preferences':
                                    foodPreferences.isEmpty
                                        ? null
                                        : foodPreferences,
                                'occupation_type':
                                    occupationType.isEmpty
                                        ? null
                                        : occupationType,
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              _toast('Health data saved!');
                              _selectClient(_selectedClientId!);
                            } catch (e) {
                              _toast('Errore: $e');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kCyan,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Save Health Data',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          );
        });
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════
  List<Map<String, dynamic>> _filteredClients(Map<String, dynamic> data) {
    var clients =
        (data['clients'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Apply stat filter
    if (_statFilter == 'active') {
      clients = clients.where((c) => c['status'] == 'Active').toList();
    } else if (_statFilter == 'at_risk') {
      clients = clients.where((c) => c['status'] == 'At Risk').toList();
    } else if (_statFilter == 'diets') {
      clients = clients.where((c) => c['calories_target'] != null).toList();
    }
    // 'total' shows all — no additional filter

    if (_searchQuery.isNotEmpty) {
      clients = clients
          .where((c) =>
              (c['name'] as String? ?? '')
                  .toLowerCase()
                  .contains(_searchQuery))
          .toList();
    }
    return clients;
  }

  Future<void> _selectClient(String clientId) async {
    setState(() {
      _selectedClientId = clientId;
      _loadingDetail = true;
    });
    try {
      debugPrint('>>> 1. getClientDetail($clientId)');
      final detail = await _service.getClientDetail(clientId);
      debugPrint('>>> 1. OK');

      debugPrint('>>> 2. getClientWeeklyMealPlan($clientId)');
      final mealPlanRes =
          await _service.getClientWeeklyMealPlan(clientId);
      debugPrint('>>> 2. OK');

      final plan = mealPlanRes['plan'] as Map<String, dynamic>? ?? {};
      final parsedPlan = <int, List<Map<String, dynamic>>>{};
      for (final entry in plan.entries) {
        final dayList = entry.value as List? ?? [];
        parsedPlan[int.parse(entry.key)] =
            dayList.map((m) => Map<String, dynamic>.from(m as Map)).toList();
      }

      setState(() {
        _clientDetail = detail;
        _mealPlan = parsedPlan;
        _mealPlanDay = 0;
        _loadingDetail = false;
      });
      _loadCharts();
    } catch (e, st) {
      debugPrint('>>> FAILED: $e');
      debugPrint('>>> Stack: $st');
      setState(() => _loadingDetail = false);
      _toast('Errore: $e');
    }
  }

  Future<void> _loadCharts() async {
    if (_selectedClientId == null) return;
    try {
      final w = await _service.getClientWeightHistory(
          _selectedClientId!, _chartPeriod);
      final d = await _service.getClientDietConsistency(
          _selectedClientId!, _chartPeriod);
      if (mounted) setState(() { _weightData = w; _dietData = d; });
    } catch (_) {}
  }

  Widget _avatar(String name, String? url, double size) {
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initialsCircle(name, size)),
      );
    }
    return _initialsCircle(name, size);
  }

  Widget _initialsCircle(String name, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.w700,
              color: AppColors.success),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String tag) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey[500],
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _dropdown(String label, String value, List<String> values,
      List<String> labels, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey[500],
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: values.contains(value) ? value : values.first,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              style: const TextStyle(fontSize: 13, color: Colors.white),
              items: List.generate(
                  values.length,
                  (i) => DropdownMenuItem(
                      value: values[i], child: Text(labels[i]))),
              onChanged: (v) => onChanged(v ?? ''),
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniField(
      String hint, TextEditingController ctrl, ValueChanged<String> onChanged,
      {double fontSize = 13}) {
    return TextField(
      controller: ctrl,
      onChanged: onChanged,
      style: TextStyle(fontSize: fontSize, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[700], fontSize: fontSize),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
    );
  }

  Widget _macroField(
      String label, TextEditingController ctrl, ValueChanged<String> onChanged) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 0.3)),
          const SizedBox(height: 2),
          TextField(
            controller: ctrl,
            onChanged: onChanged,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _kCyan,
            letterSpacing: 1.0));
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SMALL HELPER WIDGETS
// ═══════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback? onTap;

  const _StatCard(
      {required this.value, required this.label, required this.color,
       this.isActive = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.15) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? color.withValues(alpha: 0.5) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: isActive ? color.withValues(alpha: 0.8) : Colors.grey[600],
                      fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}

class _CyanMetric extends StatelessWidget {
  final String label;
  final String value;

  const _CyanMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _kCyan.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kCyan.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _kCyan)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}

class _IndexedMeal {
  final int index;
  final Map<String, dynamic> meal;
  const _IndexedMeal(this.index, this.meal);
}

// ═══════════════════════════════════════════════════════════
//  SIMPLE CHARTS (CustomPaint, no dependency)
// ═══════════════════════════════════════════════════════════

class _SimpleLineChart extends StatelessWidget {
  final List<double> values;
  final Color color;

  const _SimpleLineChart({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _LineChartPainter(values: values, color: color),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _LineChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final nonZero = values.where((v) => v > 0).toList();
    if (nonZero.isEmpty) return;

    final minVal = nonZero.reduce((a, b) => a < b ? a : b) * 0.95;
    final maxVal = nonZero.reduce((a, b) => a > b ? a : b) * 1.05;
    final range = maxVal - minVal;
    if (range == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : i * size.width / (values.length - 1);
      final y = size.height - ((values[i] - minVal) / range * size.height);

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
    canvas.drawPath(path, paint);

    // Draw points
    final dotPaint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : i * size.width / (values.length - 1);
      final y = size.height - ((values[i] - minVal) / range * size.height);
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _SimpleBarChart extends StatelessWidget {
  final List<double> values;

  const _SimpleBarChart({required this.values});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _BarChartPainter(values: values),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<double> values;

  _BarChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxVal = 100.0;
    final barWidth = (size.width / values.length) * 0.6;
    final gap = (size.width / values.length) * 0.4;

    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final barHeight = (v / maxVal) * size.height;
      final x = i * (barWidth + gap) + gap / 2;

      final color = v >= 70
          ? const Color(0xFF22C55E).withValues(alpha: 0.6)
          : v >= 40
              ? const Color(0xFFF97316).withValues(alpha: 0.6)
              : const Color(0xFFEF4444).withValues(alpha: 0.6);

      final paint = Paint()..color = color;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.values != values;
}
