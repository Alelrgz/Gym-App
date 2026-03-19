import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Scope metadata: key, Italian label, icon, description
class ConsentScope {
  final String key;
  final String label;
  final IconData icon;
  final String description;

  const ConsentScope(this.key, this.label, this.icon, this.description);
}

const allConsentScopes = [
  ConsentScope('weight', 'Peso corporeo', Icons.monitor_weight_outlined,
      'Peso, massa grassa, massa magra, storico peso'),
  ConsentScope('body_composition', 'Composizione corporea', Icons.accessibility_new,
      'Altezza, genere, composizione corporea'),
  ConsentScope('diet', 'Dieta e alimentazione', Icons.restaurant_outlined,
      'Piano alimentare, log pasti, macro, idratazione'),
  ConsentScope('health_data', 'Dati sulla salute', Icons.favorite_outline,
      'Allergie, condizioni mediche, integratori, sonno'),
  ConsentScope('medical_cert', 'Certificato medico', Icons.description_outlined,
      'File del certificato medico sportivo'),
  ConsentScope('physique_photos', 'Foto fisico', Icons.photo_camera_outlined,
      'Foto di progresso fisico'),
  ConsentScope('training_data', 'Dati allenamento', Icons.fitness_center,
      'Log esercizi, progressi forza, storico workout'),
];

/// Default scopes to pre-select based on professional role
List<String> defaultScopesForRole(String role) {
  if (role == 'nutritionist') {
    return ['weight', 'body_composition', 'diet', 'health_data'];
  }
  return ['weight', 'training_data', 'physique_photos', 'medical_cert'];
}

/// Shows a consent dialog as a bottom sheet.
/// Returns the list of selected scopes, or null if cancelled.
Future<List<String>?> showConsentDialog(
  BuildContext context, {
  required String professionalName,
  required String professionalRole,
  List<String>? preSelectedScopes,
  List<String>? existingScopes,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ConsentSheet(
      professionalName: professionalName,
      professionalRole: professionalRole,
      preSelectedScopes: preSelectedScopes ?? defaultScopesForRole(professionalRole),
      existingScopes: existingScopes ?? [],
    ),
  );
}

class _ConsentSheet extends StatefulWidget {
  final String professionalName;
  final String professionalRole;
  final List<String> preSelectedScopes;
  final List<String> existingScopes;

  const _ConsentSheet({
    required this.professionalName,
    required this.professionalRole,
    required this.preSelectedScopes,
    required this.existingScopes,
  });

  @override
  State<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<_ConsentSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.existingScopes, ...widget.preSelectedScopes};
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'nutritionist':
        return 'Nutrizionista';
      case 'trainer':
        return 'Trainer';
      case 'both':
        return 'Trainer / Nutrizionista';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                children: [
                  Icon(Icons.shield_outlined, size: 36, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Consenso Dati',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.professionalName} (${_roleLabel(widget.professionalRole)}) '
                    'richiede accesso ai tuoi dati. '
                    'Seleziona quali dati vuoi condividere.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Scope toggles
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: allConsentScopes.length,
                itemBuilder: (_, i) {
                  final scope = allConsentScopes[i];
                  final isOn = _selected.contains(scope.key);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isOn
                              ? AppColors.primary.withOpacity(0.15)
                              : AppColors.textTertiary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          scope.icon,
                          size: 20,
                          color: isOn ? AppColors.primary : AppColors.textTertiary,
                        ),
                      ),
                      title: Text(
                        scope.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isOn ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                      subtitle: Text(
                        scope.description,
                        style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                      trailing: Switch.adaptive(
                        value: isOn,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() {
                          val ? _selected.add(scope.key) : _selected.remove(scope.key);
                        }),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.borderLight),
                        ),
                      ),
                      child: const Text('Annulla',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.pop(context, _selected.toList()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.textTertiary.withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Conferma (${_selected.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
    );
  }
}
