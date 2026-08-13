import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

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
      tz_data.initializeTimeZones();
      final localTz = tz.local;

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

  /// 检查并立即发送库存不足通知
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

  /// 为指定药品预定定时通知（在库存耗尽时触发）
  Future<void> scheduleStockAlert(Medicine medicine) async {
    if (!_initialized) return;

    final id = medicine.id.hashCode;

    // 先取消该药品已有的定时通知
    try {
      await _plugin.cancel(id);
    } catch (_) {}

    final remainingDays = medicine.remainingDays;
    if (remainingDays == double.infinity) return;

    // 库存已耗尽或当天将耗尽，立即通知
    if (remainingDays <= 0) {
      await _plugin.show(
        id,
        '药品即将用完',
        '${medicine.name} 库存已不足，请及时补充',
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
      return;
    }

    try {
      // 以午夜为界：在下个午夜 + 剩余整日数时触发通知
      final now = DateTime.now();
      final nextMidnight = DateTime(now.year, now.month, now.day + 1);
      final depletionDate = nextMidnight.add(Duration(days: remainingDays.floor()));
      final depletionTz = tz.TZDateTime.from(depletionDate, tz.local);

      await _plugin.zonedSchedule(
        id,
        '药品即将用完',
        '${medicine.name} 预计当天用完，请及时补充',
        depletionTz,
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
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('已为 ${medicine.name} 预定定时通知: ${depletionDate.toIso8601String()}');
    } catch (e) {
      debugPrint('预定定时通知失败: $e');
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

  /// 取消指定药品的定时通知
  Future<void> cancelForMedicine(String medicineId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(medicineId.hashCode);
    } catch (e) {
      debugPrint('取消通知失败: $e');
    }
  }
}