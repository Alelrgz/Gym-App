import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../config/theme.dart';
import '../providers/client_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/dashboard_sheets.dart';
import 'package:dio/dio.dart';

/// Full-screen gym discovery — shown instead of dashboard when client has no gym.
class GymDiscoveryScreen extends ConsumerStatefulWidget {
  const GymDiscoveryScreen({super.key});

  @override
  ConsumerState<GymDiscoveryScreen> createState() => _GymDiscoveryScreenState();
}

class _GymDiscoveryScreenState extends ConsumerState<GymDiscoveryScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>>? _gyms;
  bool _loading = true;
  bool _locationGranted = false;
  double? _lat;
  double? _lng;
  String? _joiningGymCode;

  @override
  void initState() {
    super.initState();
    _requestLocationAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestLocationAndLoad() async {
    // Try to get location
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          _locationGranted = true;
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 5)),
          );
          _lat = position.latitude;
          _lng = position.longitude;
        }
      }
    } catch (_) {
      // Location not available — proceed without it
    }

    await _loadGyms();
  }

  Future<void> _loadGyms({String? query}) async {
    setState(() => _loading = true);
    try {
      final service = ref.read(clientServiceProvider);
      final gyms = await service.discoverGyms(lat: _lat, lng: _lng, query: query);
      if (mounted) setState(() { _gyms = gyms; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _gyms = []; _loading = false; });
    }
  }

  Future<void> _joinGym(String gymCode) async {
    setState(() => _joiningGymCode = gymCode);
    try {
      final service = ref.read(clientServiceProvider);
      await service.joinGym(gymCode);
      ref.invalidate(clientDataProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Iscritto alla palestra!'), backgroundColor: AppColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _joiningGymCode = null);
        String msg = 'Errore';
        if (e is DioException && e.response?.data is Map) {
          msg = (e.response!.data as Map)['detail']?.toString() ?? msg;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trova la tua palestra',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _locationGranted
                          ? 'Palestre vicino a te'
                          : 'Attiva la posizione per trovare le palestre più vicine',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),

                    // Search bar
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Cerca per nome o città...',
                        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textTertiary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: AppColors.textTertiary),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadGyms();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (q) => _loadGyms(query: q.trim().isNotEmpty ? q.trim() : null),
                    ),

                    if (!_locationGranted) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _requestLocationAndLoad,
                          icon: const Icon(Icons.my_location_rounded, size: 16),
                          label: const Text('Attiva posizione'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Manual code entry
                    TextButton.icon(
                      onPressed: () => showJoinGymDialog(context, ref),
                      icon: const Icon(Icons.qr_code_rounded, size: 16),
                      label: const Text('Hai un codice? Inseriscilo qui'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Gym list
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (_gyms == null || _gyms!.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_off_rounded, size: 48, color: AppColors.textTertiary),
                        const SizedBox(height: 12),
                        const Text(
                          'Nessuna palestra trovata',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Prova a cercare per nome o inserisci un codice palestra',
                          style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _GymCard(
                        gym: _gyms![index],
                        isJoining: _joiningGymCode == _gyms![index]['gym_code'],
                        onJoin: () => _joinGym(_gyms![index]['gym_code']),
                      ),
                    ),
                    childCount: _gyms!.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── GYM CARD ──────────────────────────────────────────────────

class _GymCard extends StatelessWidget {
  final Map<String, dynamic> gym;
  final bool isJoining;
  final VoidCallback onJoin;

  const _GymCard({required this.gym, required this.isJoining, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final distance = gym['distance_km'];
    final memberCount = gym['member_count'] ?? 0;

    return GlassCard(
      child: Row(
        children: [
          // Logo
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.06),
            ),
            child: gym['logo'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      gym['logo'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center_rounded, color: AppColors.textTertiary),
                    ),
                  )
                : const Icon(Icons.fitness_center_rounded, color: AppColors.textTertiary, size: 24),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gym['name'] ?? 'Palestra',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (gym['city'] != null) ...[
                      Icon(Icons.location_on_outlined, size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          gym['city'],
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (distance != null) ...[
                      if (gym['city'] != null) const Text(' · ', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                      Text(
                        distance < 1 ? '${(distance * 1000).round()} m' : '$distance km',
                        style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
                if (memberCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '$memberCount ${memberCount == 1 ? 'membro' : 'membri'}',
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Join button
          SizedBox(
            width: 72,
            height: 34,
            child: ElevatedButton(
              onPressed: isJoining ? null : onJoin,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: isJoining
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Iscriviti'),
            ),
          ),
        ],
      ),
    );
  }
}
