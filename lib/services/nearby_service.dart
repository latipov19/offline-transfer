import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';

import '../core/constants/app_constants.dart';

/// Connection states for the state machine.
enum ConnectionState {
  idle,
  advertising,
  discovering,
  pairing,
  connecting,
  connected,
  transferring,
  paused,
  reconnecting,
  disconnected,
  failed,
}

/// Manages all Nearby Connections (Wi-Fi Direct / Bluetooth) operations.
/// Never put networking logic in UI. UI observes streams from here.
class NearbyService {
  NearbyService._();
  static final NearbyService instance = NearbyService._();

  final Nearby _nearby = Nearby();

  // ── State ──────────────────────────────────────────────────────────────
  ConnectionState _state = ConnectionState.idle;
  ConnectionState get state => _state;

  String? _connectedEndpointId;
  String? _connectedDeviceName;
  String? _sessionId;
  Uint8List? _sessionKey;

  String? get connectedEndpointId => _connectedEndpointId;
  String? get connectedDeviceName => _connectedDeviceName;

  // ── Streams ────────────────────────────────────────────────────────────
  final _stateController = StreamController<ConnectionState>.broadcast();
  final List<Uint8List> _payloadBuffer = [];
  late final StreamController<Uint8List> _payloadController =
      StreamController<Uint8List>.broadcast(
        onListen: () {
          while (_payloadBuffer.isNotEmpty) {
            final data = _payloadBuffer.removeAt(0);
            _payloadController.add(data);
          }
        },
      );
  final _connectionController = StreamController<String>.broadcast();
  final _disconnectionController = StreamController<String>.broadcast();

  Stream<ConnectionState> get stateStream => _stateController.stream;
  Stream<Uint8List> get payloadStream => _payloadController.stream;
  Stream<String> get connectionStream => _connectionController.stream;
  Stream<String> get disconnectionStream => _disconnectionController.stream;

  // ── Advertising (Receiver side) ────────────────────────────────────────

  Future<void> startAdvertising({
    required String deviceName,
    required String sessionId,
    required Function(String endpointId, String endpointName)
    onConnectionRequest,
  }) async {
    _updateState(ConnectionState.advertising);
    _log('[NEARBY] Starting advertising as: $deviceName');

    try {
      await _nearby.startAdvertising(
        '${AppConstants.qrPrefix}$sessionId',
        Strategy.P2P_POINT_TO_POINT,
        onConnectionInitiated: (endpointId, connectionInfo) {
          _log(
            '[NEARBY] Connection request from: ${connectionInfo.endpointName}',
          );
          _connectedDeviceName = connectionInfo.endpointName;
          _updateState(ConnectionState.pairing);
          onConnectionRequest(endpointId, connectionInfo.endpointName);
        },
        onConnectionResult: (endpointId, status) {
          if (status == Status.CONNECTED) {
            _log('[NEARBY] Connection established: $endpointId');
            _connectedEndpointId = endpointId;
            _updateState(ConnectionState.connected);
            // CRITICAL: Stop advertising immediately so Wi-Fi Direct channel is not disrupted
            stopAdvertising();
            _connectionController.add(endpointId);
          } else {
            _log('[NEARBY] Connection failed/rejected: $status');
            _updateState(ConnectionState.failed);
          }
        },
        onDisconnected: (endpointId) {
          _log('[NEARBY] Disconnected from: $endpointId');
          if (_connectedEndpointId == endpointId) {
            _connectedEndpointId = null;
            _updateState(ConnectionState.disconnected);
            _disconnectionController.add(endpointId);
          }
        },
        serviceId: AppConstants.serviceId,
      );
    } catch (e) {
      _log('[NEARBY] startAdvertising error: $e');
      _updateState(ConnectionState.failed);
      rethrow;
    }
  }

  Future<void> stopAdvertising() async {
    try {
      await _nearby.stopAdvertising();
    } catch (_) {}
    if (_state == ConnectionState.advertising) {
      _updateState(ConnectionState.idle);
    }
  }

  // ── Discovery (Sender side) ────────────────────────────────────────────

  Future<void> startDiscovery({
    required String deviceName,
    required Function(String endpointId, String endpointName) onEndpointFound,
    required Function(String endpointId) onEndpointLost,
  }) async {
    _updateState(ConnectionState.discovering);
    _log('[NEARBY] Starting discovery...');

    try {
      await _nearby.startDiscovery(
        deviceName,
        Strategy.P2P_POINT_TO_POINT,
        onEndpointFound: (endpointId, endpointName, serviceId) {
          _log('[NEARBY] Found endpoint: $endpointName');
          onEndpointFound(endpointId, endpointName);
        },
        onEndpointLost: (endpointId) {
          _log('[NEARBY] Lost endpoint: $endpointId');
          if (endpointId != null) onEndpointLost(endpointId);
        },
        serviceId: AppConstants.serviceId,
      );
    } catch (e) {
      _log('[NEARBY] startDiscovery error: $e');
      _updateState(ConnectionState.failed);
      rethrow;
    }
  }

