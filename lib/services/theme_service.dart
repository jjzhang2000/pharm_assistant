import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// 可选配色主题（种子色）
class AppThemeOption {
  final String label;
  final Color seed;

  const AppThemeOption(this.label, this.seed);
}

/// 全局主题偏好：明暗模式 + 配色种子色，持久化到 settings.json
class ThemeService extends ChangeNotifier {
  /// 可选配色：青 / 蓝 / 绿 / 紫
  static const List<AppThemeOption> seedOptions = [
    AppThemeOption('青', Color(0xFF009688)),
    AppThemeOption('蓝', Color(0xFF1E88E5)),
    AppThemeOption('绿', Color(0xFF43A047)),
    AppThemeOption('紫', Color(0xFF8E24AA)),
  ];

  ThemeMode _mode = ThemeMode.system;
  int _seedIndex = 0;
  bool _loaded = false;

  ThemeMode get mode => _mode;
  int get seedIndex => _seedIndex;
  Color get seedColor => seedOptions[_seedIndex].seed;
  bool get loaded => _loaded;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/settings.json');
  }

  /// 从 settings.json 读取主题偏好
  Future<void> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final modeIndex = map['mode'] as int? ?? 0;
        _mode = (modeIndex >= 0 && modeIndex < ThemeMode.values.length)
            ? ThemeMode.values[modeIndex]
            : ThemeMode.system;
        _seedIndex = map['seed'] as int? ?? 0;
        if (_seedIndex < 0 || _seedIndex >= seedOptions.length) _seedIndex = 0;
      }
    } catch (e) {
      debugPrint('加载主题设置失败: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _save();
  }

  Future<void> setSeed(int index) async {
    if (index < 0 || index >= seedOptions.length || _seedIndex == index) return;
    _seedIndex = index;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f.writeAsString(
          jsonEncode({'mode': _mode.index, 'seed': _seedIndex}));
    } catch (e) {
      debugPrint('保存主题设置失败: $e');
    }
  }
}