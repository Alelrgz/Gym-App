import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'glass_card.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final VoidCallback? onTap;
  final bool highlighted;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: highlighted
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (valueColor ?? AppColors.primary).withValues(alpha: 0.6),
                  width: 1.5,
                ),
              )
            : null,
        child: GlassCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.textSecondary, size: 20),
                const SizedBox(height: 6),
              ],
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
