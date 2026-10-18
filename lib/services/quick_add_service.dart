import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// 快速增加库存档位偏好：+10/+50 或 +28/+100，持久化到 quick_add.json
class QuickAddService extends ChangeNotifier {
  /// 可选档位：索引 0 为 +10/+50，索引 1 为 +28/+100（默认）
  static const List<List<int>> presets = [
    [10, 50],
    [28, 100],
  ];

  int _index = 1;
  bool _loaded = false;

  int get index => _index;
  int get small => presets[_index][0];
  int get large => presets[_index][1];
  bool get loaded => _loaded;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/quick_add.json');
  }

  /// 从 quick_add.json 读取档位偏好
  Future<void> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final i = map['index'] as int? ?? 1;
        _index = (i >= 0 && i < presets.length) ? i : 1;
      }
    } catch (e) {
      debugPrint('加载快速增加库存设置失败: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  /// 切换档位
  Future<void> setPreset(int index) async {
    if (index < 0 || index >= presets.length || _index == index) return;
    _index = index;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({'index': _index}));
    } catch (e) {
      debugPrint('保存快速增加库存设置失败: $e');
    }
  }
}