import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Keeps existing call sites while restoring Flutter's standard Material icons.
class AppIcon extends StatelessWidget {
  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  const AppIcon(this.icon, {super.key, this.size, this.color, this.semanticLabel});
  @override
  Widget build(BuildContext context) => Icon(icon, size: size, color: color, semanticLabel: semanticLabel);
}

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});
  @override Widget build(BuildContext context) => IconButton(tooltip: '戻る',
    onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded));
}
