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

      // Android 13+ 需要运行时申请通知权限，否则通知不会显示
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('通知初始化失败: $e');
      _initialized = false;
    }
  }

  /// 检查并立即发送库存不足通知（仅限非星标药品；星标药品走专门的短缺通知机制）
  Future<void> checkAndNotify(List<Medicine> medicines) async {
    if (!_initialized) return;

    for (final medicine in medicines) {
      // 星标药品由 scheduleStarredShortage 预排期，或转入短缺时即时通知，此处跳过以免重复
      if (medicine.needsAlert && !medicine.isStarred) {
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

  /// 发送星标药品短缺通知（由 StorageService 在药品转入「星标+短缺」时调用一次）
  Future<void> showStarredShortage(Medicine medicine) async {
    if (!_initialized) return;
    try {
      final remainingDays = medicine.remainingDays.floor();
      await _plugin.show(
        _starId(medicine.id),
        '星标药品短缺',
        '${medicine.name} 库存不足，剩余约 $remainingDays 天用量，请及时补充',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medicine_star_alert',
            '星标药品提醒',
            channelDescription: '星标药品短缺提醒',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('发送星标短缺通知失败: $e');
    }
  }

  /// 星标短缺通知使用独立的通知 ID，避免与库存耗尽通知（medicine.id.hashCode）冲突
  static int _starId(String medicineId) => 'star_shortage:$medicineId'.hashCode;

  /// 为星标药品预约定时通知：在剩余天数跌破警戒线的未来时刻触发，
  /// 即使 App 未运行也会由系统闹钟在后台弹出。
  Future<void> scheduleStarredShortage(Medicine medicine) async {
    if (!_initialized) return;
    final id = _starId(medicine.id);
    try {
      await _plugin.cancel(id);
    } catch (_) {}

    // 非星标、或当前已短缺（交给即时通知）时不排期
    if (!medicine.isStarred || medicine.needsAlert) return;

    final remainingDays = medicine.remainingDays;
    if (remainingDays == double.infinity) return;

    final daysToThreshold =
        (remainingDays - medicine.alertThreshold).floor();
    if (daysToThreshold < 0) return;

    // 以午夜为界：在下个午夜 + 距跌破警戒线的整日数时触发
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final thresholdDate = nextMidnight.add(Duration(days: daysToThreshold));
    final thresholdTz = tz.TZDateTime.from(thresholdDate, tz.local);

    try {
      await _plugin.zonedSchedule(
        id,
        '星标药品短缺',
        '${medicine.name} 库存即将低于警戒线，请及时补充',
        thresholdTz,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medicine_star_alert',
            '星标药品提醒',
            channelDescription: '星标药品短缺提醒',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('预定星标短缺通知失败: $e');
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

  /// 取消指定药品的定时通知
  Future<void> cancelForMedicine(String medicineId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(medicineId.hashCode);
      await _plugin.cancel(_starId(medicineId));
    } catch (e) {
      debugPrint('取消通知失败: $e');
    }
  }
}