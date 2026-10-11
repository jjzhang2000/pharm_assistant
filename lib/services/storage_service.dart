import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/medicine.dart';
import '../models/medicine_box.dart';
import 'notification_service.dart';

/// 全局唯一的药品/药箱 JSON 文件存储服务，通过 [ChangeNotifier] 驱动界面刷新
class StorageService extends ChangeNotifier {
  List<MedicineBox> _boxes = [];
  List<Medicine> _medicines = [];
  bool _initialized = false;

  List<MedicineBox> get boxes => List.unmodifiable(_boxes);

  List<Medicine> get medicines => List.unmodifiable(_medicines);

  /// 指定药箱内的药品
  List<Medicine> medicinesForBox(String boxId) =>
      _medicines.where((m) => m.boxId == boxId).toList();

  /// 按 ID 查找药箱
  MedicineBox? boxById(String id) {
    for (final b in _boxes) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// 指定药箱是否为备用药箱
  bool isBackupBox(String boxId) => boxById(boxId)?.isBackup ?? false;

  bool get initialized => _initialized;

  /// 获取 JSON 文件路径
  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/medicines.json');
  }

  /// 从 JSON 文件加载药箱与药品列表，迁移旧数据并自动扣减库存
  Future<void> load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is List) {
          // 旧格式：纯药品数组
          _medicines = decoded
              .map((e) => Medicine.fromJson(e as Map<String, dynamic>))
              .toList();
          _boxes = [];
        } else if (decoded is Map<String, dynamic>) {
          _boxes = (decoded['boxes'] as List?)
                  ?.map((e) => MedicineBox.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [];
          _medicines = (decoded['medicines'] as List?)
                  ?.map((e) => Medicine.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [];
        }
      }
    } catch (e) {
      debugPrint('加载数据失败: $e');
    }

    // 确保至少存在一个默认药箱
    var migrated = false;
    if (_boxes.isEmpty) {
      _boxes.add(MedicineBox(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '小药箱',
        createdAt: DateTime.now(),
        color: MedicineBox.boxPalette.first,
      ));
      migrated = true;
    }

    // 确保存在备用药箱（只记录存量、不自动扣减、不参与短缺统计）
    if (!_boxes.any((b) => b.isBackup)) {
      _boxes.add(MedicineBox(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '备用药箱',
        createdAt: DateTime.now(),
        color: MedicineBox.backupColor,
        isBackup: true,
      ));
      migrated = true;
    }

    // 备用药箱永远排在最末（其余普通药箱保持原有顺序）
    final reordered = [
      ..._boxes.where((b) => !b.isBackup),
      ..._boxes.where((b) => b.isBackup),
    ];
    final orderChanged = reordered.length != _boxes.length ||
        _boxes.asMap().entries.any((e) => e.value.id != reordered[e.key].id);
    _boxes = reordered;
    if (orderChanged) migrated = true;

    final defaultBoxId = _boxes.first.id;

    // 为未分配或颜色重复的药箱分配颜色；备用药箱固定使用专用底色
    final usedColors = <int>{};
    for (int i = 0; i < _boxes.length; i++) {
      final b = _boxes[i];
      if (b.isBackup) {
        if (b.color != MedicineBox.backupColor) {
          _boxes[i] = b.copyWith(color: MedicineBox.backupColor);
          migrated = true;
        }
        continue;
      }
      if (b.color == 0 || usedColors.contains(b.color)) {
        final c = MedicineBox.nextColor(usedColors);
        _boxes[i] = b.copyWith(color: c);
        usedColors.add(c);
        migrated = true;
      } else {
        usedColors.add(b.color);
      }
    }

    // 未归属的药品归入默认药箱
    for (int i = 0; i < _medicines.length; i++) {
      final m = _medicines[i];
      if (m.boxId.isEmpty || !_boxes.any((b) => b.id == m.boxId)) {
        _medicines[i] = m.copyWith(boxId: defaultBoxId);
        migrated = true;
      }
    }

    if (migrated) {
      await _save();
    }

    await _autoDeductStock();

    _initialized = true;
    notifyListeners();
  }

  /// 根据服用周期自动扣减库存，并持久化
  Future<void> _autoDeductStock() async {
    bool changed = false;
    final now = DateTime.now();
    for (int i = 0; i < _medicines.length; i++) {
      final m = _medicines[i];
      // 备用药箱中的药品只记录存量，不参与自动扣减
      if (isBackupBox(m.boxId)) continue;
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
      if (isBackupBox(medicine.boxId)) continue;
      notifier.scheduleStockAlert(medicine);
      notifier.scheduleStarredShortage(medicine, notifyIfShort: true);
    }
  }

  /// 保存药箱与药品列表到 JSON 文件
  Future<void> _save() async {
    try {
      final file = await _getFile();
      final data = {
        'boxes': _boxes.map((b) => b.toJson()).toList(),
        'medicines': _medicines.map((m) => m.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('保存数据失败: $e');
    }
  }

  /// 新增药箱（返回新建的药箱；新药箱始终插入到备用药箱之前）
  Future<MedicineBox> addBox(String name) async {
    final usedColors = _boxes.map((b) => b.color).toSet();
    final box = MedicineBox(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      createdAt: DateTime.now(),
      color: MedicineBox.nextColor(usedColors),
    );
    final backupIndex = _boxes.indexWhere((b) => b.isBackup);
    if (backupIndex >= 0) {
      _boxes.insert(backupIndex, box);
    } else {
      _boxes.add(box);
    }
    await _save();
    notifyListeners();
    return box;
  }

  /// 重命名药箱
  Future<void> renameBox(String id, String name) async {
    final index = _boxes.indexWhere((b) => b.id == id);
    if (index != -1) {
      final old = _boxes[index];
      _boxes[index] = MedicineBox(
        id: old.id,
        name: name,
        createdAt: old.createdAt,
        color: old.color,
      );
      await _save();
      notifyListeners();
    }
  }

  /// 删除药箱及其中的所有药品
  Future<void> deleteBox(String id) async {
    final notifier = NotificationService();
    for (final m in _medicines.where((m) => m.boxId == id)) {
      await notifier.cancelForMedicine(m.id);
    }
    _medicines.removeWhere((m) => m.boxId == id);
    _boxes.removeWhere((b) => b.id == id);
    await _save();
    notifyListeners();
  }

  /// 添加药品
  Future<void> add(Medicine medicine) async {
    _medicines.add(medicine);
    await _save();
    notifyListeners();
    if (isBackupBox(medicine.boxId)) return;
    final notifier = NotificationService();
    notifier.scheduleStockAlert(medicine);
    notifier.scheduleStarredShortage(medicine);
    if (medicine.isStarred && medicine.needsAlert) {
      notifier.showStarredShortage(medicine);
    }
  }

  /// 更新药品
  Future<void> update(Medicine medicine) async {
    final index = _medicines.indexWhere((m) => m.id == medicine.id);
    if (index != -1) {
      final old = _medicines[index];
      final wasShort = old.isStarred && old.needsAlert;
      final isShort = medicine.isStarred && medicine.needsAlert;
      _medicines[index] = medicine;
      await _save();
      notifyListeners();
      if (isBackupBox(medicine.boxId)) return;
      final notifier = NotificationService();
      notifier.scheduleStockAlert(medicine);
      notifier.scheduleStarredShortage(medicine);
      // 由「未短缺」转为「短缺」（如扣减库存、刚标记星标）时立即通知一次
      if (isShort && !wasShort) {
        notifier.showStarredShortage(medicine);
      }
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
    for (final m in _medicines) {
      if (m.id == id) return m;
    }
    return null;
  }
}