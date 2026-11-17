import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/app_constants.dart';
import '../models/transfer_item.dart';
import '../core/permissions/permission_service.dart';
import 'send_screen.dart';
import '../repositories/transfer_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.color(context, AppTheme.background),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppTheme.color(context, AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Transfer history'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            color: AppTheme.color(context, AppTheme.textSecondary),
            onPressed: () async {
              await TransferRepository.instance.clearCompleted();
            },
            tooltip: 'Clear completed',
          ),
        ],
      ),
      body: SafeArea(
        child: PageContent(
          child: ValueListenableBuilder(
            valueListenable: Hive.box<TransferItem>(AppConstants.transferBox)
                .listenable(),
            builder: (context, box, _) {
              final transfers = box.values.toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              if (transfers.isEmpty) {
                return _buildEmpty(context);
              }

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: transfers.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _TransferCard(item: transfers[index]),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.color(context, AppTheme.surfaceElevated),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_rounded,
              color: AppTheme.color(context, AppTheme.textMuted),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No transfers yet',
            style: TextStyle(
              color: AppTheme.color(context, AppTheme.textSecondary),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No files sent or received',
            style: TextStyle(
              color: AppTheme.color(context, AppTheme.textMuted),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  final TransferItem item;

  const _TransferCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                fileIcon(item.fileName),
                color: fileColor(item.fileName),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.color(context, AppTheme.textPrimary),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${formatBytes(item.fileSize)} / ${item.isSender ? 'Sent' : 'Received'}',
                      style: TextStyle(
                        color: AppTheme.color(context, AppTheme.textSecondary),
                        fontSize: 12,
                      ),
                    ),
                    if (item.peerDeviceName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${item.isSender ? 'To' : 'From'}: ${item.peerDeviceName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.color(context, AppTheme.textMuted),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StatusBadge(status: item.status),
                ),
              ),
              if (item.status == TransferStatus.paused)
                Text(
                  '${(item.progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: AppTheme.color(context, AppTheme.textMuted),
                    fontSize: 11,
                  ),
                ),
              if (item.isSender && !item.isComplete && item.sourcePath != null)
                IconButton(
                  tooltip: 'Resume transfer',
                  icon: Icon(
                    Icons.play_arrow_rounded,
                    color: AppTheme.color(context, AppTheme.primary),
                  ),
                  onPressed: () async {
                    final permission = await PermissionService.instance
                        .requestNearbyPermissions();
                    if (!context.mounted) return;
                    if (permission != PermissionResult.granted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Transfer permissions are required',
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SendScreen(resumeTransfer: item),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TransferStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case TransferStatus.completed:
        color = AppTheme.color(context, AppTheme.success);
        icon = Icons.check_circle_rounded;
        label = 'Done';
        break;
      case TransferStatus.failed:
        color = AppTheme.color(context, AppTheme.error);
        icon = Icons.error_rounded;
        label = 'Failed';
        break;
      case TransferStatus.paused:
        color = AppTheme.color(context, AppTheme.warning);
        icon = Icons.pause_circle_rounded;
        label = 'Paused';
        break;
      case TransferStatus.cancelled:
        color = AppTheme.color(context, AppTheme.textMuted);
        icon = Icons.cancel_rounded;
        label = 'Cancelled';
        break;
      default:
        color = AppTheme.color(context, AppTheme.primary);
        icon = Icons.sync_rounded;
        label = status.statusLabel;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
