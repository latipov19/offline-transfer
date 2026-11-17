import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Kept source-compatible with existing screens, without backdrop blur.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? shadows;
  final Gradient? gradient;
  final double blur;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.shadows,
    this.gradient,
    this.blur = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: backgroundColor ?? AppTheme.color(context, AppTheme.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: borderColor ?? AppTheme.color(context, AppTheme.border),
            width: borderWidth,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Static background: idle screens do not schedule animation frames.
class CosmicBackground extends StatelessWidget {
  final Widget child;
  final bool showGrid;
  const CosmicBackground({
    super.key,
    required this.child,
    this.showGrid = true,
  });

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppTheme.color(context, AppTheme.background),
    child: child,
  );
}

class RadarPulseEffect extends StatelessWidget {
  final Widget centerChild;
  final double radius;
  final Color ringColor;
  const RadarPulseEffect({
    super.key,
    required this.centerChild,
    this.radius = 140,
    this.ringColor = AppTheme.accent,
  });

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: centerChild);
}

class HoloTargetHUD extends StatelessWidget {
  final Widget child;
  final double size;
  final bool isScanning;
  final Color cornerColor;
  const HoloTargetHUD({
    super.key,
    required this.child,
    required this.size,
    this.isScanning = true,
    this.cornerColor = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      foregroundPainter: _ScannerFrame(cornerColor),
      child: child,
    ),
  );
}

class _ScannerFrame extends CustomPainter {
  final Color color;
  const _ScannerFrame(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const inset = 2.0;
    const arm = 24.0;
    for (final corner in [
      const Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      Offset(size.width - inset, size.height - inset),
    ]) {
      final dx = corner.dx < size.width / 2 ? arm : -arm;
      final dy = corner.dy < size.height / 2 ? arm : -arm;
      canvas.drawPath(
        Path()
          ..moveTo(corner.dx + dx, corner.dy)
          ..lineTo(corner.dx, corner.dy)
          ..lineTo(corner.dx, corner.dy + dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScannerFrame oldDelegate) => color != oldDelegate.color;
}

class CyberBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color glowColor;
  const CyberBadge({
    super.key,
    required this.label,
    this.icon,
    this.glowColor = AppTheme.accent,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppTheme.color(context, glowColor).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: AppTheme.color(context, glowColor)),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.color(context, glowColor),
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    ),
  );
}

class GlowButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? glowColor;
  final bool isLoading;
  final bool isSecondary;
  const GlowButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.gradient,
    this.glowColor,
    this.isLoading = false,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !isLoading ? onTap : null;
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: 21),
        if (isLoading || icon != null) const SizedBox(width: 10),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 54)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
    return isSecondary
        ? OutlinedButton(
            onPressed: enabled,
            style: style.copyWith(
              foregroundColor: WidgetStatePropertyAll(
                AppTheme.color(context, AppTheme.textPrimary),
              ),
              side: WidgetStatePropertyAll(
                BorderSide(
                  color: AppTheme.color(context, AppTheme.borderStrong),
                ),
              ),
            ),
            child: content,
          )
        : FilledButton(
            onPressed: enabled,
            style: style.copyWith(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? AppTheme.color(context, AppTheme.surfaceElevated)
                    : glowColor ?? AppTheme.color(context, AppTheme.primary),
              ),
              foregroundColor: WidgetStatePropertyAll(
                AppTheme.color(context, AppTheme.background),
              ),
            ),
            child: content,
          );
  }
}

class TransferProgressBar extends StatelessWidget {
  final double progress;
  final Color? color;
  const TransferProgressBar({super.key, required this.progress, this.color});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: progress.isFinite ? progress.clamp(0, 1) : 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      builder: (context, value, _) => LinearProgressIndicator(
        value: value,
        color: color ?? AppTheme.color(context, AppTheme.primary),
        backgroundColor: AppTheme.color(context, AppTheme.surfaceElevated),
        minHeight: 6,
        borderRadius: BorderRadius.circular(3),
        semanticsLabel: 'Transfer progress',
      ),
    ),
  );
}

class ConnectionDot extends StatelessWidget {
  final bool isConnected;
  final double size;
  const ConnectionDot({super.key, required this.isConnected, this.size = 10});

  @override
  Widget build(BuildContext context) => Semantics(
    label: isConnected ? 'Connected' : 'Disconnected',
    child: SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isConnected
              ? AppTheme.color(context, AppTheme.success)
              : AppTheme.color(context, AppTheme.error),
        ),
      ),
    ),
  );
}

/// Constrains content on tablets without fixing its height on small phones.
class PageContent extends StatelessWidget {
  final Widget child;
  const PageContent({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: child,
    ),
  );
}

/// File size formatter.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// Get file type icon.
IconData fileIcon(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'webp':
    case 'heic':
      return Icons.image_rounded;
    case 'mp4':
    case 'mkv':
    case 'avi':
    case 'mov':
    case 'webm':
      return Icons.movie_rounded;
    case 'mp3':
    case 'aac':
    case 'wav':
    case 'flac':
    case 'ogg':
      return Icons.music_note_rounded;
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'doc':
    case 'docx':
      return Icons.description_rounded;
    case 'xls':
    case 'xlsx':
      return Icons.table_chart_rounded;
    case 'ppt':
    case 'pptx':
      return Icons.slideshow_rounded;
    case 'zip':
    case 'rar':
    case '7z':
    case 'tar':
    case 'gz':
      return Icons.folder_zip_rounded;
    case 'apk':
      return Icons.android_rounded;
    case 'txt':
    case 'md':
      return Icons.text_snippet_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

/// Get file type color.
Color fileColor(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'webp':
    case 'heic':
      return const Color(0xFF4CAF50);
    case 'mp4':
    case 'mkv':
    case 'avi':
    case 'mov':
      return const Color(0xFFE91E63);
    case 'mp3':
    case 'aac':
    case 'wav':
    case 'flac':
      return const Color(0xFF9C27B0);
    case 'pdf':
      return const Color(0xFFFF5722);
    case 'zip':
    case 'rar':
    case '7z':
      return const Color(0xFFFF9800);
    case 'apk':
      return const Color(0xFF00BCD4);
    default:
      return AppTheme.primary;
  }
}
