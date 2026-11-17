import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../core/constants/app_constants.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  bool _isEditing = false;
  String _deviceName = '';
  String _themeMode = 'dark'; // 'dark' | 'light' | 'system'

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final name = await StorageService.instance.getDeviceName();
    final theme =
        StorageService.instance.getSetting(AppConstants.keyThemeMode) ?? 'dark';
    setState(() {
      _deviceName = name;
      _nameController.text = name;
      _themeMode = theme;
    });
  }

  Future<void> _setThemeMode(String mode) async {
    await StorageService.instance.putSetting(AppConstants.keyThemeMode, mode);
    setState(() => _themeMode = mode);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restart the app to apply the new theme'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _saveDeviceName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await StorageService.instance.setDeviceName(name);
    setState(() {
      _deviceName = name;
      _isEditing = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Device name updated')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.color(context, AppTheme.background),
    appBar: AppBar(
      title: const Text('Settings'),
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: SafeArea(
      child: PageContent(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const _SectionHeader('Device'),
            const SizedBox(height: 16),
            if (_isEditing) ...[
              TextField(
                controller: _nameController,
                autofocus: true,
                style: TextStyle(
                  color: AppTheme.color(context, AppTheme.textPrimary),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _saveDeviceName(),
                decoration: InputDecoration(
                  labelText: 'Device name',
                  labelStyle: TextStyle(
                    color: AppTheme.color(context, AppTheme.textSecondary),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Cancel editing',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _isEditing = false),
                  ),
                  IconButton(
                    tooltip: 'Save device name',
                    icon: Icon(
                      Icons.check_rounded,
                      color: AppTheme.color(context, AppTheme.primary),
                    ),
                    onPressed: _saveDeviceName,
                  ),
                ],
              ),
            ] else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.phone_android_rounded,
                  color: AppTheme.color(context, AppTheme.accent),
                ),
                title: Text(
                  _deviceName,
                  style: TextStyle(
                    color: AppTheme.color(context, AppTheme.textPrimary),
                  ),
                ),
                subtitle: Text(
                  'Device name',
                  style: TextStyle(
                    color: AppTheme.color(context, AppTheme.textSecondary),
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Edit device name',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => setState(() => _isEditing = true),
                ),
              ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 28),
            const _SectionHeader('Appearance'),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) => SegmentedButton<String>(
                showSelectedIcon: false,
                direction:
                    constraints.maxWidth < 300 ||
                        MediaQuery.textScalerOf(context).scale(14) > 19
                    ? Axis.vertical
                    : Axis.horizontal,
                segments: const [
                  ButtonSegment(
                    value: 'dark',
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                  ButtonSegment(
                    value: 'light',
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: 'system',
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto_outlined),
                  ),
                ],
                selected: {_themeMode},
                onSelectionChanged: (value) => _setThemeMode(value.first),
              ),
            ),
            const SizedBox(height: 28),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.security_outlined,
                color: AppTheme.color(context, AppTheme.primary),
              ),
              title: Text(
                'Permissions',
                style: TextStyle(
                  color: AppTheme.color(context, AppTheme.textPrimary),
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: openAppSettings,
            ),
            const Divider(),
            const SizedBox(height: 28),
            const _SectionHeader('About'),
            const SizedBox(height: 16),
            const _AboutRow('App', 'Offline Transfer'),
            const _AboutRow('Version', '1.0.0'),
            const _AboutRow('Protocol', 'v${AppConstants.protocolVersion}'),
            const _AboutRow('Encryption', 'AES-256-GCM'),
            const _AboutRow('Transport', 'Nearby Connections'),
            const _AboutRow('Internet', 'Not required'),
          ],
        ),
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: TextStyle(
      color: AppTheme.color(context, AppTheme.textSecondary),
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;
  const _AboutRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.color(context, AppTheme.textSecondary),
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppTheme.color(context, AppTheme.textPrimary),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}
