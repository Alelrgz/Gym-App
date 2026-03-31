import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/owner_provider.dart';

// ═══════════════════════════════════════════════════════════
//  TRIGGER DEFINITIONS
// ═══════════════════════════════════════════════════════════

class _TriggerDef {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final String defaultMessage;
  final List<String> variables;
  final bool hasThreshold;
  final String? thresholdLabel;
  final int defaultThreshold;

  const _TriggerDef({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.defaultMessage,
    required this.variables,
    this.hasThreshold = false,
    this.thresholdLabel,
    this.defaultThreshold = 5,
  });
}

const _triggers = [
  _TriggerDef(
    id: 'days_inactive',
    label: 'Cliente Inattivo',
    description: 'Quando un cliente non si allena da un certo numero di giorni',
    icon: Icons.schedule_rounded,
    color: Color(0xFFF97316),
    defaultMessage: 'Ciao {client_name}, ci manchi! Sono passati {days_inactive} giorni dal tuo ultimo allenamento. Ti aspettiamo alla {gym_name}! 💪',
    variables: ['{client_name}', '{days_inactive}', '{last_workout_date}', '{trainer_name}', '{gym_name}'],
    hasThreshold: true,
    thresholdLabel: 'Dopo quanti giorni di inattività?',
    defaultThreshold: 5,
  ),
  _TriggerDef(
    id: 'missed_workout',
    label: 'Allenamento Mancato',
    description: 'Quando un cliente salta un allenamento programmato',
    icon: Icons.fitness_center_rounded,
    color: Color(0xFFF87171),
    defaultMessage: 'Ciao {client_name}, abbiamo notato che hai saltato "{workout_title}". Nessun problema, ti aspettiamo al prossimo! 🏋️',
    variables: ['{client_name}', '{workout_title}', '{date}', '{trainer_name}', '{gym_name}'],
  ),
  _TriggerDef(
    id: 'no_show_appointment',
    label: 'Appuntamento Mancato',
    description: 'Quando un cliente non si presenta a un appuntamento',
    icon: Icons.event_busy_rounded,
    color: Color(0xFFFACC15),
    defaultMessage: 'Ciao {client_name}, abbiamo notato che non sei riuscito a venire all\'appuntamento con {trainer_name}. Vuoi riprogrammare?',
    variables: ['{client_name}', '{trainer_name}', '{appointment_date}', '{appointment_time}', '{gym_name}'],
  ),
  _TriggerDef(
    id: 'subscription_canceled',
    label: 'Abbonamento Cancellato',
    description: 'Quando un cliente cancella il proprio abbonamento',
    icon: Icons.credit_card_off_rounded,
    color: Color(0xFFA78BFA),
    defaultMessage: 'Ciao {client_name}, ci dispiace vederti andare! Usa il codice {coupon_code} per {discount_value}{discount_symbol} di sconto. Ti aspettiamo alla {gym_name}!',
    variables: ['{client_name}', '{plan_name}', '{days_since_cancellation}', '{trainer_name}', '{gym_name}'],
    hasThreshold: true,
    thresholdLabel: 'Entro quanti giorni dalla cancellazione?',
    defaultThreshold: 7,
  ),
  _TriggerDef(
    id: 'payment_failed',
    label: 'Pagamento Fallito',
    description: 'Quando il pagamento di un abbonamento fallisce (Stripe)',
    icon: Icons.credit_score_rounded,
    color: Color(0xFFEF4444),
    defaultMessage: 'Ciao {client_name}, il pagamento per il tuo abbonamento "{plan_name}" non è andato a buon fine. Aggiorna il metodo di pagamento per continuare ad allenarti!',
    variables: ['{client_name}', '{plan_name}', '{amount}', '{currency}', '{trainer_name}', '{gym_name}'],
    hasThreshold: true,
    thresholdLabel: 'Entro quanti giorni dal pagamento fallito?',
    defaultThreshold: 3,
  ),
  _TriggerDef(
    id: 'upcoming_appointment',
    label: 'Promemoria Appuntamento',
    description: 'Ricorda al cliente un appuntamento in arrivo',
    icon: Icons.alarm_rounded,
    color: Color(0xFF38BDF8),
    defaultMessage: 'Ciao {client_name}, ricordati del tuo appuntamento con {trainer_name} il {appointment_date} alle {appointment_time}. Ti aspettiamo! 📅',
    variables: ['{client_name}', '{trainer_name}', '{appointment_date}', '{appointment_time}', '{gym_name}'],
    hasThreshold: true,
    thresholdLabel: 'Quante ore prima dell\'appuntamento?',
    defaultThreshold: 24,
  ),
];

