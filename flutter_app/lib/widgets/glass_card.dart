import 'package:flutter/material.dart';
import '../config/theme.dart';

enum GlassVariant { base, primary, accent }

class GlassCard extends StatelessWidget {
  final Widget child;
  final GlassVariant variant;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.variant = GlassVariant.base,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = switch (variant) {
      GlassVariant.base => GlassDecoration.card(borderRadius: borderRadius),
      GlassVariant.primary => GlassDecoration.primary(borderRadius: borderRadius),
      GlassVariant.accent => GlassDecoration.accent(borderRadius: borderRadius),
    };

    Widget card = Container(
      decoration: decoration,
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      card = GestureDetector(onTap: onTap, child: card);
    }

    return card;
  }
}
