import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/medicine.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;

    try {
      const androidSettings =
          AndroidInitializationSettings('@drawable/ic_notification');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(settings);
      _initialized = true;
    } catch (e) {
      debugPrint('通知初始化失败: $e');
      _initialized = false;
    }
  }

  /// 检查并发送库存不足通知
  Future<void> checkAndNotify(List<Medicine> medicines) async {
    if (!_initialized) return;

    for (final medicine in medicines) {
      if (medicine.needsAlert) {
        try {
          final remainingDays = medicine.remainingDays.floor();
          await _plugin.show(
            medicine.id.hashCode,
            '药品即将用完',
            '${medicine.name} 仅剩约 $remainingDays 天用量，请及时补充',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'medicine_alert',
                '药品提醒',
                channelDescription: '药品库存不足提醒',
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
          );
        } catch (e) {
          debugPrint('发送通知失败: $e');
        }
      }
    }
  }

  /// 取消所有通知
  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('取消通知失败: $e');
    }
  }
}