const _offerVariables = ['{offer_title}', '{discount_value}', '{discount_symbol}', '{coupon_code}', '{offer_expires}', '{checkout_link}'];

// ═══════════════════════════════════════════════════════════
//  PRE-BUILT RECIPES
// ═══════════════════════════════════════════════════════════

class _Recipe {
  final String name;
  final String subtitle;
  final String triggerId;
  final int? threshold;
  final String message;
  final IconData icon;
  final Color color;

  const _Recipe({
    required this.name,
    required this.subtitle,
    required this.triggerId,
    this.threshold,
    required this.message,
    required this.icon,
    required this.color,
  });
}

const _recipes = [
  _Recipe(
    name: 'Riattiva Inattivi',
    subtitle: 'Contatta chi non viene da 7 giorni',
    triggerId: 'days_inactive',
    threshold: 7,
    message: 'Ciao {client_name}, ci manchi! Sono passati {days_inactive} giorni dal tuo ultimo allenamento. Ti aspettiamo alla {gym_name}! 💪',
    icon: Icons.replay_rounded,
    color: Color(0xFFF97316),
  ),
  _Recipe(
    name: 'Promemoria Allenamento',
    subtitle: 'Quando salta una sessione programmata',
    triggerId: 'missed_workout',
    message: 'Ciao {client_name}, hai saltato "{workout_title}" — ti aspettiamo alla prossima sessione! 🏋️',
    icon: Icons.fitness_center_rounded,
    color: Color(0xFFF87171),
  ),
  _Recipe(
    name: 'Recupera Ex-Clienti',
    subtitle: 'Dopo la cancellazione dell\'abbonamento',
    triggerId: 'subscription_canceled',
    threshold: 7,
    message: 'Ciao {client_name}, ci dispiace vederti andare! Usa il codice {coupon_code} per {discount_value}{discount_symbol} di sconto. Ti aspettiamo!',
    icon: Icons.card_giftcard_rounded,
    color: Color(0xFFA78BFA),
  ),
  _Recipe(
    name: 'No-Show Appuntamento',
    subtitle: 'Quando manca un appuntamento col trainer',
    triggerId: 'no_show_appointment',
    message: 'Ciao {client_name}, non sei riuscito a venire all\'appuntamento con {trainer_name}. Vuoi riprogrammare? 📅',
    icon: Icons.event_busy_rounded,
    color: Color(0xFFFACC15),
  ),
  _Recipe(
    name: 'Pagamento Fallito',
    subtitle: 'Quando il pagamento Stripe non va a buon fine',
    triggerId: 'payment_failed',
    threshold: 3,
    message: 'Ciao {client_name}, il pagamento per "{plan_name}" non è andato a buon fine. Aggiorna il tuo metodo di pagamento per non perdere l\'accesso! 💳',
    icon: Icons.credit_score_rounded,
    color: Color(0xFFEF4444),
  ),
  _Recipe(
    name: 'Promemoria 24h Prima',
    subtitle: 'Ricorda l\'appuntamento il giorno prima',
    triggerId: 'upcoming_appointment',
    threshold: 24,
    message: 'Ciao {client_name}, domani hai un appuntamento con {trainer_name} alle {appointment_time}. Non dimenticare! 📅',
    icon: Icons.alarm_rounded,
    color: Color(0xFF38BDF8),
  ),
];

// ═══════════════════════════════════════════════════════════
//  MAIN BUILDER SCREEN
// ═══════════════════════════════════════════════════════════

class OwnerAutomationBuilderScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existingTemplate;
  const OwnerAutomationBuilderScreen({super.key, this.existingTemplate});

  @override
  ConsumerState<OwnerAutomationBuilderScreen> createState() => _OwnerAutomationBuilderScreenState();
}

class _OwnerAutomationBuilderScreenState extends ConsumerState<OwnerAutomationBuilderScreen> {
  int _step = 0; // 0=recipes/trigger, 1=conditions, 2=message
  _TriggerDef? _selectedTrigger;
  int _threshold = 5;
  String _name = '';
  late TextEditingController _messageCtrl;
  late TextEditingController _nameCtrl;
  bool _enabled = true;
  bool _saving = false;
  bool _dragOverMessage = false;
  bool get _isEdit => widget.existingTemplate != null;

