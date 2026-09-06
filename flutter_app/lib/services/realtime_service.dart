import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';

class RealtimeSyncService {
  static final RealtimeSyncService instance = RealtimeSyncService._internal();
  RealtimeSyncService._internal();

  final ValueNotifier<int> syncNotifier = ValueNotifier<int>(0);
  final ValueNotifier<Map<String, dynamic>?> lastNotificationNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<int> unreadNotifCountNotifier = ValueNotifier<int>(0);
  
  IO.Socket? _socket;
  Timer? _pollingTimer;
  bool _initialized = false;

  void triggerSync() {
    syncNotifier.value++;
  }

  void updateUnreadCount(int count) {
    unreadNotifCountNotifier.value = count;
  }

  Future<void> joinUser(dynamic userId, [dynamic conferenceId = 1]) async {
    if (_socket != null && _socket!.connected) {
      if (userId != null) {
        _socket?.emit('join_user', userId);
      }
      if (conferenceId != null) {
        _socket?.emit('join_conference', conferenceId);
      }
    }
  }

  void init() {
    if (_initialized) return;
    _initialized = true;

    _initSocket();
    _startPolling();
  }

  Future<void> _initSocket() async {
    try {
      final wsUrl = apiBaseUrl.replaceAll('/api', '');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      _socket = IO.io(
        wsUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .setAuth({'token': token})
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(999)
            .setReconnectionDelay(2000)
            .build(),
      );

      _socket?.onConnect((_) async {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getInt('user_id');
        if (userId != null) {
          _socket?.emit('join_user', userId);
        }
        _socket?.emit('join_conference', 1);
        triggerSync();
      });

      _socket?.on('conference_updated', (_) => triggerSync());
      _socket?.on('sessions_updated', (_) => triggerSync());
      _socket?.on('speakers_updated', (_) => triggerSync());
      _socket?.on('notices_updated', (_) => triggerSync());
      _socket?.on('new_notice', (data) {
        if (data is Map) {
          lastNotificationNotifier.value = Map<String, dynamic>.from(data);
          unreadNotifCountNotifier.value++;
        }
        triggerSync();
      });
      _socket?.on('notification_received', (data) {
        if (data is Map) {
          lastNotificationNotifier.value = Map<String, dynamic>.from(data);
          unreadNotifCountNotifier.value++;
        }
        triggerSync();
      });
      _socket?.on('profile_updated', (_) => triggerSync());
      _socket?.on('attendance_updated', (_) => triggerSync());
      _socket?.on('new_scan', (_) => triggerSync());
      _socket?.on('gallery_updated', (_) => triggerSync());
      _socket?.on('meal_scanned', (_) => triggerSync());

      _socket?.onDisconnect((_) {});
      _socket?.onError((_) {});
    } catch (_) {}
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      triggerSync();
    });
  }

  void dispose() {
    _pollingTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _initialized = false;
  }
}

