import 'package:flutter/material.dart' as material;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

enum AppToastType { success, warning, error, info }

void showAppToast(
  material.BuildContext context,
  String message, {
  AppToastType type = AppToastType.info,
  Duration showDuration = const Duration(seconds: 3),
}) {
  final (icon, color, backgroundColor) = switch (type) {
    AppToastType.success => (
      material.Icons.check_circle_rounded,
      const material.Color(0xFF15803D),
      const material.Color(0xFFF0FDF4),
    ),
    AppToastType.warning => (
      material.Icons.warning_amber_rounded,
      const material.Color(0xFFD97706),
      const material.Color(0xFFFFF7ED),
    ),
    AppToastType.error => (
      material.Icons.error_outline_rounded,
      const material.Color(0xFFDC2626),
      const material.Color(0xFFFEF2F2),
    ),
    AppToastType.info => (
      material.Icons.info_outline_rounded,
      const material.Color(0xFF1565C0),
      const material.Color(0xFFEFF6FF),
    ),
  };

  shadcn.showToast(
    context: context,
    location: shadcn.ToastLocation.topRight,
    dismissible: true,
    curve: material.Curves.easeOutCubic,
    entryDuration: const Duration(milliseconds: 500),
    showDuration: showDuration,
    builder: (context, overlay) => shadcn.SurfaceCard(
      padding: const material.EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: material.ConstrainedBox(
        constraints: const material.BoxConstraints(maxWidth: 380),
        child: material.Row(
          mainAxisSize: material.MainAxisSize.min,
          children: [
            material.Container(
              width: 32,
              height: 32,
              decoration: material.BoxDecoration(
                color: backgroundColor,
                shape: material.BoxShape.circle,
              ),
              child: material.Icon(icon, size: 18, color: color),
            ),
            const material.SizedBox(width: 10),
            material.Flexible(
              child: material.Text(
                message,
                maxLines: 3,
                overflow: material.TextOverflow.ellipsis,
                style: const material.TextStyle(
                  color: material.Color(0xFF1E293B),
                  fontSize: 13,
                  fontWeight: material.FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