  // Delivery methods
  final Set<String> _deliveryMethods = {'in_app'};

  // Linked offer
  List<Map<String, dynamic>> _offers = [];
  String? _linkedOfferId;

  @override
  void initState() {
    super.initState();
    final tmpl = widget.existingTemplate;
    if (tmpl != null) {
      _name = tmpl['name'] as String? ?? '';
      _nameCtrl = TextEditingController(text: _name);
      _messageCtrl = TextEditingController(text: tmpl['message_template'] as String? ?? '');
      _enabled = tmpl['is_enabled'] as bool? ?? tmpl['enabled'] as bool? ?? true;
      _linkedOfferId = tmpl['linked_offer_id'] as String?;
      final triggerId = tmpl['trigger_type'] as String? ?? '';
      _selectedTrigger = _triggers.cast<_TriggerDef?>().firstWhere((t) => t?.id == triggerId, orElse: () => null);
      final config = tmpl['trigger_config'];
      if (config is Map) {
        _threshold = (config['hours_before'] as num?)?.toInt()
            ?? (config['days_threshold'] as num?)?.toInt()
            ?? 5;
      }
      // Load delivery methods
      final methods = tmpl['delivery_methods'];
      if (methods is List && methods.isNotEmpty) {
        _deliveryMethods.clear();
        for (final m in methods) {
          _deliveryMethods.add(m.toString());
        }
      }
      _step = 1; // skip recipe selection for edits
    } else {
      _nameCtrl = TextEditingController();
      _messageCtrl = TextEditingController();
    }
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    try {
      final offers = await ref.read(ownerServiceProvider).getOffers();
      if (mounted) setState(() => _offers = offers);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _selectRecipe(_Recipe recipe) {
    final trigger = _triggers.firstWhere((t) => t.id == recipe.triggerId);
    setState(() {
      _selectedTrigger = trigger;
      _threshold = recipe.threshold ?? trigger.defaultThreshold;
      _nameCtrl.text = recipe.name;
      _name = recipe.name;
      _messageCtrl.text = recipe.message;
      _step = 2; // skip conditions for recipes (pre-configured)
    });
  }

  void _selectTrigger(_TriggerDef trigger) {
    setState(() {
      _selectedTrigger = trigger;
      _threshold = trigger.defaultThreshold;
      _messageCtrl.text = trigger.defaultMessage;
      if (_nameCtrl.text.isEmpty) _nameCtrl.text = trigger.label;
      _name = _nameCtrl.text;
      _step = 1;
    });
  }

  void _goToStep(int step) {
    if (step >= 0 && step <= 2 && _selectedTrigger != null) {
      setState(() => _step = step);
    }
  }

  Future<void> _save() async {
    if (_selectedTrigger == null || _messageCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final data = {
      'name': _nameCtrl.text.trim().isEmpty ? _selectedTrigger!.label : _nameCtrl.text.trim(),
      'trigger_type': _selectedTrigger!.id,
      'message_template': _messageCtrl.text.trim(),
      'is_enabled': _enabled,
      'delivery_methods': _deliveryMethods.toList(),
      'linked_offer_id': _linkedOfferId,
      'trigger_config': {
        if (_selectedTrigger!.hasThreshold && _selectedTrigger!.id == 'upcoming_appointment')
          'hours_before': _threshold
        else if (_selectedTrigger!.hasThreshold)
          'days_threshold': _threshold,
      },
    };

    try {
      final svc = ref.read(ownerServiceProvider);
      if (_isEdit) {
        await svc.updateAutomatedMessage(widget.existingTemplate!['id'] as String, data);
      } else {
        await svc.createAutomatedMessage(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_selectedTrigger != null) _buildStepIndicator(),
            Expanded(child: _buildCurrentStep()),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            onPressed: () {
              if (_step > 0 && !_isEdit) {
                setState(() {
                  if (_step == 1 || (_step == 2 && !_selectedTrigger!.hasThreshold)) {
                    _step = 0;
                    _selectedTrigger = null;
                  } else {
                    _step--;
                  }
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _isEdit ? 'Modifica Automazione' : 'Nuova Automazione',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          if (_selectedTrigger != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (_selectedTrigger!.color).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_selectedTrigger!.icon, size: 14, color: _selectedTrigger!.color),
                const SizedBox(width: 4),
                Text(_selectedTrigger!.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _selectedTrigger!.color)),
              ]),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP INDICATOR
  // ═══════════════════════════════════════════════════════════

  Widget _buildStepIndicator() {
    const steps = ['Quando', 'Condizioni', 'Messaggio'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: List.generate(3, (i) {
          final active = i == _step;
          final done = i < _step;
          return Expanded(
            child: GestureDetector(
              onTap: () => _goToStep(i),
              child: Column(
                children: [
                  Row(children: [
                    if (i > 0) Expanded(child: Container(height: 2, color: done || active ? _selectedTrigger!.color.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08))),
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? _selectedTrigger!.color : done ? _selectedTrigger!.color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
                        border: Border.all(color: active || done ? _selectedTrigger!.color : Colors.white.withValues(alpha: 0.1), width: 1.5),
                      ),
                      child: Center(
                        child: done
                            ? Icon(Icons.check_rounded, size: 14, color: _selectedTrigger!.color)
                            : Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : Colors.grey[500])),
                      ),
                    ),
                    if (i < 2) Expanded(child: Container(height: 2, color: done ? _selectedTrigger!.color.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08))),
                  ]),
                  const SizedBox(height: 6),
                  Text(steps[i], style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? _selectedTrigger!.color : Colors.grey[600])),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP ROUTER
  // ═══════════════════════════════════════════════════════════

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0: return _buildStep0Triggers();
      case 1: return _buildStep1Conditions();
      case 2: return _buildStep2Message();
      default: return const SizedBox();
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP 0: TRIGGER SELECTION + RECIPES
  // ═══════════════════════════════════════════════════════════

  Widget _buildStep0Triggers() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipes section
          Text('Modelli Pronti', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey[300], letterSpacing: 0.3)),
          const SizedBox(height: 4),
          Text('Inizia subito con un\'automazione preconfigurata', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 12),
          ...List.generate(_recipes.length, (i) => _buildRecipeCard(_recipes[i])),
          const SizedBox(height: 24),

          // Custom trigger section
          Row(children: [
            Expanded(child: Divider(color: Colors.grey[800])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('oppure crea da zero', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ),
            Expanded(child: Divider(color: Colors.grey[800])),
          ]),
          const SizedBox(height: 16),
          Text('Scegli un Trigger', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey[300], letterSpacing: 0.3)),
          const SizedBox(height: 12),
          ...List.generate(_triggers.length, (i) => _buildTriggerCard(_triggers[i])),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(_Recipe recipe) {
    return GestureDetector(
      onTap: () => _selectRecipe(recipe),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: recipe.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: recipe.color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: recipe.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(recipe.icon, size: 20, color: recipe.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(recipe.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildTriggerCard(_TriggerDef trigger) {
    return GestureDetector(
      onTap: () => _selectTrigger(trigger),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: trigger.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(trigger.icon, size: 20, color: trigger.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trigger.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(trigger.description, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[700]),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP 1: CONDITIONS
  // ═══════════════════════════════════════════════════════════

  Widget _buildStep1Conditions() {
    final trigger = _selectedTrigger!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Natural language summary
          _buildFlowPreview(),
          const SizedBox(height: 24),

          // Name
          _sectionLabel('Nome Automazione'),
          const SizedBox(height: 8),
          _styledTextField(_nameCtrl, 'es. Promemoria Cliente Inattivo', onChanged: (v) => _name = v),
          const SizedBox(height: 20),

          // Threshold slider
          if (trigger.hasThreshold) ...[
            _sectionLabel(trigger.thresholdLabel ?? 'Soglia'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$_threshold', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: trigger.color)),
                      const SizedBox(width: 6),
                      Text(
                        trigger.id == 'upcoming_appointment' ? 'ore' : 'giorni',
                        style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: trigger.color,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
                      thumbColor: trigger.color,
                      overlayColor: trigger.color.withValues(alpha: 0.15),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _threshold.toDouble().clamp(1, trigger.id == 'upcoming_appointment' ? 72 : 30),
                      min: 1,
                      max: trigger.id == 'upcoming_appointment' ? 72 : 30,
                      divisions: trigger.id == 'upcoming_appointment' ? 71 : 29,
                      label: trigger.id == 'upcoming_appointment' ? '$_threshold ore' : '$_threshold giorni',
                      onChanged: (v) => setState(() => _threshold = v.round()),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        trigger.id == 'upcoming_appointment' ? '1 ora' : '1 giorno',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      Text(
                        trigger.id == 'upcoming_appointment' ? '72 ore' : '30 giorni',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Continue button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => setState(() => _step = 2),
              style: ElevatedButton.styleFrom(
                backgroundColor: trigger.color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continua', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STEP 2: MESSAGE COMPOSER
  // ═══════════════════════════════════════════════════════════

  Widget _buildStep2Message() {
    final trigger = _selectedTrigger!;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Flow preview
                _buildFlowPreview(),
                const SizedBox(height: 20),

                // Message
                _sectionLabel('Messaggio'),
                const SizedBox(height: 8),
                DragTarget<String>(
                  onWillAcceptWithDetails: (_) {
                    if (!_dragOverMessage) setState(() => _dragOverMessage = true);
                    return true;
                  },
                  onLeave: (_) => setState(() => _dragOverMessage = false),
                  onAcceptWithDetails: (details) {
                    setState(() => _dragOverMessage = false);
                    _insertVariable(details.data);
                  },
                  builder: (ctx, candidateData, rejectedData) {
                    return AnimatedContainer(
                      duration: AppAnim.fast,
                      decoration: _dragOverMessage
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: (trigger.color).withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 1)],
                            )
                          : null,
                      child: _styledTextField(
                        _messageCtrl,
                        'Scrivi il tuo messaggio...',
                        maxLines: 5,
                        borderColor: _dragOverMessage ? trigger.color : null,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Tap-to-insert variables
                _sectionLabel('Variabili — tocca o trascina nel messaggio'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: trigger.variables.map((v) => _buildVariableChip(v)).toList(),
                ),
                const SizedBox(height: 20),

                // Linked offer
                if (_offers.isNotEmpty) ...[
                  _sectionLabel('Allega Offerta (opzionale)'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _linkedOfferId != null ? const Color(0xFFA78BFA).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _linkedOfferId,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E1E1E),
                        hint: Text('Nessuna offerta', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                        items: [
                          DropdownMenuItem<String?>(value: null, child: Text('Nessuna offerta', style: TextStyle(color: Colors.grey[500], fontSize: 14))),
                          ..._offers.where((o) => o['is_active'] == true).map((o) {
                            final discount = o['discount_type'] == 'percent'
                                ? '${(o['discount_value'] as num).toInt()}%'
                                : '€${(o['discount_value'] as num).toStringAsFixed(0)}';
                            return DropdownMenuItem<String?>(
                              value: o['id'] as String,
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFA78BFA).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                  child: Text(discount, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFA78BFA))),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(o['title'] as String? ?? '', style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
                              ]),
                            );
                          }),
                        ],
                        onChanged: (v) => setState(() => _linkedOfferId = v),
                      ),
                    ),
                  ),
                  if (_linkedOfferId != null) ...[
                    const SizedBox(height: 10),
                    _sectionLabel('Variabili Offerta — tocca o trascina'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _offerVariables.map((v) => _buildVariableChip(v)).toList(),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],

                // Delivery method
                _sectionLabel('Metodo di Consegna'),
                const SizedBox(height: 8),
                _buildDeliveryToggle('in_app', Icons.notifications_rounded, 'Notifica In-App', 'Inviata direttamente nell\'app'),
                const SizedBox(height: 6),
                _buildDeliveryToggle('email', Icons.email_rounded, 'Email', 'Inviata via SMTP (configura in Impostazioni)'),
                const SizedBox(height: 6),
                _buildDeliveryToggle('whatsapp', Icons.chat_rounded, 'WhatsApp', 'Genera link wa.me · il proprietario invia manualmente'),
                const SizedBox(height: 20),

                // Enable toggle
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      Icon(_enabled ? Icons.power_settings_new_rounded : Icons.power_off_rounded, size: 20, color: _enabled ? const Color(0xFF4ADE80) : Colors.grey[600]),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_enabled ? 'Automazione Attiva' : 'Automazione Disattivata', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(_enabled ? 'Si attiverà automaticamente quando le condizioni sono soddisfatte' : 'Non invierà messaggi fino all\'attivazione', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _enabled = !_enabled),
                        child: Container(
                          width: 48, height: 28,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: _enabled ? const Color(0xFF4ADE80) : Colors.grey[700],
                          ),
                          child: AnimatedAlign(
                            duration: AppAnim.fast,
                            alignment: _enabled ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              width: 22, height: 22,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom save button
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: trigger.color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                disabledBackgroundColor: trigger.color.withValues(alpha: 0.3),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _isEdit ? 'Salva Modifiche' : 'Crea Automazione',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  FLOW PREVIEW (Natural Language Summary)
  // ═══════════════════════════════════════════════════════════

  Widget _buildFlowPreview() {
    final trigger = _selectedTrigger!;
    String condition = '';
    switch (trigger.id) {
      case 'days_inactive':
        condition = 'non si allena da $_threshold giorni';
        break;
      case 'missed_workout':
        condition = 'salta un allenamento programmato';
        break;
      case 'no_show_appointment':
        condition = 'non si presenta a un appuntamento';
        break;
      case 'subscription_canceled':
        condition = 'cancella l\'abbonamento (entro $_threshold giorni)';
        break;
      case 'payment_failed':
        condition = 'ha un pagamento Stripe fallito (entro $_threshold giorni)';
        break;
      case 'upcoming_appointment':
        condition = 'ha un appuntamento nelle prossime $_threshold ore';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [trigger.color.withValues(alpha: 0.08), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: trigger.color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_awesome_rounded, size: 16, color: trigger.color),
            const SizedBox(width: 6),
            Text('Riepilogo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: trigger.color, letterSpacing: 0.3)),
          ]),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[300]),
              children: [
                const TextSpan(text: 'Quando un cliente '),
                TextSpan(text: condition, style: TextStyle(fontWeight: FontWeight.w700, color: trigger.color)),
                const TextSpan(text: ', invia automaticamente una '),
                const TextSpan(text: 'notifica in-app', style: TextStyle(fontWeight: FontWeight.w700)),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════

  void _insertVariable(String variable) {
    final text = _messageCtrl.text;
    final sel = _messageCtrl.selection;
    final pos = sel.isValid ? sel.baseOffset : text.length;
    final newText = text.substring(0, pos) + variable + text.substring(pos);
    _messageCtrl.text = newText;
    _messageCtrl.selection = TextSelection.collapsed(offset: pos + variable.length);
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 0.3));
  }

  Widget _styledTextField(TextEditingController ctrl, String hint, {int maxLines = 1, ValueChanged<String>? onChanged, Color? borderColor}) {
    final border = borderColor ?? Colors.white.withValues(alpha: 0.08);
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[700]),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _selectedTrigger?.color ?? AppColors.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildVariableChip(String variable) {
    // Friendly label mapping
    final labels = {
      '{client_name}': 'Nome Cliente',
      '{days_inactive}': 'Giorni Inattivo',
      '{workout_title}': 'Nome Allenamento',
      '{trainer_name}': 'Nome Trainer',
      '{date}': 'Data',
      '{last_workout_date}': 'Ultimo Allenamento',
      '{appointment_date}': 'Data Appuntamento',
      '{appointment_time}': 'Ora Appuntamento',
      '{plan_name}': 'Nome Piano',
      '{days_since_cancellation}': 'Giorni da Cancellazione',
      '{gym_name}': 'Nome Palestra',
      '{offer_title}': 'Titolo Offerta',
      '{discount_value}': 'Valore Sconto',
      '{discount_symbol}': 'Simbolo (% / €)',
      '{coupon_code}': 'Codice Coupon',
      '{offer_expires}': 'Scadenza Offerta',
      '{checkout_link}': 'Link Pagamento',
      '{amount}': 'Importo',
      '{currency}': 'Valuta',
    };

    final color = _selectedTrigger?.color ?? AppColors.primary;
    final chipWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(labels[variable] ?? variable, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );

    return Draggable<String>(
      data: variable,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.5)),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12)],
            ),
            child: Text(labels[variable] ?? variable, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color, decoration: TextDecoration.none)),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: chipWidget),
      child: GestureDetector(
        onTap: () => _insertVariable(variable),
        child: chipWidget,
      ),
    );
  }

  Widget _buildDeliveryToggle(String method, IconData icon, String title, String subtitle) {
    final selected = _deliveryMethods.contains(method);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selected && _deliveryMethods.length > 1) {
            _deliveryMethods.remove(method);
          } else if (!selected) {
            _deliveryMethods.add(method);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4ADE80).withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? const Color(0xFF4ADE80).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? const Color(0xFF4ADE80) : Colors.grey[600]),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : Colors.grey[500])),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xFF4ADE80) : Colors.transparent,
                border: Border.all(color: selected ? const Color(0xFF4ADE80) : Colors.grey[700]!, width: 2),
              ),
              child: selected ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}
