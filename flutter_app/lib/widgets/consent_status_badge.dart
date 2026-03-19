import 'package:flutter/material.dart';
import '../config/theme.dart';

/// A compact badge showing consent status for a client.
/// Used in trainer/nutritionist dashboards when viewing client data.
class ConsentStatusBadge extends StatelessWidget {
  final bool hasConsent;
  final List<String> scopes;
  final VoidCallback? onRequestConsent;

  const ConsentStatusBadge({
    super.key,
    required this.hasConsent,
    this.scopes = const [],
    this.onRequestConsent,
  });

  @override
  Widget build(BuildContext context) {
    if (hasConsent && scopes.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user, size: 16, color: AppColors.success),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Consenso attivo (${scopes.length} ${scopes.length == 1 ? "dato" : "dati"})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onRequestConsent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 16, color: AppColors.warning),
            const SizedBox(width: 6),
            const Flexible(
              child: Text(
                'Nessun consenso — dati limitati',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
