import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/medicine.dart';
import 'notification_service.dart';

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

  /// 从 JSON 文件加载药品列表，并自动扣减库存
  Future<void> load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _medicines =
            jsonList.map((e) => Medicine.fromJson(e as Map<String, dynamic>)).toList();
        await _autoDeductStock();
      }
    } catch (e) {
      debugPrint('加载数据失败: $e');
    }
    _initialized = true;
    notifyListeners();
  }

  /// 根据服用周期自动扣减库存，并持久化
  Future<void> _autoDeductStock() async {
    bool changed = false;
    final now = DateTime.now();
    for (int i = 0; i < _medicines.length; i++) {
      final m = _medicines[i];
      final adjusted = m.adjustedStock;
      if (adjusted < m.currentStock) {
        debugPrint(
            '[自动扣减] ${m.name}: ${m.currentStock} -> $adjusted (lastStockUpdate=${m.lastStockUpdate})');
        _medicines[i] = m.copyWith(
          currentStock: adjusted,
          lastStockUpdate: now,
          // 低频药品：扣减后推进下一次服用日期
          nextDoseDate: m.adjustedNextDoseDate,
          // 周/月安排：扣减后推进到下一轮（无安排时为 null 保持不变）
          nextRoundDates: m.advancedRoundDates,
          updatedAt: now,
        );
        changed = true;
      } else {
        debugPrint(
            '[自动扣减] ${m.name}: 无需扣减 (stock=${m.currentStock}, adjusted=$adjusted, lastStockUpdate=${m.lastStockUpdate})');
      }
    }
    if (changed) {
      await _save();
    }
  }

  /// 为所有药品预约定时通知（需在 NotificationService.init() 之后调用）
  void scheduleAllAlerts() {
    final notifier = NotificationService();
    for (final medicine in _medicines) {
      notifier.scheduleStockAlert(medicine);
    }
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
    NotificationService().scheduleStockAlert(medicine);
  }

  /// 更新药品
  Future<void> update(Medicine medicine) async {
    final index = _medicines.indexWhere((m) => m.id == medicine.id);
    if (index != -1) {
      _medicines[index] = medicine;
      await _save();
      notifyListeners();
      NotificationService().scheduleStockAlert(medicine);
    }
  }

  /// 删除药品
  Future<void> delete(String id) async {
    _medicines.removeWhere((m) => m.id == id);
    await _save();
    notifyListeners();
    NotificationService().cancelForMedicine(id);
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