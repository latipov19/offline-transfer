import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/pairing_info.dart';
import '../models/transfer_item.dart';
import '../services/nearby_service.dart';
import '../services/storage_service.dart';
import '../core/constants/app_constants.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'transfer_screen.dart';

enum SendStep { selectFiles, scanQr, connecting, ready }

class SendScreen extends StatefulWidget {
  final TransferItem? resumeTransfer;
  const SendScreen({super.key, this.resumeTransfer});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  SendStep _step = SendStep.selectFiles;
  final List<PlatformFile> _selectedFiles = [];
  PairingInfo? _pairingInfo;
  bool _isConnecting = false;
  String _statusText = 'Select files to send';
  MobileScannerController? _scannerController;
  bool _hasNavigated = false;
  StreamSubscription<String>? _connectionSub;
  Timer? _connectionTimer;

  @override
  void initState() {
    super.initState();
    final transfer = widget.resumeTransfer;
    if (transfer != null) {
      _selectedFiles.add(
        PlatformFile(
          name: transfer.fileName,
          size: transfer.fileSize,
          path: transfer.sourcePath,
        ),
      );
      _step = SendStep.scanQr;
      _statusText = 'Scan receiver\'s QR code';
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _connectionSub?.cancel();
    _connectionTimer?.cancel();
    if (!_hasNavigated) NearbyService.instance.stopAll();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (!mounted || result == null || result.files.isEmpty) return;

    setState(() {
      _selectedFiles.clear();
      _selectedFiles.addAll(result.files);
      _step = SendStep.scanQr;
      _statusText = 'Scan receiver\'s QR code';
    });

    // Initialize scanner
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  void _onQrScanned(BarcodeCapture capture) async {
    if (_isConnecting || _hasNavigated || !mounted) return;
    final barcode = capture.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue;
    if (rawValue == null) return;
    if (!rawValue.startsWith(AppConstants.qrPrefix)) return;

    try {
      final pairingInfo = PairingInfo.fromQrString(rawValue);

      if (!pairingInfo.isValid) {
        _showError('QR code expired. Please refresh on receiver.');
        return;
      }

      _isConnecting = true;
      await _scannerController?.stop();
      if (!mounted) return;

      setState(() {
        _pairingInfo = pairingInfo;
        _step = SendStep.connecting;
        _isConnecting = true;
        _statusText = 'Connecting to ${pairingInfo.deviceName}...';
      });

      await _connectToReceiver(pairingInfo);
    } catch (e) {
      await _resetScanner('Invalid QR code: $e');
    }
  }

  Future<void> _connectToReceiver(PairingInfo pairingInfo) async {
    try {
      final deviceName = await StorageService.instance.getDeviceName();
      if (!mounted) return;
      NearbyService.instance.setSession(
        sessionId: pairingInfo.sessionId,
        sessionKey: pairingInfo.keyBytes,
      );
      await _connectionSub?.cancel();
      _connectionSub = NearbyService.instance.connectionStream.listen((
        endpointId,
      ) {
        if (!mounted || !_isConnecting || _hasNavigated) return;
        _connectionTimer?.cancel();
        NearbyService.instance.stopDiscovery();
        setState(() {
          _isConnecting = false;
          _step = SendStep.ready;
          _statusText = 'Connected! Starting transfer...';
        });
        _navigateToTransfer();
      });
      bool connectionAttempted = false;
      await NearbyService.instance.startDiscovery(
        deviceName: deviceName,
        onEndpointFound: (endpointId, endpointName) async {
          if (endpointName !=
                  '${AppConstants.qrPrefix}${pairingInfo.sessionId}' ||
              connectionAttempted ||
              !mounted ||
              !_isConnecting) {
            return;
          }
          connectionAttempted = true;
          setState(() => _statusText = 'Found device! Connecting...');
          try {
            await NearbyService.instance.requestConnection(
              deviceName: deviceName,
              endpointId: endpointId,
            );
          } catch (e) {
            connectionAttempted = false;
            if (mounted) {
              setState(() => _statusText = 'Connection attempt failed: $e');
            }
          }
        },
        onEndpointLost: (_) {
          connectionAttempted = false;
        },
      );
      _connectionTimer?.cancel();
      _connectionTimer = Timer(const Duration(seconds: 30), () {
        if (mounted && _isConnecting) {
          _resetScanner('Receiver not found. Try again.');
        }
      });
    } catch (e) {
      await _resetScanner('Connection failed: $e');
    }
  }

  Future<void> _resetScanner(String message) async {
    _connectionTimer?.cancel();
    await _connectionSub?.cancel();
    await NearbyService.instance.stopAll();
    if (!mounted || _hasNavigated) return;
    setState(() {
      _isConnecting = false;
      _step = SendStep.scanQr;
      _statusText = message;
    });
    await _scannerController?.start();
  }

  void _navigateToTransfer() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TransferScreen(
          isReceiver: false,
          sessionKey: NearbyService.instance.sessionKey!,
          peerName: _pairingInfo?.deviceName ?? 'Device',
          peerDeviceId: _pairingInfo?.deviceId,
          selectedFiles: _selectedFiles,
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.color(context, AppTheme.background),
    appBar: AppBar(
      title: const Text('Send files'),
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: SafeArea(child: PageContent(child: _buildBody())),
  );

  Widget _buildBody() {
    switch (_step) {
      case SendStep.selectFiles:
        return _buildSelectFiles();
      case SendStep.scanQr:
        return _buildScanQr();
      case SendStep.connecting:
      case SendStep.ready:
        return _buildConnecting();
    }
  }

  Widget _buildSelectFiles() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      CyberBadge(
        label: '01 / SELECT FILES',
        icon: Icons.folder_outlined,
        glowColor: AppTheme.color(context, AppTheme.primary),
      ),
      const SizedBox(height: 28),
      Text(
        'What are you\nsharing today?',
        style: TextStyle(
          color: AppTheme.color(context, AppTheme.textPrimary),
          fontSize: 30,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
      const SizedBox(height: 36),
      Icon(
        Icons.folder_open_rounded,
        color: AppTheme.color(context, AppTheme.primary),
        size: 88,
      ),
      const SizedBox(height: 32),
      GlowButton(
        label: 'Choose files',
        icon: Icons.add_rounded,
        onTap: _pickFiles,
      ),
      const SizedBox(height: 28),
      const Divider(),
      const SizedBox(height: 20),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          const CyberBadge(label: 'Photos', icon: Icons.image_outlined),
          CyberBadge(
            label: 'Videos',
            icon: Icons.movie_outlined,
            glowColor: AppTheme.color(context, AppTheme.neonPink),
          ),
          CyberBadge(
            label: 'Apps',
            icon: Icons.android_rounded,
            glowColor: AppTheme.color(context, AppTheme.primary),
          ),
          CyberBadge(
            label: 'Documents',
            icon: Icons.description_outlined,
            glowColor: AppTheme.color(context, AppTheme.warning),
          ),
        ],
      ),
    ],
  );

  Widget _buildScanQr() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      if (_selectedFiles.isNotEmpty) _buildFilePreview(),
      const SizedBox(height: 24),
      Text(
        'Scan receiver',
        style: TextStyle(
          color: AppTheme.color(context, AppTheme.textPrimary),
          fontSize: 26,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 20),
      AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _onQrScanned,
              ),
              IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) => Center(
                    child: HoloTargetHUD(
                      size: constraints.maxWidth * 0.75,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        _statusText,
        style: TextStyle(
          color: AppTheme.color(context, AppTheme.textSecondary),
          fontSize: 14,
        ),
      ),
    ],
  );

  Widget _buildFilePreview() {
    final totalSize = _selectedFiles.fold<int>(0, (s, f) => s + f.size);
    return GlassContainer(
      child: Row(
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            color: AppTheme.color(context, AppTheme.accent),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFiles.length == 1
                      ? _selectedFiles[0].name
                      : '${_selectedFiles.length} files selected',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.color(context, AppTheme.textPrimary),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatBytes(totalSize),
                  style: TextStyle(
                    color: AppTheme.color(context, AppTheme.textSecondary),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Change selected files',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => setState(() {
              _selectedFiles.clear();
              _step = SendStep.selectFiles;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildConnecting() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 48),
      Icon(
        Icons.wifi_tethering_rounded,
        size: 80,
        color: AppTheme.color(context, AppTheme.accent),
      ),
      const SizedBox(height: 32),
      Text(
        _isConnecting ? 'Connecting...' : 'Connected',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppTheme.color(context, AppTheme.textPrimary),
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        _statusText,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppTheme.color(context, AppTheme.textSecondary),
          fontSize: 14,
        ),
      ),
      const SizedBox(height: 32),
      if (_isConnecting) const LinearProgressIndicator(minHeight: 4),
    ],
  );
}
