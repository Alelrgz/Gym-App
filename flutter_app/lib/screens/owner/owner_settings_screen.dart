import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../providers/owner_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gym_provider.dart';
import '../../models/user.dart';

class OwnerSettingsScreen extends ConsumerStatefulWidget {
  const OwnerSettingsScreen({super.key});

  @override
  ConsumerState<OwnerSettingsScreen> createState() => _OwnerSettingsScreenState();
}

class _OwnerSettingsScreenState extends ConsumerState<OwnerSettingsScreen> {
  bool _loading = true;

  // Gym info
  String _gymName = '';
  String _gymCode = '';
  String? _gymLogo;

  // Stripe
  String _stripeStatus = 'checking'; // checking, not_connected, pending, connected

  // POS Terminal
  String _terminalStatus = 'checking'; // checking, needs_connect, no_location, no_reader, registered
  bool _isSandbox = false;
  String? _readerLabel;
  String? _readerStatus;
  String _readerTab = 'code';
  bool _turnstileExpanded = false;

  // Shower
  int _showerTimer = 8;
  int _showerLimit = 3;

  // Turnstile
  String _deviceApiKey = '';
  int _gateDuration = 5;

  // Commissions
  double _defaultCommissionRate = 0;
  List<Map<String, dynamic>> _trainers = [];

  // SMTP
  String _smtpHost = '';
  int _smtpPort = 587;
  String _smtpUser = '';
  String _smtpFromEmail = '';
  String _smtpFromName = '';
  bool _smtpPasswordSet = false;
  bool _smtpConfigured = false;
  bool _smtpTesting = false;
  String? _smtpOAuthProvider;
  bool _smtpOAuthConnected = false;

  // Push Notifications (FCM)
  bool _fcmConfigured = false;

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
        svc.getGymSettings().catchError((_) => <String, dynamic>{}),
        svc.getGymCode().catchError((_) => ''),
        svc.getStripeStatus().catchError((_) => <String, dynamic>{}),
        svc.getShowerSettings().catchError((_) => <String, dynamic>{}),
        svc.getApprovedTrainers().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;

      final settings = results[0] as Map<String, dynamic>;
      final stripeData = results[2] as Map<String, dynamic>;
      final showerData = results[3] as Map<String, dynamic>;

      setState(() {
        _gymName = settings['gym_name'] as String? ?? '';
        _gymLogo = settings['gym_logo'] as String?;
        _gymCode = results[1] as String;
        _deviceApiKey = settings['device_api_key'] as String? ?? '';
        _gateDuration = (settings['gate_duration'] as num?)?.toInt() ?? 5;
        _defaultCommissionRate = (settings['default_commission_rate'] as num?)?.toDouble() ?? 0;

        // Stripe status
        final charges = stripeData['charges_enabled'] == true;
        final details = stripeData['details_submitted'] == true;
        if (charges && details) {
          _stripeStatus = 'connected';
        } else if (stripeData['account_id'] != null) {
          _stripeStatus = 'pending';
        } else {
          _stripeStatus = 'not_connected';
        }

        // Shower
        _showerTimer = (showerData['timer_minutes'] as num?)?.toInt() ?? 8;
        _showerLimit = (showerData['daily_limit'] as num?)?.toInt() ?? 3;

        _trainers = results[4] as List<Map<String, dynamic>>;
        _loading = false;
      });

