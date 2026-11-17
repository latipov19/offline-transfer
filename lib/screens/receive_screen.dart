import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/transfer_panels.dart';

import 'package:uuid/uuid.dart';

import '../models/pairing_info.dart';
import '../services/nearby_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'transfer_screen.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  String _qrData = '';
  String _statusText = 'Generating QR code...';
  bool _isConnected = false;

  StreamSubscription? _connectionSub;
  StreamSubscription? _payloadSub;

  Timer? _qrRefreshTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _initReceiver();
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _payloadSub?.cancel();
    _qrRefreshTimer?.cancel();
    if (!_hasNavigated) {
      NearbyService.instance.stopAll();
    }
    super.dispose();
  }

  Future<void> _initReceiver() async {
    try {
      final deviceId = await StorageService.instance.getDeviceId();
      final deviceName = await StorageService.instance.getDeviceName();
      final sessionId = const Uuid().v4();

      final pairingInfo = PairingInfo.generate(
        sessionId: sessionId,
        deviceId: deviceId,
        deviceName: deviceName,
      );

      NearbyService.instance.setSession(
        sessionId: sessionId,
        sessionKey: pairingInfo.keyBytes,
      );

      if (mounted) {
        setState(() {
          _qrData = pairingInfo.toQrString();
          _statusText = 'Show this QR to sender device';
        });
      }

      if (!mounted) return;
      _connectionSub?.cancel();
      _connectionSub = NearbyService.instance.connectionStream.listen(
        _onConnected,
      );
      await NearbyService.instance.startAdvertising(
        deviceName: deviceName,
        sessionId: sessionId,
        onConnectionRequest: _onConnectionRequest,
      );

      if (mounted) {
        setState(() => _statusText = 'Advertising... Ready to pair');
      }

      _qrRefreshTimer?.cancel();
      _qrRefreshTimer = Timer(const Duration(minutes: 4), () {
        if (mounted && !_isConnected) _refreshQr();
      });
    } catch (e) {
      if (mounted) setState(() => _statusText = 'Error: $e');
    }
  }

  Future<void> _refreshQr() async {
    if (!mounted || _isConnected) return;
    setState(() {
      _qrData = '';
      _statusText = 'Refreshing QR...';
    });
    await NearbyService.instance.stopAll();
    _connectionSub?.cancel();
    _payloadSub?.cancel();
    _qrRefreshTimer?.cancel();
    await _initReceiver();
  }

  void _onConnectionRequest(String endpointId, String endpointName) {
    NearbyService.instance.acceptConnection(endpointId: endpointId);
    if (mounted) {
      setState(() => _statusText = 'Pairing with $endpointName...');
    }
  }

  void _onConnected(String endpointId) {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    _isConnected = true;
    _connectionSub?.cancel();
    _payloadSub?.cancel();
    _qrRefreshTimer?.cancel();

    // CRITICAL: Stop advertising immediately so Wi-Fi Direct channel is dedicated to transfer
    NearbyService.instance.stopAdvertising();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TransferScreen(
          isReceiver: true,
          sessionKey: NearbyService.instance.sessionKey!,
          peerName:
              NearbyService.instance.connectedDeviceName ?? 'Sender Device',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.color(context, AppTheme.background),
    appBar: AppBar(
      title: const Text('Receive files'),
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (!_isConnected)
          IconButton(
            tooltip: 'Refresh QR code',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshQr,
          ),
      ],
    ),
    body: SafeArea(
      child: ReceivePanel(
        qrData: _qrData,
        status: _statusText,
        connected: _isConnected,
      ),
    ),
  );
}
