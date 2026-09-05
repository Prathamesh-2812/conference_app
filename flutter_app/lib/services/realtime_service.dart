import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';

class RealtimeSyncService {
  static final RealtimeSyncService instance = RealtimeSyncService._internal();
  RealtimeSyncService._internal();

  final ValueNotifier<int> syncNotifier = ValueNotifier<int>(0);
  IO.Socket? _socket;
  Timer? _pollingTimer;
  bool _initialized = false;

  void triggerSync() {
    syncNotifier.value++;
  }

  void init() {
    if (_initialized) return;
    _initialized = true;

    _initSocket();
    _startPolling();
  }

  void _initSocket() {
    try {
      final wsUrl = apiBaseUrl.replaceAll('/api', '');
      print('RealtimeSync: Connecting to $wsUrl');

      _socket = IO.io(
        wsUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(999)
            .setReconnectionDelay(3000)
            .build(),
      );

      _socket?.onConnect((_) {
        print('RealtimeSync: Socket connected successfully');
        triggerSync();
      });

      _socket?.on('conference_updated', (_) {
        print('RealtimeSync: Conference updated event received');
        triggerSync();
      });

      _socket?.on('new_notice', (_) {
        print('RealtimeSync: New notice received');
        triggerSync();
      });

      _socket?.on('notices_updated', (_) => triggerSync());
      _socket?.on('sessions_updated', (_) => triggerSync());
      _socket?.on('speakers_updated', (_) => triggerSync());
      _socket?.on('gallery_updated', (_) => triggerSync());
      _socket?.on('meal_scanned', (_) => triggerSync());
      _socket?.on('new_scan', (_) => triggerSync());

      _socket?.onDisconnect((_) {
        print('RealtimeSync: Socket disconnected, fallback polling active');
      });

      _socket?.onError((err) {
        print('RealtimeSync Error: $err');
      });
    } catch (e) {
      print('RealtimeSync init error: $e');
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    // Background 12-second sync timer for guaranteed freshness
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      triggerSync();
    });
  }

  void dispose() {
    _pollingTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
  }
}
