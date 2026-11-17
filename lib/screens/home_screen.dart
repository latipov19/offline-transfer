import 'package:flutter/material.dart';

import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../core/permissions/permission_service.dart';
import 'receive_screen.dart';
import 'send_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _requestPermissionsAndNavigate(bool isSender) async {
    final result = await PermissionService.instance.requestNearbyPermissions(
      needsCamera: isSender,
    );

    if (!mounted) return;

    if (result == PermissionResult.permanentlyDenied) {
      _showPermissionDialog();
      return;
    }
    if (result == PermissionResult.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permissions are required for file transfer'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (isSender) {
      Navigator.push(context, _slideRoute(const SendScreen()));
    } else {
      Navigator.push(context, _slideRoute(const ReceiveScreen()));
    }
  }

  PageRoute _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Permissions Required',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Bluetooth, Wi-Fi, Location, Camera, and Storage permissions are required.\n\nPlease enable them in Settings.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.color(context, AppTheme.background),
      body: SafeArea(
        child: PageContent(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              Row(
                children: [
                  Icon(
                    Icons.swap_horiz_rounded,
                    color: AppTheme.color(context, AppTheme.primary),
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'OFFLINE TRANSFER',
                      style: TextStyle(
                        color: AppTheme.color(context, AppTheme.textSecondary),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      _slideRoute(const SettingsScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              Text(
                'Offline\nTransfer',
                style: TextStyle(
                  color: AppTheme.color(context, AppTheme.textPrimary),
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 36),
              _TransferAction(
                label: 'Send files',
                subtitle: 'Choose files to share',
                icon: Icons.north_east_rounded,
                primary: true,
                onTap: () => _requestPermissionsAndNavigate(true),
              ),
              const SizedBox(height: 12),
              _TransferAction(
                label: 'Receive files',
                subtitle: 'Ready for an incoming transfer',
                icon: Icons.south_west_rounded,
                onTap: () => _requestPermissionsAndNavigate(false),
              ),
              const SizedBox(height: 32),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.history_rounded,
                  color: AppTheme.color(context, AppTheme.accent),
                ),
                title: Text(
                  'Transfer history',
                  style: TextStyle(
                    color: AppTheme.color(context, AppTheme.textPrimary),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.push(context, _slideRoute(const HistoryScreen())),
              ),
              const Divider(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: AppTheme.color(context, AppTheme.textMuted),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AES-256-GCM',
                      style: TextStyle(
                        color: AppTheme.color(context, AppTheme.textMuted),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'About Offline Transfer',
                    icon: const Icon(Icons.info_outline_rounded, size: 20),
                    onPressed: _showAbout,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.color(context, AppTheme.surfaceElevated),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Offline Transfer',
          style: TextStyle(
            color: AppTheme.color(context, AppTheme.textPrimary),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Version 1.0.0\n\nPeer-to-peer file transfer.\nNo internet. No cloud. No server.\n\nAES-256-GCM encrypted.\nOpen source.',
          style: TextStyle(
            color: AppTheme.color(context, AppTheme.textSecondary),
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: AppTheme.color(context, AppTheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferAction extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;
  const _TransferAction({
    required this.label,
    required this.subtitle,
    required this.icon,
    this.primary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = primary
        ? AppTheme.color(context, AppTheme.background)
        : AppTheme.color(context, AppTheme.textPrimary);
    return Material(
      color: primary
          ? AppTheme.color(context, AppTheme.primary)
          : AppTheme.color(context, AppTheme.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: primary
              ? AppTheme.color(context, AppTheme.primary)
              : AppTheme.color(context, AppTheme.borderStrong),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: primary
                            ? foreground.withValues(alpha: 0.85)
                            : AppTheme.color(context, AppTheme.textSecondary),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                icon,
                color: primary
                    ? AppTheme.color(context, AppTheme.background)
                    : AppTheme.color(context, AppTheme.accent),
                size: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
