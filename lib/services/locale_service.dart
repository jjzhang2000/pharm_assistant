import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// 全局语言偏好：当前界面语言，持久化到 locale.json
class LocaleService extends ChangeNotifier {
  /// 通知服务等无 BuildContext 的场景读取的当前语言（默认中文）
  static Locale current = const Locale('zh');

  Locale _locale = const Locale('zh');
  bool _loaded = false;

  Locale get locale => _locale;
  bool get loaded => _loaded;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/locale.json');
  }

  /// 从 locale.json 读取语言偏好
  Future<void> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        _locale = map['locale'] == 'en' ? const Locale('en') : const Locale('zh');
      }
    } catch (e) {
      debugPrint('加载语言设置失败: $e');
    }
    current = _locale;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    final normalized =
        locale.languageCode == 'en' ? const Locale('en') : const Locale('zh');
    if (_locale == normalized) return;
    _locale = normalized;
    current = normalized;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f.writeAsString(
          jsonEncode({'locale': _locale.languageCode}));
    } catch (e) {
      debugPrint('保存语言设置失败: $e');
    }
  }
}