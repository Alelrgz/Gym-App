import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gym_provider.dart';
import '../../providers/owner_provider.dart';
import '../../widgets/glass_card.dart';

class OwnerFacilitiesScreen extends ConsumerStatefulWidget {
  const OwnerFacilitiesScreen({super.key});

  @override
  ConsumerState<OwnerFacilitiesScreen> createState() => _OwnerFacilitiesScreenState();
}

class _OwnerFacilitiesScreenState extends ConsumerState<OwnerFacilitiesScreen> {
  bool _loading = true;

  List<Map<String, dynamic>> _activityTypes = [];
  List<Map<String, dynamic>> _facilities = [];
  List<Map<String, dynamic>> _bookings = [];

  String? _selectedTypeId;
  String? _selectedTypeName;
  String? _selectedFacilityId;
  String? _selectedFacilityName;

  // Availability editing
  Map<String, dynamic>? _availability;
  bool _showAvailability = false;
  Map<String, List<TextEditingController>> _dayControllers = {};

  static const _dayNames = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
  static const _dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

  String? _lastGymId;

  @override
  void initState() {
    super.initState();
    final gymId = ref.read(activeGymIdProvider);
    if (gymId != null) {
      ref.read(apiClientProvider).activeGymId = gymId;
    }
    _loadAll();
  }