      // Load terminal status separately
      _loadTerminalStatus();
      _loadSmtpSettings();
      _loadFcmSettings();
    } catch (e) {
      debugPrint('Settings _loadAll error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }


  Future<void> _loadTerminalStatus() async {
    try {
      final svc = ref.read(ownerServiceProvider);
      final testMode = await svc.getTerminalTestMode().catchError((_) => <String, dynamic>{});
      _isSandbox = testMode['test_mode'] == true;

      final readers = await svc.getTerminalReaders().catchError((_) => <Map<String, dynamic>>[]);
      if (mounted) {
        setState(() {
          if (_stripeStatus != 'connected' && _stripeStatus != 'pending') {
            _terminalStatus = 'needs_connect';
          } else if (readers.isEmpty) {
            _terminalStatus = 'no_reader';
          } else {
            _terminalStatus = 'registered';
            _readerLabel = readers.first['label'] as String? ?? 'Lettore';
            _readerStatus = readers.first['status'] as String? ?? 'Online';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _terminalStatus = 'needs_connect');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reload when active gym changes (e.g. user switches gym on dashboard)
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
          : SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 32 : 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
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
                            child: const Text('Impostazioni', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Impostazioni', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                        const SizedBox(height: 4),
                        Text(_gymName.isNotEmpty ? _gymName : 'La Mia Palestra', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Settings cards - single column layout
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cards = [
                        _buildProfileCard(),
                        _buildGymInfoCard(),
                        _buildSmtpCard(),
                        _buildPushNotificationCard(),
                        _buildStripeCard(),
                        _buildPosCard(),
                        _buildShowerCard(),
                        _buildTurnstileCard(),
                        _buildCommissionsCard(),
                        _buildImportCard(),
                        _buildLogoutCard(),
                      ];

                      return Column(
                        children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PROFILE HEADER
  // ═══════════════════════════════════════════════════════════
  Widget _buildProfileCard() {
    return _settingsCard(
      child: Row(
        children: [
          // Logo
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _gymLogo != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network('${ApiConfig.baseUrl}$_gymLogo', fit: BoxFit.cover, errorBuilder: (_, _, a) => _logoPlaceholder()),
                  )
                : _logoPlaceholder(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_gymName.isNotEmpty ? _gymName : 'La Mia Palestra', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text('Proprietario Palestra · Attivo', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoPlaceholder() {
    return Center(
      child: Text(
        _gymName.isNotEmpty ? _gymName[0].toUpperCase() : 'G',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary),
      ),
    );
  }

  Future<void> _loadSmtpSettings() async {
    try {
      final data = await ref.read(ownerServiceProvider).getSmtpSettings();
      if (mounted) {
        setState(() {
          _smtpHost = data['smtp_host'] as String? ?? '';
          _smtpPort = (data['smtp_port'] as num?)?.toInt() ?? 587;
          _smtpUser = data['smtp_user'] as String? ?? '';
          _smtpFromEmail = data['smtp_from_email'] as String? ?? '';
          _smtpFromName = data['smtp_from_name'] as String? ?? '';
          _smtpPasswordSet = data['smtp_password_set'] as bool? ?? false;
          _smtpConfigured = data['is_configured'] as bool? ?? false;
          _smtpOAuthProvider = data['oauth_provider'] as String?;
          _smtpOAuthConnected = data['oauth_connected'] as bool? ?? false;
        });
      }
    } catch (_) {}

  }

  Future<void> _loadFcmSettings() async {
    // Push notifications are now managed centrally by Heaven's Fit — always configured
    if (mounted) setState(() => _fcmConfigured = true);
  }

  // ═══════════════════════════════════════════════════════════
  //  GYM INFO
  // ═══════════════════════════════════════════════════════════
  Widget _buildGymInfoCard() {
    final gyms = ref.watch(ownerGymsProvider);
    final activeGymId = ref.watch(activeGymIdProvider);

    return _settingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle('Palestra')),
              GestureDetector(
                onTap: _showCreateGymDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('Aggiungi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Gym selector (when multiple gyms)
          if (gyms.length > 1) ...[
            const SizedBox(height: 12),
            _fieldLabel('Seleziona Palestra'),
            ...gyms.map((gym) {
              final isActive = gym.id == activeGymId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  onTap: () => _switchToGym(gym),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive ? AppColors.primary.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.primary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Center(
                            child: Text(
                              gym.name.isNotEmpty ? gym.name[0].toUpperCase() : 'G',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isActive ? AppColors.primary : Colors.grey[500]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(gym.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ),
                        if (isActive)
                          Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary)
                        else
                          Text('Seleziona', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          _fieldLabel('Nome Palestra'),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(_gymName.isNotEmpty ? _gymName : '—', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
                ),
              ),
              const SizedBox(width: 8),
              _iconBtn(Icons.edit_rounded, onTap: _showGymNameModal),
            ],
          ),
          const SizedBox(height: 12),
          _fieldLabel('Codice Palestra'),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    _gymCode.isNotEmpty ? _gymCode : '------',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary, fontFamily: 'monospace', letterSpacing: 1.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _actionBtn('Copia', onTap: () {
                Clipboard.setData(ClipboardData(text: _gymCode));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Codice copiato!')));
              }),
            ],
          ),
          const SizedBox(height: 4),
          Text('Condividi con trainer e clienti', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _switchToGym(GymInfo gym) {
    ref.read(activeGymIdProvider.notifier).state = gym.id;
    ref.read(apiClientProvider).activeGymId = gym.id;
    // Reload settings for the new gym
    _loadAll();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Palestra attiva: ${gym.name}')),
    );
  }

  void _showCreateGymDialog() {
    final nameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nuova Palestra'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(hintText: 'Nome della nuova palestra'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final svc = ref.read(ownerServiceProvider);
                final result = await svc.createGym(name);
                final newGym = GymInfo(
                  id: result['id'] as String,
                  name: result['name'] as String,
                  logo: result['logo'] as String?,
                );
                // Update the auth state's gym list
                final authNotifier = ref.read(authProvider.notifier);
                final currentUser = ref.read(authProvider).user;
                if (currentUser != null) {
                  final updatedGyms = [...currentUser.gyms, newGym];
                  authNotifier.updateUser(currentUser.copyWith(gyms: updatedGyms));
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Palestra "${newGym.name}" creata!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Errore: $e')),
                  );
                }
              }
            },
            child: const Text('Crea'),
          ),
        ],
      ),
    );
  }

  void _showGymNameModal() {
    final nameCtrl = TextEditingController(text: _gymName);
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Modifica Nome Palestra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(hintText: 'Nuovo nome palestra'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Conferma con password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(ownerServiceProvider).updateGymName(nameCtrl.text, passCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() => _gymName = nameCtrl.text);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Errore: $e')));
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SMTP EMAIL
  // ═══════════════════════════════════════════════════════════
  Widget _buildSmtpCard() {
    final oauthLabel = _smtpOAuthProvider == 'google' ? 'Google' : _smtpOAuthProvider == 'microsoft' ? 'Microsoft' : null;

    return _settingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('Email Automatiche'),
              Row(
                children: [
                  if (_smtpOAuthConnected) ...[
                    _badge(oauthLabel ?? 'OAuth', const Color(0xFF60A5FA)),
                    const SizedBox(width: 6),
                  ],
                  _badge(
                    _smtpConfigured ? 'Attivo' : 'Non Configurato',
                    _smtpConfigured ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _smtpOAuthConnected
              ? 'Email collegate tramite ${oauthLabel ?? 'OAuth'}. Nessuna password necessaria.'
              : 'Configura SMTP per inviare email automatiche ai clienti.',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          if (_smtpConfigured) ...[
            _smtpInfoRow(_smtpOAuthConnected ? 'Metodo' : 'Server', _smtpOAuthConnected ? 'OAuth2 (${oauthLabel ?? _smtpOAuthProvider})' : _smtpHost),
            if (!_smtpOAuthConnected) _smtpInfoRow('Porta', '$_smtpPort'),
            _smtpInfoRow('Email', _smtpUser),
            _smtpInfoRow('Mittente', _smtpFromEmail.isNotEmpty ? _smtpFromEmail : _smtpUser),
            _smtpInfoRow('Nome', _smtpFromName),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_smtpOAuthConnected) ...[
                  Expanded(
                    child: _actionBtn('Disconnetti', icon: Icons.link_off_rounded, onTap: _disconnectOAuth),
                  ),
                ] else ...[
                  Expanded(
                    child: _actionBtn('Modifica', icon: Icons.edit_rounded, onTap: _showSmtpModal),
                  ),
                ],
                const SizedBox(width: 8),
                _actionBtn(
                  _smtpTesting ? 'Invio...' : 'Test Email',
                  icon: Icons.send_rounded,
                  onTap: _smtpTesting ? null : _testSmtp,
                ),
              ],
            ),
          ] else ...[
            _guideBox([
              'Metodo consigliato: accedi con Google o Microsoft',
              'Autorizzi l\'invio email dal tuo account — nessuna password da inserire',
              'Le email arriveranno ai tuoi clienti con il tuo indirizzo',
              'In alternativa, configura un server SMTP manuale',
            ]),
            const SizedBox(height: 12),
            // OAuth sign-in buttons
            ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _startOAuth('google'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                    ),
                    icon: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF4285F4))),
                    label: const Text('Accedi con Google'),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _startOAuth('microsoft'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F2F2F),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.window_rounded, size: 18, color: Color(0xFF00A4EF)),
                    label: const Text('Accedi con Microsoft'),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('oppure', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    ),
                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                  ],
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showSmtpModal,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                icon: const Icon(Icons.email_rounded, size: 16),
                label: const Text('Configura SMTP Manuale'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startOAuth(String provider) async {
    try {
      final data = await ref.read(ownerServiceProvider).getSmtpOAuthAuthorizeUrl(provider);
      final url = data['url'] as String?;
      if (url != null) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        // Show hint to reload after completing OAuth
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Completa l\'accesso nel browser, poi torna qui.'),
              duration: const Duration(seconds: 8),
              action: SnackBarAction(label: 'Ricarica', onPressed: _loadSmtpSettings),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('OAuth non disponibile: $e'),
          backgroundColor: const Color(0xFFF87171),
        ));
      }
    }
  }

  Future<void> _disconnectOAuth() async {
    try {
      await ref.read(ownerServiceProvider).disconnectSmtpOAuth();
      _loadSmtpSettings();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OAuth disconnesso')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Widget _smtpInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
          Expanded(child: Text(value.isNotEmpty ? value : '—', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  static const _smtpPresets = <String, Map<String, dynamic>>{
    'Gmail': {'host': 'smtp.gmail.com', 'port': 587, 'hint': 'Usa una App Password di Google'},
    'Outlook': {'host': 'smtp.office365.com', 'port': 587, 'hint': 'Usa la password del tuo account Microsoft'},
    'Aruba': {'host': 'smtps.aruba.it', 'port': 465, 'hint': 'Usa le credenziali della tua casella Aruba'},
    'Yahoo': {'host': 'smtp.mail.yahoo.com', 'port': 587, 'hint': 'Genera una App Password da Yahoo'},
    'Libero': {'host': 'smtp.libero.it', 'port': 465, 'hint': 'Usa le credenziali del tuo account Libero'},
    'Personalizzato': {'host': '', 'port': 587, 'hint': 'Inserisci i dati del tuo server SMTP'},
  };

  void _showSmtpModal() {
    final hostCtrl = TextEditingController(text: _smtpHost);
    final portCtrl = TextEditingController(text: '$_smtpPort');
    final userCtrl = TextEditingController(text: _smtpUser);
    final passCtrl = TextEditingController();
    final fromEmailCtrl = TextEditingController(text: _smtpFromEmail);
    final fromNameCtrl = TextEditingController(text: _smtpFromName);

    // Detect current preset
    String selectedPreset = 'Personalizzato';
    for (final entry in _smtpPresets.entries) {
      if (entry.value['host'] == _smtpHost && _smtpHost.isNotEmpty) {
        selectedPreset = entry.key;
        break;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final preset = _smtpPresets[selectedPreset]!;
          final hintText = preset['hint'] as String;

          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Configurazione SMTP', style: TextStyle(fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Seleziona il tuo provider email:', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _smtpPresets.keys.map((name) {
                      final isSelected = name == selectedPreset;
                      return GestureDetector(
                        onTap: () {
                          final p = _smtpPresets[name]!;
                          setModalState(() {
                            selectedPreset = name;
                            if (name != 'Personalizzato') {
                              hostCtrl.text = p['host'] as String;
                              portCtrl.text = '${p['port']}';
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? AppColors.primary : Colors.grey[400],
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: AppColors.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(hintText, style: TextStyle(fontSize: 10, color: Colors.grey[400]))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // OAuth shortcut for Gmail/Outlook
                  if (selectedPreset == 'Gmail' || selectedPreset == 'Outlook') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _startOAuth(selectedPreset == 'Gmail' ? 'google' : 'microsoft');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedPreset == 'Gmail' ? Colors.white : const Color(0xFF2F2F2F),
                          foregroundColor: selectedPreset == 'Gmail' ? Colors.black87 : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: selectedPreset == 'Gmail'
                          ? const Text('G', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF4285F4)))
                          : const Icon(Icons.window_rounded, size: 16, color: Color(0xFF00A4EF)),
                        label: Text('Accedi con ${selectedPreset == 'Gmail' ? 'Google' : 'Microsoft'}'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('oppure manuale', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        ),
                        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (selectedPreset == 'Personalizzato') ...[
                    _buildInput(hostCtrl, 'Server SMTP'),
                    const SizedBox(height: 8),
                    _buildInput(portCtrl, 'Porta', keyboardType: TextInputType.number),
                    const SizedBox(height: 8),
                  ],
                  _buildInput(userCtrl, 'Email / Username'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _smtpPasswordSet ? 'Password (lascia vuoto per non cambiare)' : 'Password / App Password',
                      hintStyle: TextStyle(color: Colors.grey[700]),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInput(fromEmailCtrl, 'Email Mittente (opzionale)'),
                  const SizedBox(height: 8),
                  _buildInput(fromNameCtrl, 'Nome Mittente (es. La Mia Palestra)'),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
              ElevatedButton(
                onPressed: () async {
                  final data = <String, dynamic>{
                    'smtp_host': hostCtrl.text.trim(),
                    'smtp_port': int.tryParse(portCtrl.text.trim()) ?? 587,
                    'smtp_user': userCtrl.text.trim(),
                    'smtp_from_email': fromEmailCtrl.text.trim(),
                    'smtp_from_name': fromNameCtrl.text.trim(),
                  };
                  if (passCtrl.text.isNotEmpty) data['smtp_password'] = passCtrl.text;

                  try {
                    await ref.read(ownerServiceProvider).updateSmtpSettings(data);
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadSmtpSettings();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMTP salvato!')));
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Errore: $e')));
                  }
                },
                child: const Text('Salva'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _testSmtp() async {
    setState(() => _smtpTesting = true);
    try {
      final result = await ref.read(ownerServiceProvider).testSmtpSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] as String? ?? 'Email di test inviata!'),
          backgroundColor: const Color(0xFF4ADE80),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: const Color(0xFFF87171),
        ));
      }
    } finally {
      if (mounted) setState(() => _smtpTesting = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  PUSH NOTIFICATIONS (FCM)
  // ═══════════════════════════════════════════════════════════
  Widget _buildPushNotificationCard() {
    return _settingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('Notifiche Push'),
              _badge(
                _fcmConfigured ? 'Attivo' : 'Non Configurato',
                _fcmConfigured ? const Color(0xFF4ADE80) : Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Le notifiche push arrivano sul telefono del cliente anche quando l\'app è chiusa.',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          if (_fcmConfigured) ...[
            Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF4ADE80).withValues(alpha: 0.15)),
                  child: const Center(child: Icon(Icons.check_rounded, size: 18, color: Color(0xFF4ADE80))),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Firebase Configurato', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4ADE80))),
                    Text('I clienti riceveranno notifiche push', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _actionBtn('Modifica Server Key', icon: Icons.edit_rounded, onTap: _showFcmModal),
          ] else ...[
            Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF4ADE80).withValues(alpha: 0.15)),
                  child: const Center(child: Icon(Icons.cloud_done_rounded, size: 18, color: Color(0xFF4ADE80))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Gestite da Heaven's Fit", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4ADE80))),
                      Text('Le notifiche push funzionano automaticamente — nessuna configurazione necessaria.', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showFcmModal() {
    final keyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Firebase Server Key', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Vai su Firebase Console > Impostazioni Progetto > Cloud Messaging e copia la Server Key.', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 12),
            TextField(
              controller: keyCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Incolla la Server Key qui...',
                hintStyle: TextStyle(color: Colors.grey[700]),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(ownerServiceProvider).updateFcmSettings({'fcm_server_key': keyCtrl.text.trim()});
                if (ctx.mounted) Navigator.pop(ctx);
                _loadFcmSettings();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firebase configurato!')));
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Errore: $e')));
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  STRIPE PAYMENTS
  // ═══════════════════════════════════════════════════════════
  Widget _buildStripeCard() {
    Color badgeColor;
    String badgeText;
    switch (_stripeStatus) {
      case 'connected':
        badgeColor = const Color(0xFF4ADE80);
        badgeText = 'Attivo';
      case 'pending':
        badgeColor = const Color(0xFFFACC15);
        badgeText = 'In Attesa';
      case 'not_connected':
        badgeColor = const Color(0xFFF87171);
        badgeText = 'Non Configurato';
      default:
        badgeColor = const Color(0xFFFACC15);
        badgeText = 'Verifica...';
    }

    return _settingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('Pagamenti Stripe'),
              _badge(badgeText, badgeColor),
            ],
          ),
          const SizedBox(height: 12),
          if (_stripeStatus == 'not_connected') ...[
            Text('Ricevi pagamenti direttamente sul tuo conto. Gratuito e sicuro.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 12),
            _guideBox([
              'Premi "Connetti con Stripe" qui sotto',
              'Crea un account Stripe (o accedi se ne hai già uno)',
              'Completa la verifica — ci vogliono 2 minuti',
              'Torna nell\'app — sei pronto a ricevere pagamenti!',
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startStripeConnect,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF635BFF), padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.payment_rounded, size: 16),
                label: const Text('Connetti con Stripe'),
              ),
            ),
          ] else if (_stripeStatus == 'pending') ...[
            Text('Configurazione incompleta. Completa la registrazione.', style: TextStyle(fontSize: 12, color: const Color(0xFFFACC15))),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startStripeConnect,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFACC15).withValues(alpha: 0.2), foregroundColor: const Color(0xFFFACC15)),
                child: const Text('Continua Configurazione →'),
              ),
            ),
          ] else if (_stripeStatus == 'connected') ...[
            Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF4ADE80).withValues(alpha: 0.15)),
                  child: const Center(child: Icon(Icons.check_rounded, size: 18, color: Color(0xFF4ADE80))),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pagamenti Attivi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4ADE80))),
                    Text('I pagamenti arrivano sul tuo conto', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _actionBtn('Vedi Dashboard', icon: Icons.attach_money_rounded, onTap: _openStripeDashboard),
          ],
        ],
      ),
    );
  }

  Future<void> _startStripeConnect() async {
    try {
      final data = await ref.read(ownerServiceProvider).startStripeOnboard();
      final url = data['url'] as String?;
      if (url != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Apri: $url')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  Future<void> _openStripeDashboard() async {
    try {
      final data = await ref.read(ownerServiceProvider).getStripeDashboard();
      final url = data['url'] as String?;
      if (url != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dashboard: $url')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  POS TERMINAL
  // ═══════════════════════════════════════════════════════════
  Widget _buildPosCard() {
    final terminalBadgeColor = _terminalStatus == 'registered' ? const Color(0xFF4ADE80) : Colors.grey[600]!;
    final terminalBadgeText = switch (_terminalStatus) {
      'registered' => 'Online',
      'no_reader' => 'Non Configurato',
      'no_location' => 'Richiede Posizione',
      'needs_connect' => 'Richiede Pagamenti',
      _ => 'Verifica...',
    };

    final regCodeCtrl = TextEditingController();
    final labelCtrl = TextEditingController(text: 'Reception');
    final readerIdCtrl = TextEditingController();
    final addrLine1Ctrl = TextEditingController();
    final addrCityCtrl = TextEditingController();
    final addrPostalCtrl = TextEditingController();
    final addrStateCtrl = TextEditingController();

    return _settingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('Terminale POS'),
              Row(
                children: [
                  if (_isSandbox) ...[
                    _badge('Sandbox', const Color(0xFFFACC15)),
                    const SizedBox(width: 6),
                  ],
                  _badge(terminalBadgeText, terminalBadgeColor),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_terminalStatus == 'needs_connect')
            Text('Configura prima i pagamenti Stripe per abilitare il terminale POS.', style: TextStyle(fontSize: 12, color: Colors.grey[600]))
          else if (_terminalStatus == 'no_location') ...[
            Text('Inserisci l\'indirizzo della palestra per registrare un lettore POS.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 10),
            _buildInput(addrLine1Ctrl, 'Indirizzo'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildInput(addrCityCtrl, 'Città')),
                const SizedBox(width: 8),
                Expanded(child: _buildInput(addrPostalCtrl, 'CAP')),
              ],
            ),
            const SizedBox(height: 8),
            _buildInput(addrStateCtrl, 'Provincia (es. MI)'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await ref.read(ownerServiceProvider).createTerminalLocation({
                      'address': {
                        'line1': addrLine1Ctrl.text,
                        'city': addrCityCtrl.text,
                        'postal_code': addrPostalCtrl.text,
                        'country': 'IT',
                        'state': addrStateCtrl.text,
                      },
                    });
                    _loadTerminalStatus();
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
                  }
                },
                child: const Text('Crea Posizione Terminale'),
              ),
            ),
          ] else if (_terminalStatus == 'no_reader') ...[
            // Tab selector
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(3),
              child: StatefulBuilder(
                builder: (ctx, setTabState) => Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _tabBtn('Codice Lettore', _readerTab == 'code', () { setState(() => _readerTab = 'code'); setTabState(() {}); })),
                        Expanded(child: _tabBtn('ID Esistente', _readerTab == 'id', () { setState(() => _readerTab = 'id'); setTabState(() {}); })),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_readerTab == 'code') ...[
                      Text('Codice mostrato sullo schermo del lettore alla prima accensione.', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      _buildInput(regCodeCtrl, 'es. blue-fox-red'),
                      const SizedBox(height: 8),
                      _buildInput(labelCtrl, 'Etichetta (es. Reception)'),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await ref.read(ownerServiceProvider).registerTerminalReader({
                                'registration_code': regCodeCtrl.text,
                                'label': labelCtrl.text,
                              });
                              _loadTerminalStatus();
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
                            }
                          },
                          child: const Text('Registra Lettore'),
                        ),
                      ),
                      if (_isSandbox) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () async {
                              try {
                                await ref.read(ownerServiceProvider).registerTerminalReader({'simulated': true});
                                _loadTerminalStatus();
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
                              }
                            },
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                            child: const Text('Usa Lettore Simulato (Sandbox)'),
                          ),
                        ),
                      ],
                    ] else ...[
                      Text('Incolla l\'ID dalla dashboard Stripe → Terminal → Readers.', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      _buildInput(readerIdCtrl, 'tmr_Fxxxxxxxxxxxxxxxxx'),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await ref.read(ownerServiceProvider).importTerminalReader({'reader_id': readerIdCtrl.text});
                              _loadTerminalStatus();
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
                            }
                          },
                          child: const Text('Collega Lettore Esistente'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ] else if (_terminalStatus == 'registered') ...[
            Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF4ADE80).withValues(alpha: 0.15)),
                  child: const Icon(Icons.contactless_rounded, size: 18, color: Color(0xFF4ADE80)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_readerLabel ?? 'Lettore', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4ADE80))),
                    Text(_readerStatus ?? 'Online', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Il terminale POS è pronto per accettare pagamenti.', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SHOWER SYSTEM
  // ═══════════════════════════════════════════════════════════
  Widget _buildShowerCard() {
    final timerCtrl = TextEditingController(text: '$_showerTimer');
    final limitCtrl = TextEditingController(text: '$_showerLimit');

    return _settingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Sistema Docce'),
          const SizedBox(height: 12),
          _fieldLabel('Durata Timer (minuti)'),
          _buildInput(timerCtrl, '8', keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          _fieldLabel('Limite Giornaliero per Membro'),
          _buildInput(limitCtrl, '3', keyboardType: TextInputType.number),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(ownerServiceProvider).updateShowerSettings({
                    'timer_minutes': int.tryParse(timerCtrl.text) ?? 8,
                    'daily_limit': int.tryParse(limitCtrl.text) ?? 3,
                  });
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Docce salvate')));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
                }
              },
              child: const Text('Salva Docce'),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TURNSTILE / KIOSK
  // ═══════════════════════════════════════════════════════════
  Widget _buildTurnstileCard() {
    final gateCtrl = TextEditingController(text: '$_gateDuration');

    return _settingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _turnstileExpanded = !_turnstileExpanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Tornello / Kiosk'),
                      Text('Configura il Raspberry Pi all\'ingresso per la scansione QR e l\'apertura del tornello.', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _turnstileExpanded ? 0.5 : 0,
                  duration: AppAnim.fast,
                  child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[600], size: 22),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          const SizedBox(height: 12),
          _fieldLabel('Chiave API Dispositivo'),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    _deviceApiKey.isNotEmpty ? _deviceApiKey : 'Non ancora generata',
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white.withValues(alpha: 0.6)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _actionBtn('Copia', onTap: () {
                if (_deviceApiKey.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: _deviceApiKey));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chiave copiata!')));
                }
              }),
            ],
          ),
          const SizedBox(height: 12),
          _fieldLabel('Durata Apertura Cancello (secondi)'),
          _buildInput(gateCtrl, '5', keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      final data = await ref.read(ownerServiceProvider).generateDeviceKey();
                      setState(() => _deviceApiKey = data['device_api_key'] as String? ?? _deviceApiKey);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chiave generata')));
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
                    }
                  },
                  child: const Text('Genera Chiave'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Save turnstile settings - gate duration
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvato')));
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Salva'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Rigenerare la chiave disconnetterà tutti i dispositivi configurati.', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          if (_deviceApiKey.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withValues(alpha: 0.06)),
            const SizedBox(height: 8),
            _fieldLabel('Comando Setup Raspberry Pi'),
            Text('L\'elettricista esegue questo via SSH sul Raspberry Pi.', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: SelectableText(
                'curl -sSL ${ApiConfig.baseUrl}/kiosk-setup | DEVICE_KEY=$_deviceApiKey bash',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF6EE7B7)),
              ),
            ),
          ],
              ],
            ),
            crossFadeState: _turnstileExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: AppAnim.fast,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  COMMISSIONS
  // ═══════════════════════════════════════════════════════════
  Widget _buildCommissionsCard() {
    final defaultRateCtrl = TextEditingController(text: _defaultCommissionRate.toStringAsFixed(0));

    return _settingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Commissioni Trainer'),
          Text('Imposta la percentuale di commissione sulle entrate per ogni trainer del tuo team.', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 12),
          // Default rate row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Expanded(child: Text('Tasso predefinito', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6)))),
                SizedBox(
                  width: 72,
                  height: 34,
                  child: TextField(
                    controller: defaultRateCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Text(' %', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    final rate = double.tryParse(defaultRateCtrl.text) ?? 0;
                    for (final t in _trainers) {
                      try {
                        await ref.read(ownerServiceProvider).setCommissionRate(t['id'] as String, rate);
                      } catch (_) {}
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Applicato a tutti')));
                      _loadAll();
                    }
                  },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), textStyle: const TextStyle(fontSize: 12)),
                  child: const Text('Applica a tutti'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Per-trainer list
          if (_trainers.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Nessun trainer', style: TextStyle(color: Colors.grey[600], fontSize: 13))))
          else
            ...List.generate(_trainers.length, (i) {
              final t = _trainers[i];
              final rateCtrl = TextEditingController(text: ((t['commission_rate'] as num?)?.toDouble() ?? 0).toStringAsFixed(0));
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text((t['username'] as String? ?? '?')[0].toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t['username'] as String? ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    SizedBox(
                      width: 60,
                      height: 30,
                      child: TextField(
                        controller: rateCtrl,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.06),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5))),
                        ),
                        onSubmitted: (val) async {
                          final newRate = double.tryParse(val);
                          if (newRate != null) {
                            try {
                              await ref.read(ownerServiceProvider).setCommissionRate(t['id'] as String, newRate);
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvato')));
                            } catch (_) {}
                          }
                        },
                      ),
                    ),
                    Text(' %', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  CLIENT IMPORT
  // ═══════════════════════════════════════════════════════════
  Widget _buildImportCard() {
    return _settingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Importa Clienti'),
          Text('Importa clienti da file CSV. Ogni cliente riceverà una password temporanea.', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Colonne richieste (almeno una):', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.45))),
                Text('name, email', style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.white.withValues(alpha: 0.3))),
                const SizedBox(height: 6),
                Text('Opzionali:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.45))),
                Text('phone, weight, body_fat, height, gender, date_of_birth, plan', style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.white.withValues(alpha: 0.3))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importazione CSV disponibile nella versione web')));
              },
              child: const Text('Carica File CSV'),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  LOGOUT
  // ═══════════════════════════════════════════════════════════
  Widget _buildLogoutCard() {
    return _settingsCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          GestureDetector(
            onTap: () => ref.read(authProvider.notifier).logout(),
            child: Row(
              children: [
                const Icon(Icons.logout_rounded, size: 14, color: Color(0xFFF87171)),
                const SizedBox(width: 6),
                const Text('Esci', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFF87171))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SHARED HELPERS
  // ═══════════════════════════════════════════════════════════
  Widget _settingsCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary));
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _iconBtn(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: const Color(0xFF252525), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.4)),
      ),
    );
  }

  Widget _actionBtn(String label, {IconData? icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
            ],
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _guideBox(List<String> steps) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppColors.primary.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text('Come fare', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary.withValues(alpha: 0.7))),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(steps.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 18, height: 18, margin: const EdgeInsets.only(right: 8, top: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                  child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary))),
                ),
                Expanded(child: Text(steps[i], style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6), height: 1.4))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4))),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String hint, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[700]),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
