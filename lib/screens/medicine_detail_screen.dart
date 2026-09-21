import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/medicine.dart';
import '../services/storage_service.dart';

/// 药品详情页：展示库存与用药计划，提供编辑、移动、删除等操作
class MedicineDetailScreen extends StatelessWidget {
  final String medicineId;

  const MedicineDetailScreen({super.key, required this.medicineId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<StorageService>(
      builder: (context, storage, _) {
        final medicine = storage.findById(medicineId);

        if (medicine == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('药品不存在')),
          );
        }

        final isBackup = storage.isBackupBox(medicine.boxId);
        final remainingDays = medicine.remainingDays;
        final isAlert = !isBackup && medicine.needsAlert;

        return Scaffold(
          appBar: AppBar(
            title: Text(medicine.name),
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: '编辑',
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(),
                onPressed: () async {
                  await Navigator.pushNamed(
                    context,
                    '/medicine/edit',
                    arguments: medicineId,
                  );
                },
              ),
              PopupMenuButton<_MedicineAction>(
                tooltip: '更多',
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.more_horiz),
                ),
                onSelected: (action) =>
                    _handleAction(context, storage, medicine, action),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _MedicineAction.move,
                    child: Row(
                      children: [
                        Icon(Icons.drive_file_move_outline, size: 20),
                        SizedBox(width: 12),
                        Text('移动'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _MedicineAction.delete,
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20),
                        SizedBox(width: 12),
                        Text('删除'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部卡片：备用药箱只显示存量，普通药品显示剩余存量 / 天数
                if (isBackup)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${Medicine.formatStock(medicine.currentStock)} ${medicine.form}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 14,
                              color: theme.colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '当前存量',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isAlert
                          ? theme.colorScheme.errorContainer
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        if (isAlert)
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 32,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        Text(
                          '${Medicine.formatStock(medicine.currentStock)} ${medicine.form} / '
                          '${remainingDays == double.infinity ? '--' : '${remainingDays.floor()} 天'}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isAlert
                                ? theme.colorScheme.onErrorContainer
                                : theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 14,
                              color: isAlert
                                  ? theme.colorScheme.onErrorContainer
                                      .withValues(alpha: 0.8)
                                  : theme.colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '剩余存量 / 天数',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isAlert
                                    ? theme.colorScheme.onErrorContainer
                                        .withValues(alpha: 0.8)
                                    : theme.colorScheme.onPrimaryContainer
                                        .withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // 药品信息
                const _SectionHeader(icon: Icons.medication, label: '药品信息'),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.medication_outlined,
                  label: '规格',
                  value: '${medicine.dosageStrength.toInt()} ${medicine.dosageStrengthUnit} / ${medicine.form}',
                ),

                // 服用方式：备用药箱不服用，不展示
                if (!isBackup) ...[
                  const SizedBox(height: 24),
                  const _SectionHeader(icon: Icons.repeat, label: '服用方式'),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.schedule,
                    label: '频次',
                    value: '每 ${medicine.periodValue} ${medicine.periodUnit} ${medicine.timesPerPeriod} 次',
                  ),
                  _InfoRow(
                    icon: Icons.scale,
                    label: '每次剂量',
                    value: '${medicine.dosagePerTime} ${medicine.form}',
                  ),
                  if (medicine.hasSchedule)
                    _InfoRow(
                      icon: Icons.access_time,
                      label: '服用安排',
                      value: _scheduleSummary(medicine),
                    ),
                  if (medicine.isInfrequent || medicine.hasSchedule)
                    _InfoRow(
                      icon: Icons.event,
                      label: '下次服用日期',
                      value: medicine.adjustedNextDoseDate != null
                          ? '${medicine.adjustedNextDoseDate!.year}/${medicine.adjustedNextDoseDate!.month}/${medicine.adjustedNextDoseDate!.day}'
                          : '未设置',
                    ),
                ],

                const SizedBox(height: 24),

                // 库存信息
                const _SectionHeader(icon: Icons.inventory_2, label: '库存信息'),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.shelves,
                  label: '当前存量',
                  value: '${Medicine.formatStock(medicine.currentStock)} ${medicine.form}',
                ),
                if (!isBackup)
                  _InfoRow(
                    icon: Icons.notifications_active_outlined,
                    label: '提醒阈值',
                    value: '低于 ${medicine.alertThreshold} 天提醒',
                  ),

                const SizedBox(height: 24),

                // 库存调整
                const _SectionHeader(icon: Icons.tune, label: '快速调整库存'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: () {
                          if (medicine.currentStock > 0) {
                            final updated = medicine.copyWith(
                              currentStock: medicine.currentStock - 1,
                              updatedAt: DateTime.now(),
                              lastStockUpdate: DateTime.now(),
                            );
                            storage.update(updated);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Icon(Icons.remove),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: FilledButton(
                        onPressed: () {
                          final updated = medicine.copyWith(
                            currentStock: medicine.currentStock + 1,
                            updatedAt: DateTime.now(),
                            lastStockUpdate: DateTime.now(),
                          );
                          storage.update(updated);
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor: theme.colorScheme.onPrimaryContainer,
                        ),
                        child: const Icon(Icons.add),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: FilledButton(
                        onPressed: () {
                          final updated = medicine.copyWith(
                            currentStock: medicine.currentStock + 10,
                            updatedAt: DateTime.now(),
                            lastStockUpdate: DateTime.now(),
                          );
                          storage.update(updated);
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor: theme.colorScheme.onPrimaryContainer,
                        ),
                        child: const Text('+10'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: FilledButton(
                        onPressed: () {
                          final updated = medicine.copyWith(
                            currentStock: medicine.currentStock + 50,
                            updatedAt: DateTime.now(),
                            lastStockUpdate: DateTime.now(),
                          );
                          storage.update(updated);
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor: theme.colorScheme.onPrimaryContainer,
                        ),
                        child: const Text('+50'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 生成服用安排的显示文本，如：每天 08:00 14:00；每周 下一轮 8/18、8/20 09:00
  String _scheduleSummary(Medicine m) {
    final parts = <String>[];
    if (m.periodUnit == '天') {
      for (final s in m.doseSlots) {
        parts.add('${s.toString().padLeft(2, '0')}:00');
      }
      return parts.join(' ');
    }
    // 周/月：显式下一轮的各次服用日期 + 服用小时
    for (final d in m.nextRoundDates) {
      parts.add('${d.month}/${d.day}');
    }
    parts.add('${(m.doseHour ?? 8).toString().padLeft(2, '0')}:00');
    return parts.join(' ');
  }

  void _confirmDelete(
      BuildContext context, StorageService storage, Medicine medicine) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${medicine.name}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              storage.delete(medicine.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 处理「更多」菜单命令
  Future<void> _handleAction(BuildContext context, StorageService storage,
      Medicine medicine, _MedicineAction action) async {
    switch (action) {
      case _MedicineAction.move:
        await _moveMedicine(context, storage, medicine);
        break;
      case _MedicineAction.delete:
        _confirmDelete(context, storage, medicine);
        break;
    }
  }

  /// 将药品移动到另一个药箱（或新建药箱后移入）
  Future<void> _moveMedicine(
      BuildContext context, StorageService storage, Medicine medicine) async {
    final target = await _showMoveDialog(context, storage, medicine);
    if (target == null || !context.mounted) return;

    String? targetBoxId;
    if (target.isNew) {
      final name = await _showNewBoxNameDialog(context);
      if (name == null || !context.mounted) return;
      final newBox = await storage.addBox(name);
      targetBoxId = newBox.id;
    } else {
      targetBoxId = target.boxId;
    }

    if (targetBoxId == null || !context.mounted) return;
    await storage.update(
        medicine.copyWith(boxId: targetBoxId, updatedAt: DateTime.now()));
    if (!context.mounted) return;
    Navigator.pop(context, targetBoxId);
  }

  /// 弹出药箱选择列表（不含当前药箱），最后一项为「新药箱」
  Future<_MoveTarget?> _showMoveDialog(
      BuildContext context, StorageService storage, Medicine medicine) {
    final otherBoxes =
        storage.boxes.where((b) => b.id != medicine.boxId).toList();
    return showDialog<_MoveTarget>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('移动到'),
        children: [
          for (final box in otherBoxes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, _MoveTarget.box(box.id)),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Color(box.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      box.name,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, const _MoveTarget.newBox()),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.add_circle_outline,
                    size: 22, color: Theme.of(ctx).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('新药箱'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 弹出新建药箱输入框，返回非空药箱名
  Future<String?> _showNewBoxNameDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新药箱'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '请输入药箱名'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    ).then((value) {
      controller.dispose();
      return (value == null || value.isEmpty) ? null : value;
    });
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 「更多」菜单命令
enum _MedicineAction { move, delete }

/// 移动目标：现有药箱（boxId）或新建药箱（isNew）
class _MoveTarget {
  final String? boxId;
  final bool isNew;

  const _MoveTarget.box(this.boxId) : isNew = false;
  const _MoveTarget.newBox()
      : boxId = null,
        isNew = true;
}