  Future<void> _loadAll() async {
    final svc = ref.read(ownerServiceProvider);
    try {
      final results = await Future.wait([
        svc.getActivityTypes().catchError((_) => <Map<String, dynamic>>[]),
        svc.getFacilityBookings().catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _activityTypes = results[0] as List<Map<String, dynamic>>;
        _bookings = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFacilities(String typeId) async {
    try {
      final data = await ref.read(ownerServiceProvider).getFacilities(typeId);
      if (mounted) setState(() => _facilities = data);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final currentGymId = ref.watch(activeGymIdProvider);
    if (_lastGymId != null && currentGymId != _lastGymId) {
      _lastGymId = currentGymId;
      ref.read(apiClientProvider).activeGymId = currentGymId;
      Future.microtask(() => _loadAll());
    }
    _lastGymId = currentGymId;

    final isDesktop = MediaQuery.of(context).size.width > 1024;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadAll,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isDesktop ? 32 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    if (!isDesktop) ...[
                      Center(
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [AppColors.primary, Color(0xFFFB923C)],
                              ).createShader(bounds),
                              child: const Text('Strutture', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                            ),
                            const SizedBox(height: 2),
                            Text('Gestione strutture', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Strutture', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                          const SizedBox(height: 4),
                          const Text('Gestione Strutture', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Activity Types
                    _buildActivityTypesSection(),
                    const SizedBox(height: 24),

                    // Facilities (shown when type selected)
                    if (_selectedTypeId != null) ...[
                      _buildFacilitiesSection(),
                      const SizedBox(height: 24),
                    ],

                    // Availability (shown when facility selected)
                    if (_showAvailability && _selectedFacilityId != null) ...[
                      _buildAvailabilitySection(),
                      const SizedBox(height: 24),
                    ],

                    // Bookings
                    _buildBookingsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  ACTIVITY TYPES (Teal)
  // ═══════════════════════════════════════════════════════════
  Widget _buildActivityTypesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildZoneBar(const Color(0xFF2DD4BF)),
            const SizedBox(width: 10),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: const Color(0xFF2DD4BF).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.layers_rounded, size: 16, color: Color(0xFF2DD4BF)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tipi di Attività', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2DD4BF), letterSpacing: 0.5)),
                  Text('Tennis, padel, calcio, yoga e altro', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            _buildActionChip('+ Nuovo', const Color(0xFF2DD4BF), onTap: () => _showActivityTypeModal()),
          ],
        ),
        const SizedBox(height: 12),
        if (_activityTypes.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: 32, color: Colors.grey[700]),
                  const SizedBox(height: 8),
                  Text('Nessun tipo di attività', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text('Clicca "+ Nuovo" per iniziare', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                ],
              ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _activityTypes.map((t) {
              final isSelected = t['id'].toString() == _selectedTypeId;
              return GestureDetector(
                onTap: () => _selectActivityType(t),
                child: Container(
                  width: 140,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF2DD4BF).withValues(alpha: 0.1) : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? const Color(0xFF2DD4BF).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    children: [
                      Text(t['emoji'] as String? ?? '', style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(t['name'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                      if (t['description'] != null && (t['description'] as String).isNotEmpty)
                        Text(t['description'] as String, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _showActivityTypeModal(type: t),
                            child: Icon(Icons.edit_rounded, size: 14, color: Colors.grey[500]),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => _deleteActivityType(t),
                            child: Icon(Icons.delete_outline_rounded, size: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  FACILITIES (Orange)
  // ═══════════════════════════════════════════════════════════
  Widget _buildFacilitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildZoneBar(AppColors.primary),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => setState(() { _selectedTypeId = null; _facilities.clear(); _showAvailability = false; }),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.chevron_left_rounded, size: 16, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedTypeName ?? 'Strutture', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.5)),
                  Text('Campi, sale e strutture', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            _buildActionChip('+ Nuovo', AppColors.primary, onTap: () => _showFacilityModal()),
          ],
        ),
        const SizedBox(height: 12),
        if (_facilities.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Center(child: Text('Nessuna struttura', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          )
        else
          ...List.generate(_facilities.length, (i) {
            final f = _facilities[i];
            final name = f['name'] as String? ?? '';
            final duration = (f['slot_duration'] as num?)?.toInt() ?? 60;
            final price = (f['price_per_slot'] as num?)?.toDouble() ?? 0;
            final maxP = (f['max_participants'] as num?)?.toInt();

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                borderRadius: 14,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            '${duration}min · ${price > 0 ? "€${price.toStringAsFixed(2)}" : "Gratuito"}${maxP != null ? " · Max $maxP" : ""}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFFA78BFA)),
                      onPressed: () => _openAvailability(f),
                      tooltip: 'Disponibilità',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_rounded, size: 16, color: Colors.grey[500]),
                      onPressed: () => _showFacilityModal(facility: f),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.grey[500]),
                      onPressed: () => _deleteFacility(f),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  AVAILABILITY (Purple)
  // ═══════════════════════════════════════════════════════════
  void _initDayControllers() {
    // Dispose old controllers
    for (final ctrls in _dayControllers.values) {
      for (final c in ctrls) { c.dispose(); }
    }
    _dayControllers = {};
    for (int d = 0; d < 7; d++) {
      final key = _dayKeys[d];
      final dayData = _availability?[key];
      if (dayData != null && dayData is Map) {
        _dayControllers[key] = [
          TextEditingController(text: dayData['open'] as String? ?? ''),
          TextEditingController(text: dayData['close'] as String? ?? ''),
        ];
      } else {
        _dayControllers[key] = [TextEditingController(), TextEditingController()];
      }
    }
  }

  Widget _buildAvailabilitySection() {
    if (_dayControllers.isEmpty) _initDayControllers();
    final dayControllers = _dayControllers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildZoneBar(const Color(0xFFA78BFA)),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => setState(() => _showAvailability = false),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: const Color(0xFFA78BFA).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.chevron_left_rounded, size: 16, color: Color(0xFFA78BFA)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Disponibilità: ${_selectedFacilityName ?? ""}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFA78BFA), letterSpacing: 0.5)),
                  Text('Orario settimanale', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [const Color(0xFFA78BFA).withValues(alpha: 0.1), Colors.transparent],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              Column(
                children: [
                  ...List.generate(7, (d) {
                    final key = _dayKeys[d];
                    final ctrls = dayControllers[key]!;
                    final hasTime = ctrls[0].text.isNotEmpty || ctrls[1].text.isNotEmpty;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(_dayNames[d], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            child: _timeInput(ctrls[0], 'Apertura'),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('-', style: TextStyle(color: Colors.white38)),
                          ),
                          Expanded(
                            child: _timeInput(ctrls[1], 'Chiusura'),
                          ),
                          if (hasTime)
                            GestureDetector(
                              onTap: () {
                                for (int i = 0; i < 7; i++) {
                                  if (i == d) continue;
                                  final otherKey = _dayKeys[i];
                                  dayControllers[otherKey]![0].text = ctrls[0].text;
                                  dayControllers[otherKey]![1].text = ctrls[1].text;
                                }
                                setState(() {});
                              },
                              child: Tooltip(
                                message: 'Copia a tutti i giorni',
                                child: Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFA78BFA).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.copy_all_rounded, size: 16, color: Color(0xFFA78BFA)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _saveAvailability(dayControllers),
                      child: const Text('Salva Disponibilità', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickTime(TextEditingController ctrl) async {
    TimeOfDay initial = TimeOfDay.now();
    if (ctrl.text.contains(':')) {
      final parts = ctrl.text.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      initial = TimeOfDay(hour: h, minute: m);
    }
    final time = await showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.input,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
          timePickerTheme: const TimePickerThemeData(
            entryModeIconColor: Color(0xFFA78BFA),
          ),
        ),
        child: MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
      ),
    );
    if (time != null) {
      ctrl.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  void _autoCompleteTime(TextEditingController ctrl) {
    final text = ctrl.text.replaceAll(RegExp(r'[^\d:]'), '').trim();
    if (text.isEmpty) return;
    if (text.contains(':')) {
      final parts = text.split(':');
      final h = (int.tryParse(parts[0]) ?? 0).clamp(0, 23);
      final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0).clamp(0, 59) : 0;
      ctrl.text = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    } else {
      final h = (int.tryParse(text) ?? 0).clamp(0, 23);
      ctrl.text = '${h.toString().padLeft(2, '0')}:00';
    }
    setState(() {});
  }

  Widget _timeInput(TextEditingController ctrl, String hint) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus && ctrl.text.isNotEmpty) _autoCompleteTime(ctrl);
      },
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 13, color: Colors.white),
        keyboardType: TextInputType.datetime,
        inputFormatters: [_TimeInputFormatter()],
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[700], fontSize: 12),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFA78BFA))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          suffixIcon: GestureDetector(
            onTap: () => _pickTime(ctrl),
            child: const Icon(Icons.access_time, size: 18, color: Color(0xFFA78BFA)),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  BOOKINGS (Blue)
  // ═══════════════════════════════════════════════════════════
  Widget _buildBookingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildZoneBar(const Color(0xFF60A5FA)),
            const SizedBox(width: 10),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: const Color(0xFF60A5FA).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.event_available_rounded, size: 16, color: Color(0xFF60A5FA)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Prenotazioni Imminenti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF60A5FA), letterSpacing: 0.5)),
                  Text('Prenotazioni clienti', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_bookings.isEmpty)
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Center(child: Text('Nessuna prenotazione imminente', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _bookings.length,
              separatorBuilder: (_, _i) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final b = _bookings[i];
                return GlassCard(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 12,
                  child: Row(
                    children: [
                      Icon(Icons.event_rounded, size: 18, color: const Color(0xFF60A5FA)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b['facility_name'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(
                              '${b['date'] ?? ''} ${b['start_time'] ?? ''} - ${b['end_time'] ?? ''} · ${b['client_name'] ?? ''}',
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════════════════════════
  void _selectActivityType(Map<String, dynamic> type) {
    final id = type['id'].toString();
    setState(() {
      _selectedTypeId = id;
      _selectedTypeName = type['name'] as String?;
      _showAvailability = false;
      _facilities = [];
    });
    _loadFacilities(id);
  }

  Future<void> _openAvailability(Map<String, dynamic> facility) async {
    final id = facility['id'].toString();
    try {
      final avail = await ref.read(ownerServiceProvider).getFacilityAvailability(id);
      // Backend returns a list of slots — convert to day-keyed map for the UI
      final byDay = <String, dynamic>{};
      for (final slot in avail) {
        if (slot is Map) {
          byDay[slot['day_of_week'] ?? ''] = {
            'open': slot['start_time'] ?? '',
            'close': slot['end_time'] ?? '',
          };
        }
      }
      if (mounted) {
        _availability = byDay;
        _initDayControllers();
        setState(() {
          _selectedFacilityId = id;
          _selectedFacilityName = facility['name'] as String?;
          _showAvailability = true;
        });
      }
    } catch (_) {
      if (mounted) {
        _availability = {};
        _initDayControllers();
        setState(() {
          _selectedFacilityId = id;
          _selectedFacilityName = facility['name'] as String?;
          _showAvailability = true;
        });
      }
    }
  }

  Future<void> _saveAvailability(Map<String, List<TextEditingController>> ctrls) async {
    if (_selectedFacilityId == null) return;
    final slots = <Map<String, dynamic>>[];
    for (final key in _dayKeys) {
      final open = ctrls[key]![0].text.trim();
      final close = ctrls[key]![1].text.trim();
      if (open.isNotEmpty && close.isNotEmpty) {
        slots.add({'day_of_week': key, 'start_time': open, 'end_time': close});
      }
    }
    try {
      await ref.read(ownerServiceProvider).setFacilityAvailability(_selectedFacilityId!, {'availability': slots});
      // Update local state so UI stays in sync
      final byDay = <String, dynamic>{};
      for (final s in slots) {
        byDay[s['day_of_week']] = {'open': s['start_time'], 'close': s['end_time']};
      }
      _availability = byDay;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disponibilità salvata')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  // ── Activity Type Modal ────────────────────────────────
  void _showActivityTypeModal({Map<String, dynamic>? type}) {
    final isEdit = type != null;
    final nameCtrl = TextEditingController(text: type?['name'] as String? ?? '');
    final emojiCtrl = TextEditingController(text: type?['emoji'] as String? ?? '');
    final descCtrl = TextEditingController(text: type?['description'] as String? ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isEdit ? 'Modifica Tipo' : 'Nuovo Tipo di Attività', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            _modalLabel('Nome'),
            _modalInput(nameCtrl, 'es. Tennis, Padel, Calcio'),
            const SizedBox(height: 12),
            _modalLabel('Emoji (opzionale)'),
            _modalInput(emojiCtrl, '🎾'),
            const SizedBox(height: 12),
            _modalLabel('Descrizione (opzionale)'),
            _modalInput(descCtrl, 'Breve descrizione'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final data = {'name': nameCtrl.text, 'emoji': emojiCtrl.text, 'description': descCtrl.text};
                      try {
                        if (isEdit) {
                          await ref.read(ownerServiceProvider).updateActivityType(type!['id'].toString(), data);
                        } else {
                          await ref.read(ownerServiceProvider).createActivityType(data);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadAll();
                      } catch (e) {
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Errore: $e')));
                      }
                    },
                    child: const Text('Salva'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                    child: const Text('Annulla'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteActivityType(Map<String, dynamic> type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Elimina Tipo'),
        content: Text('Eliminare "${type['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina', style: TextStyle(color: Color(0xFFF87171)))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(ownerServiceProvider).deleteActivityType(type['id'].toString());
        if (_selectedTypeId == type['id'].toString()) {
          _selectedTypeId = null;
          _facilities.clear();
        }
        _loadAll();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  // ── Facility Modal ─────────────────────────────────────
  void _showFacilityModal({Map<String, dynamic>? facility}) {
    final isEdit = facility != null;
    final nameCtrl = TextEditingController(text: facility?['name'] as String? ?? '');
    final durationCtrl = TextEditingController(text: (facility?['slot_duration'] ?? 60).toString());
    final priceCtrl = TextEditingController(text: (facility?['price_per_slot'] as num?)?.toString() ?? '');
    final maxPCtrl = TextEditingController(text: (facility?['max_participants'] as num?)?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isEdit ? 'Modifica Struttura' : 'Nuova Struttura', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            _modalLabel('Nome'),
            _modalInput(nameCtrl, 'es. Campo 1, Sala A'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _modalLabel('Durata Slot (min)'),
                  _modalInput(durationCtrl, '60', keyboardType: TextInputType.number),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _modalLabel('Prezzo per Slot'),
                  _modalInput(priceCtrl, '0 = gratuito', keyboardType: TextInputType.number),
                ])),
              ],
            ),
            const SizedBox(height: 12),
            _modalLabel('Max Partecipanti (opzionale)'),
            _modalInput(maxPCtrl, 'Lascia vuoto per prenotazione singola', keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final data = {
                        'name': nameCtrl.text,
                        'slot_duration': int.tryParse(durationCtrl.text) ?? 60,
                        'price_per_slot': double.tryParse(priceCtrl.text) ?? 0,
                        'activity_type_id': _selectedTypeId,
                        if (maxPCtrl.text.isNotEmpty) 'max_participants': int.tryParse(maxPCtrl.text),
                      };
                      try {
                        if (isEdit) {
                          await ref.read(ownerServiceProvider).updateFacility(facility!['id'].toString(), data);
                        } else {
                          await ref.read(ownerServiceProvider).createFacility(data);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (_selectedTypeId != null) _loadFacilities(_selectedTypeId!);
                      } catch (e) {
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Errore: $e')));
                      }
                    },
                    child: const Text('Salva'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                    child: const Text('Annulla'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteFacility(Map<String, dynamic> f) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Elimina Struttura'),
        content: Text('Eliminare "${f['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina', style: TextStyle(color: Color(0xFFF87171)))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(ownerServiceProvider).deleteFacility(f['id'].toString());
        if (_selectedTypeId != null) _loadFacilities(_selectedTypeId!);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════
  Widget _buildZoneBar(Color color) {
    return Container(width: 4, height: 32, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)));
  }

  Widget _buildActionChip(String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }

  Widget _modalLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey[500], letterSpacing: 0.5)),
    );
  }

  Widget _modalInput(TextEditingController ctrl, String hint, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[700]),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

/// Formats text input as HH:MM — auto-inserts colon after 2 digits,
/// clamps hours to 0-23 and minutes to 0-59.
class _TimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Strip non-digits
    String digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length > 4) digits = digits.substring(0, 4);

    String formatted = '';
    if (digits.isEmpty) return newValue.copyWith(text: '');

    if (digits.length <= 2) {
      formatted = digits;
    } else {
      // Clamp hours
      int h = int.parse(digits.substring(0, 2));
      if (h > 23) h = 23;
      // Clamp minutes
      String minPart = digits.substring(2);
      if (minPart.length == 2) {
        int m = int.parse(minPart);
        if (m > 59) m = 59;
        minPart = m.toString().padLeft(2, '0');
      }
      formatted = '${h.toString().padLeft(2, '0')}:$minPart';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
