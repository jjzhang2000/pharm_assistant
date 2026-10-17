import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../l10n/gen/app_localizations.dart';
import '../models/medicine.dart';
import 'locale_service.dart';

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
      debugPrint('[通知] 初始化成功');

      // Android 13+ 需要运行时申请通知权限，否则通知不会显示
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        debugPrint('[通知] 权限申请结果: $granted');
        final enabled = await androidImpl.areNotificationsEnabled();
        debugPrint('[通知] 通知实际是否开启: $enabled');
      }
    } catch (e) {
      debugPrint('通知初始化失败: $e');
      _initialized = false;
    }
  }

  /// 发送星标药品短缺通知（由 StorageService 在药品转入「星标+短缺」时调用一次）
  Future<void> showStarredShortage(Medicine medicine) async {
    if (!_initialized) {
      debugPrint('[通知] 跳过：通知服务未初始化，无法发送 ${medicine.name} 的短缺通知');
      return;
    }
    final l10n = lookupAppLocalizations(LocaleService.current);
    try {
      final remainingDays = medicine.remainingDays.floor();
      await _plugin.show(
        _starId(medicine.id),
        l10n.starShortageTitle,
        l10n.starShortageBody(medicine.name, '$remainingDays'),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'medicine_star_alert',
            l10n.starAlertChannelName,
            channelDescription: l10n.starAlertChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
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
  ///
  /// [notifyIfShort]：当前已短缺时是否补发即时通知。启动检查时传 true，
  /// 作为「后台排期被取消/未送达」的兜底，避免用户打开 App 仍然收不到。
  Future<void> scheduleStarredShortage(Medicine medicine,
      {bool notifyIfShort = false}) async {
    if (!_initialized) {
      debugPrint('[通知] 跳过：通知服务未初始化，无法排期 ${medicine.name}');
      return;
    }
    final l10n = lookupAppLocalizations(LocaleService.current);
    final id = _starId(medicine.id);
    try {
      await _plugin.cancel(id);
    } catch (_) {}

    // 非星标药品不做短缺通知
    if (!medicine.isStarred) return;

    // 当前已跌破警戒线：不再预排期，按需补发即时通知
    if (medicine.needsAlert) {
      if (notifyIfShort) await showStarredShortage(medicine);
      return;
    }

    final remainingDays = medicine.remainingDays;
    if (remainingDays == double.infinity) return;

    final daysToThreshold = remainingDays - medicine.alertThreshold;
    if (daysToThreshold < 0) return;

    // 在剩余天数跌破警戒线的真实时刻触发（按剩余天差换算为绝对时间），
    // 避免以「下个午夜 + 整日数」计算导致通知滞后近一天。
    final now = DateTime.now();
    final thresholdDate = now.add(Duration(
        milliseconds: (daysToThreshold * Duration.millisecondsPerDay).round()));
    // 显式按 UTC 绝对时间转换，避免 tz.local 未设置时把本地壁钟时间
    // 误当 UTC 而导致通知偏移一个时区（如北京时间晚 8 小时）。
    final thresholdTz = tz.TZDateTime.from(thresholdDate.toUtc(), tz.UTC);

    try {
      await _plugin.zonedSchedule(
        id,
        l10n.starShortageTitle,
        l10n.starShortageUpcoming(medicine.name),
        thresholdTz,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'medicine_star_alert',
            l10n.starAlertChannelName,
            channelDescription: l10n.starAlertChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
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
    if (!_initialized) {
      debugPrint('[通知] 跳过：通知服务未初始化，无法排期 ${medicine.name}');
      return;
    }
    final l10n = lookupAppLocalizations(LocaleService.current);

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
        l10n.medicineRunningOut,
        l10n.medicineInsufficient(medicine.name),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'medicine_alert',
            l10n.medicineAlertChannelName,
            channelDescription: l10n.medicineAlertChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
      return;
    }

    try {
      // 以午夜为界：在下个午夜 + 剩余整日数时触发通知
      final now = DateTime.now();
      final nextMidnight = DateTime(now.year, now.month, now.day + 1);
      final depletionDate = nextMidnight.add(Duration(days: remainingDays.floor()));
      final depletionTz = tz.TZDateTime.from(depletionDate.toUtc(), tz.UTC);

      await _plugin.zonedSchedule(
        id,
        l10n.medicineRunningOut,
        l10n.medicineExpectedOut(medicine.name),
        depletionTz,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'medicine_alert',
            l10n.medicineAlertChannelName,
            channelDescription: l10n.medicineAlertChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
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