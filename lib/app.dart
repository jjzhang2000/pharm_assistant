import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/add_edit_medicine_screen.dart';
import 'screens/medicine_detail_screen.dart';
import 'screens/about_screen.dart';
import 'services/theme_service.dart';

/// 应用根组件：配置主题、国际化与路由表
class MedicineApp extends StatelessWidget {
  const MedicineApp({super.key});

  /// 根据种子色与明暗模式构建主题
  ThemeData _buildTheme(Color seed, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    return MaterialApp(
      title: '小药箱',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(themeService.seedColor, Brightness.light),
      darkTheme: _buildTheme(themeService.seedColor, Brightness.dark),
      themeMode: themeService.mode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/medicine/add': (context) {
          final boxId = ModalRoute.of(context)!.settings.arguments as String;
          return AddEditMedicineScreen(boxId: boxId);
        },
        '/medicine/edit': (context) {
          final id = ModalRoute.of(context)!.settings.arguments as String;
          return AddEditMedicineScreen(medicineId: id);
        },
        '/medicine/detail': (context) {
          final id = ModalRoute.of(context)!.settings.arguments as String;
          return MedicineDetailScreen(medicineId: id);
        },
        '/about': (context) => const AboutScreen(),
      },
    );
  }
}