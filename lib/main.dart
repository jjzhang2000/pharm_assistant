import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.load();

  try {
    await NotificationService().init().timeout(
      const Duration(seconds: 5),
      onTimeout: () => debugPrint('通知初始化超时，跳过'),
    );
  } catch (e) {
    debugPrint('通知初始化失败: $e');
  }

  runApp(
    ChangeNotifierProvider.value(
      value: storageService,
      child: const MedicineApp(),
    ),
  );
}