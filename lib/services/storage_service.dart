import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/medicine.dart';

class StorageService extends ChangeNotifier {
  List<Medicine> _medicines = [];
  bool _initialized = false;

  List<Medicine> get medicines => List.unmodifiable(_medicines);

  bool get initialized => _initialized;

  /// 获取 JSON 文件路径
  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/medicines.json');
  }

  /// 从 JSON 文件加载药品列表
  Future<void> load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _medicines =
            jsonList.map((e) => Medicine.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('加载数据失败: $e');
    }
    _initialized = true;
    notifyListeners();
  }

  /// 保存药品列表到 JSON 文件
  Future<void> _save() async {
    try {
      final file = await _getFile();
      final jsonList = _medicines.map((m) => m.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('保存数据失败: $e');
    }
  }

  /// 添加药品
  Future<void> add(Medicine medicine) async {
    _medicines.add(medicine);
    await _save();
    notifyListeners();
  }

  /// 更新药品
  Future<void> update(Medicine medicine) async {
    final index = _medicines.indexWhere((m) => m.id == medicine.id);
    if (index != -1) {
      _medicines[index] = medicine;
      await _save();
      notifyListeners();
    }
  }

  /// 删除药品
  Future<void> delete(String id) async {
    _medicines.removeWhere((m) => m.id == id);
    await _save();
    notifyListeners();
  }

  /// 根据 ID 查找药品
  Medicine? findById(String id) {
    try {
      return _medicines.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 获取需要提醒的药品列表
  List<Medicine> get alertMedicines =>
      _medicines.where((m) => m.needsAlert).toList();
}