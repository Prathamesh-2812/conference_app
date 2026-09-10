import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';
import 'api_service.dart';

class RealtimeSyncService {
  static final RealtimeSyncService instance = RealtimeSyncService._internal();
  RealtimeSyncService._internal();

  final ValueNotifier<int> syncNotifier = ValueNotifier<int>(0);
  final ValueNotifier<Map<String, dynamic>?> lastNotificationNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<int> unreadNotifCountNotifier = ValueNotifier<int>(0);
  
  IO.Socket? _socket;
  Timer? _pollingTimer;
  bool _initialized = false;
  final Set<String> _knownNoticeIds = <String>{};
  bool _firstFetchDone = false;

  void triggerSync() {
    syncNotifier.value++;
    calculateUnreadCount(notifyOnNew: true);
  }

  void updateUnreadCount(int count) {
    unreadNotifCountNotifier.value = count;
  }

  Future<void> calculateUnreadCount({bool notifyOnNew = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seenIds = (prefs.getStringList('seen_notice_ids') ?? []).toSet();
      final res = await ApiService.get('/notices');
      if (res is List) {
        int unread = 0;
        Map<String, dynamic>? newestUnseen;

        for (final item in res) {
          final idStr = item['id']?.toString() ?? '';
          if (idStr.isNotEmpty) {
            final isSeen = seenIds.contains(idStr);
            if (!isSeen) {
              unread++;
              // If this is a new notice arrived while app was open
              if (notifyOnNew && _firstFetchDone && !_knownNoticeIds.contains(idStr)) {
                newestUnseen ??= Map<String, dynamic>.from(item);
              }
            }
            _knownNoticeIds.add(idStr);
          }
        }

        _firstFetchDone = true;
        unreadNotifCountNotifier.value = unread;

        if (newestUnseen != null) {
          lastNotificationNotifier.value = newestUnseen;
        }
      }
    } catch (_) {}
  }

  Future<void> markNoticesAsSeen(List<dynamic> notices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seenIds = (prefs.getStringList('seen_notice_ids') ?? []).toSet();
      for (final item in notices) {
        final idStr = item['id']?.toString() ?? '';
        if (idStr.isNotEmpty) {
          seenIds.add(idStr);
          _knownNoticeIds.add(idStr);
        }
      }
      await prefs.setStringList('seen_notice_ids', seenIds.toList());
      unreadNotifCountNotifier.value = 0;
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      final res = await ApiService.get('/notices');
      if (res is List) {
        await markNoticesAsSeen(res);
      } else {
        unreadNotifCountNotifier.value = 0;
      }
    } catch (_) {
      unreadNotifCountNotifier.value = 0;
    }
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
    calculateUnreadCount(notifyOnNew: false);
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
        _socket?.emit('join_conference', ConferenceService.activeConferenceId);
        triggerSync();
      });

      _socket?.on('conference_updated', (_) => triggerSync());
      
      _socket?.on('sessions_updated', (data) {
        if (data is Map && data['title'] != null) {
          lastNotificationNotifier.value = {
            'title': '📅 Schedule Updated',
            'message': data['title'],
            'type': 'SCHEDULE',
            'created_at': DateTime.now().toIso8601String(),
          };
          unreadNotifCountNotifier.value++;
        }
        triggerSync();
      });

      _socket?.on('speakers_updated', (_) => triggerSync());
      _socket?.on('notices_updated', (_) => triggerSync());

      _socket?.on('new_notice', (data) {
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final idStr = map['id']?.toString() ?? '';
          if (idStr.isNotEmpty) {
            _knownNoticeIds.add(idStr);
          }
          lastNotificationNotifier.value = map;
          unreadNotifCountNotifier.value++;
        }
        triggerSync();
      });

      _socket?.on('notification_received', (data) {
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final idStr = map['id']?.toString() ?? '';
          if (idStr.isNotEmpty) {
            _knownNoticeIds.add(idStr);
          }
          lastNotificationNotifier.value = map;
          unreadNotifCountNotifier.value++;
        }
        triggerSync();
      });

      _socket?.on('new_notification', (data) {
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final idStr = map['id']?.toString() ?? '';
          if (idStr.isNotEmpty) {
            _knownNoticeIds.add(idStr);
          }
          lastNotificationNotifier.value = map;
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
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      calculateUnreadCount(notifyOnNew: true);
    });
  }

  void dispose() {
    _pollingTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _initialized = false;
  }
}
