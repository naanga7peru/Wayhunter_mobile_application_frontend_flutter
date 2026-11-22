import 'package:flutter/material.dart';
import 'package:wayhunter_mobile/core/theme/wayhunter_tokens.dart';

class WayhunterSurfaceCard extends StatelessWidget {
  const WayhunterSurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(WayhunterLayout.large),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
        color: WayhunterColors.glass,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WayhunterLayout.cardRadius),
          side: const BorderSide(color: WayhunterColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      );
}

enum WayhunterStatusTone { neutral, info, success, warning, danger }

class WayhunterStatusIndicator extends StatelessWidget {
  const WayhunterStatusIndicator({
    super.key,
    required this.label,
    this.tone = WayhunterStatusTone.neutral,
  });

  final String label;
  final WayhunterStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (ink, fill, icon) = switch (tone) {
      WayhunterStatusTone.neutral => (
          WayhunterColors.mutedInk,
          const Color(0xFFE3ECEA),
          Icons.circle_outlined
        ),
      WayhunterStatusTone.info => (
          const Color(0xFF184E70),
          const Color(0xFFDCEEF8),
          Icons.info_outline
        ),
      WayhunterStatusTone.success => (
          const Color(0xFF146145),
          const Color(0xFFDDF2E7),
          Icons.check_circle_outline
        ),
      WayhunterStatusTone.warning => (
          const Color(0xFF754A00),
          const Color(0xFFFFEBCB),
          Icons.warning_amber
        ),
      WayhunterStatusTone.danger => (
          WayhunterColors.dangerInk,
          const Color(0xFFFBE5E7),
          Icons.error_outline
        ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(WayhunterLayout.controlRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WayhunterLayout.medium,
          vertical: WayhunterLayout.small,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 18, color: ink)),
            const SizedBox(width: WayhunterLayout.small),
            Flexible(child: Text(label, style: TextStyle(color: ink))),
          ],
        ),
      ),
    );
  }
}
