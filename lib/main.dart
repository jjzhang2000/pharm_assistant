import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/storage_service.dart';
import 'services/theme_service.dart';
import 'services/locale_service.dart';
import 'services/quick_add_service.dart';
import 'services/notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  final themeService = ThemeService();
  final localeService = LocaleService();
  final quickAddService = QuickAddService();
  await Future.wait([
    storageService.load(),
    themeService.load(),
    localeService.load(),
    quickAddService.load(),
  ]);

  try {
    await NotificationService().init().timeout(
      const Duration(seconds: 5),
      onTimeout: () => debugPrint('通知初始化超时，跳过'),
    );
  } catch (e) {
    debugPrint('通知初始化失败: $e');
  }

  // 通知初始化完成后，为所有药品预约定时通知
  storageService.scheduleAllAlerts();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: storageService),
        ChangeNotifierProvider.value(value: themeService),
        ChangeNotifierProvider.value(value: localeService),
        ChangeNotifierProvider.value(value: quickAddService),
      ],
      child: const MedicineApp(),
    ),
  );
}