  Future<void> stopDiscovery() async {
    try {
      await _nearby.stopDiscovery();
    } catch (_) {}
  }

  // ── Connection ─────────────────────────────────────────────────────────

  Future<void> requestConnection({
    required String deviceName,
    required String endpointId,
  }) async {
    _updateState(ConnectionState.connecting);
    _log('[NEARBY] Requesting connection to: $endpointId');

    try {
      await _nearby.requestConnection(
        deviceName,
        endpointId,
        onConnectionInitiated: (endpointId, connectionInfo) {
          _log(
            '[NEARBY] Connection initiated with: ${connectionInfo.endpointName}',
          );
          _connectedDeviceName = connectionInfo.endpointName;
          _updateState(ConnectionState.pairing);
          // Sender auto-accepts after receiving connection initiation.
          // The receiver side accepts via onConnectionRequest callback.
          acceptConnection(endpointId: endpointId);
        },
        onConnectionResult: (endpointId, status) {
          if (status == Status.CONNECTED) {
            _log('[NEARBY] Connected to: $endpointId');
            _connectedEndpointId = endpointId;
            _updateState(ConnectionState.connected);
            // CRITICAL: Stop discovery immediately upon connection
            stopDiscovery();
            _connectionController.add(endpointId);
          } else {
            _log('[NEARBY] Connection result failed: $status');
            _updateState(ConnectionState.failed);
          }
        },
        onDisconnected: (endpointId) {
          _log('[NEARBY] Disconnected: $endpointId');
          if (_connectedEndpointId == endpointId) {
            _connectedEndpointId = null;
            _updateState(ConnectionState.disconnected);
            _disconnectionController.add(endpointId);
          }
        },
      );
    } catch (e) {
      _log('[NEARBY] requestConnection error: $e');
      _updateState(ConnectionState.failed);
      rethrow;
    }
  }

  Future<void> acceptConnection({required String endpointId}) async {
    try {
      await _nearby.acceptConnection(
        endpointId,
        onPayLoadRecieved: (endpointId, payload) {
          if (payload.type == PayloadType.BYTES && payload.bytes != null) {
            final data = Uint8List.fromList(payload.bytes!);
            if (_payloadController.hasListener) {
              _payloadController.add(data);
            } else {
              _log(
                '[NEARBY] Buffering payload (${data.length} bytes) - no listener attached',
              );
              _payloadBuffer.add(data);
            }
          }
        },
        onPayloadTransferUpdate: (endpointId, payloadTransferUpdate) {
          // For stream-based large payloads (not used in our chunked approach)
        },
      );
    } catch (e) {
      _log('[NEARBY] acceptConnection error: $e');
    }
  }

  Future<void> rejectConnection({required String endpointId}) async {
    try {
      await _nearby.rejectConnection(endpointId);
    } catch (_) {}
  }

  // ── Payload sending ────────────────────────────────────────────────────

  Future<void> sendPayload(Uint8List data) async {
    if (_connectedEndpointId == null) {
      throw StateError('Not connected to any endpoint');
    }
    try {
      if (data.length > 32 * 1024) {
        throw StateError('Nearby payload exceeds 32 KB');
      }
      await _nearby.sendBytesPayload(_connectedEndpointId!, data);
    } catch (e) {
      _log('[NEARBY] sendPayload error: $e');
      rethrow;
    }
  }

  // ── Disconnect ─────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    final endpointId = _connectedEndpointId;
    if (endpointId != null) {
      try {
        await _nearby.disconnectFromEndpoint(endpointId);
      } catch (_) {}
      _connectedEndpointId = null;
    }
    _payloadBuffer.clear();
    _updateState(ConnectionState.idle);
  }

  Future<void> stopAll() async {
    try {
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
      await _nearby.stopAllEndpoints();
    } catch (_) {}
    _connectedEndpointId = null;
    _payloadBuffer.clear();
    _updateState(ConnectionState.idle);
  }

  // ── Session ────────────────────────────────────────────────────────────

  void setSession({required String sessionId, required Uint8List sessionKey}) {
    _sessionId = sessionId;
    _sessionKey = sessionKey;
    _payloadBuffer.clear();
  }

  void clearPayloadBuffer() {
    _payloadBuffer.clear();
  }

  String? get sessionId => _sessionId;
  Uint8List? get sessionKey => _sessionKey;

  // ── Helpers ────────────────────────────────────────────────────────────

  void _updateState(ConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void _log(String message) {
    developer.log(message, name: 'NearbyService');
  }

  void dispose() {
    _stateController.close();
    _payloadController.close();
    _connectionController.close();
    _disconnectionController.close();
  }
}
