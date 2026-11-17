import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_theme.dart';
import 'common_widgets.dart';

class ReceivePanel extends StatelessWidget {
  final String qrData;
  final String status;
  final bool connected;
  const ReceivePanel({
    super.key,
    required this.qrData,
    required this.status,
    this.connected = false,
  });

  @override
  Widget build(BuildContext context) => PageContent(
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        CyberBadge(
          label: 'READY TO RECEIVE',
          icon: Icons.south_west_rounded,
          glowColor: AppTheme.color(context, AppTheme.primary),
        ),
        const SizedBox(height: 28),
        Text(
          'Your secure\nconnection',
          style: TextStyle(
            color: AppTheme.color(context, AppTheme.textPrimary),
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: AspectRatio(
              aspectRatio: 1,
              child: RepaintBoundary(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: qrData.isNotEmpty
                        ? QrImageView(
                            data: qrData,
                            backgroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                            semanticsLabel: 'Secure pairing QR code',
                          )
                        : const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF284438),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Icon(
              connected
                  ? Icons.check_circle_outline_rounded
                  : Icons.wifi_tethering_rounded,
              color: AppTheme.color(context, AppTheme.primary),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                status,
                style: TextStyle(
                  color: AppTheme.color(context, AppTheme.textSecondary),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            CyberBadge(
              label: 'Encrypted',
              icon: Icons.lock_outline_rounded,
              glowColor: AppTheme.color(context, AppTheme.primary),
            ),
            const CyberBadge(label: 'Offline', icon: Icons.wifi_off_rounded),
          ],
        ),
      ],
    ),
  );
}

class TransferPanel extends StatelessWidget {
  final String fileName;
  final String bytesLabel;
  final String speed;
  final String eta;
  final String peer;
  final String status;
  final String? queueLabel;
  final double fraction;
  final bool paused;
  final VoidCallback onPause;
  final VoidCallback onCancel;

  const TransferPanel({
    super.key,
    required this.fileName,
    required this.bytesLabel,
    required this.speed,
    required this.eta,
    required this.peer,
    required this.status,
    this.queueLabel,
    required this.fraction,
    required this.paused,
    required this.onPause,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) => PageContent(
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            const ConnectionDot(isConnected: true, size: 8),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                peer,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.color(context, AppTheme.textSecondary),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        GlassContainer(
          child: Row(
            children: [
              Icon(fileIcon(fileName), color: fileColor(fileName), size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName.isEmpty ? 'Preparing file...' : fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.color(context, AppTheme.textPrimary),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bytesLabel,
                      style: TextStyle(
                        color: AppTheme.color(context, AppTheme.textSecondary),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        Text(
          paused ? 'Paused' : status,
          style: TextStyle(
            color: AppTheme.color(context, AppTheme.primary),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${((fraction.isFinite ? fraction.clamp(0, 1) : 0) * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            color: AppTheme.color(context, AppTheme.textPrimary),
            fontSize: 52,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        TransferProgressBar(progress: fraction),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final items = [
              _Metric(
                label: 'Transfer speed',
                value: speed,
                icon: Icons.speed_rounded,
              ),
              _Metric(
                label: 'Time remaining',
                value: eta,
                icon: Icons.schedule_rounded,
              ),
            ];
            if (constraints.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(14) > 19) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [items[0], const SizedBox(height: 20), items[1]],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: items[0]),
                const SizedBox(width: 20),
                Expanded(child: items[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        const Divider(),
        if (queueLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Text(
              queueLabel!,
              style: TextStyle(
                color: AppTheme.color(context, AppTheme.textSecondary),
              ),
            ),
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: GlowButton(
                label: paused ? 'Resume' : 'Pause',
                icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                isSecondary: true,
                onTap: onPause,
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              tooltip: 'Cancel transfer',
              onPressed: onCancel,
              style: IconButton.styleFrom(
                minimumSize: const Size(54, 54),
                foregroundColor: AppTheme.color(context, AppTheme.error),
                backgroundColor: AppTheme.color(
                  context,
                  AppTheme.error,
                ).withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Metric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(
            icon,
            color: AppTheme.color(context, AppTheme.textMuted),
            size: 16,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.color(context, AppTheme.textMuted),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        value,
        style: TextStyle(
          color: AppTheme.color(context, AppTheme.textPrimary),
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class TransferResultPanel extends StatelessWidget {
  final bool completed;
  final String fileName;
  final String? savedLabel;
  final double? fraction;
  final VoidCallback onHome;
  final VoidCallback? onRetry;
  final VoidCallback? onOpen;
  const TransferResultPanel({
    super.key,
    required this.completed,
    required this.fileName,
    this.savedLabel,
    this.fraction,
    required this.onHome,
    this.onRetry,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) => PageContent(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Icon(
            completed
                ? Icons.check_circle_outline_rounded
                : Icons.wifi_off_rounded,
            size: 72,
            color: completed
                ? AppTheme.color(context, AppTheme.primary)
                : AppTheme.color(context, AppTheme.warning),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          completed ? 'Transfer complete' : 'Connection interrupted',
          style: TextStyle(
            color: AppTheme.color(context, AppTheme.textPrimary),
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          completed ? fileName : 'Reconnect to continue your transfer.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.color(context, AppTheme.textSecondary),
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        if (completed)
          CyberBadge(
            label: 'SHA-256 verified',
            icon: Icons.verified_outlined,
            glowColor: AppTheme.color(context, AppTheme.primary),
          ),
        if (!completed && fraction != null) ...[
          TransferProgressBar(progress: fraction!),
          const SizedBox(height: 12),
          Text(
            savedLabel ?? '',
            style: TextStyle(
              color: AppTheme.color(context, AppTheme.textSecondary),
            ),
          ),
        ],
        const SizedBox(height: 36),
        if (onRetry != null)
          GlowButton(
            label: 'Reconnect',
            icon: Icons.refresh_rounded,
            onTap: onRetry,
          ),
        if (onOpen != null)
          GlowButton(
            label: 'Open file',
            icon: Icons.open_in_new_rounded,
            onTap: onOpen,
          ),
        const SizedBox(height: 12),
        GlowButton(
          label: 'Back to home',
          icon: Icons.home_outlined,
          isSecondary: true,
          onTap: onHome,
        ),
      ],
    ),
  );
}
