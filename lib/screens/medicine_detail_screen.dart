import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/gen/app_localizations.dart';
import '../l10n/unit_labels.dart';
import '../models/medicine.dart';
import '../services/storage_service.dart';

/// 药品详情页：展示库存与用药计划，提供编辑、移动、删除等操作
class MedicineDetailScreen extends StatelessWidget {
  final String medicineId;

  const MedicineDetailScreen({super.key, required this.medicineId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Consumer<StorageService>(
      builder: (context, storage, _) {
        final medicine = storage.findById(medicineId);

        if (medicine == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(l10n.medicineNotFound)),
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
                tooltip: l10n.edit,
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
                tooltip: l10n.more,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.more_horiz),
                ),
                onSelected: (action) =>
                    _handleAction(context, storage, medicine, action),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _MedicineAction.move,
                    child: Row(
                      children: [
                        const Icon(Icons.drive_file_move_outline, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.move),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _MedicineAction.delete,
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.delete),
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
                    decoration: _headerDecoration(
                      theme,
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.primary,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${Medicine.formatStock(medicine.currentStock)} ${formLabel(l10n, medicine.form)}',
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
                              l10n.currentStock,
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
                    decoration: _headerDecoration(
                      theme,
                      isAlert
                          ? theme.colorScheme.errorContainer
                          : theme.colorScheme.primaryContainer,
                      isAlert
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
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
                          '${Medicine.formatStock(medicine.currentStock)} ${formLabel(l10n, medicine.form)} / '
                          '${remainingDays == double.infinity ? '--' : l10n.daysRemaining(remainingDays.floor())}',
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
                              l10n.remainingStockDays,
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
                _SectionHeader(icon: Icons.medication, label: l10n.medicineInfo),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.medication_outlined,
                  label: l10n.spec,
                  value: '${medicine.dosageStrength.toInt()} ${medicine.dosageStrengthUnit} / ${formLabel(l10n, medicine.form)}',
                ),

                // 服用方式：备用药箱不服用，不展示
                if (!isBackup) ...[
                  const SizedBox(height: 24),
                  _SectionHeader(icon: Icons.repeat, label: l10n.dosageMethod),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.schedule,
                    label: l10n.frequency,
                    value: l10n.frequencyValue(
                      '${medicine.periodValue}',
                      periodUnitLabel(l10n, medicine.periodUnit),
                      '${medicine.timesPerPeriod}',
                    ),
                  ),
                  _InfoRow(
                    icon: Icons.scale,
                    label: l10n.dosePerTimeLabel,
                    value: '${medicine.dosagePerTime} ${formLabel(l10n, medicine.form)}',
                  ),
                  if (medicine.hasSchedule)
                    _ScheduleChips(medicine: medicine),
                  if (medicine.isInfrequent || medicine.hasSchedule)
                    _InfoRow(
                      icon: Icons.event,
                      label: l10n.nextDoseDate,
                      value: medicine.adjustedNextDoseDate != null
                          ? '${medicine.adjustedNextDoseDate!.year}/${medicine.adjustedNextDoseDate!.month}/${medicine.adjustedNextDoseDate!.day}'
                          : l10n.notSet,
                    ),
                ],

                const SizedBox(height: 24),

                // 库存信息
                _SectionHeader(icon: Icons.inventory_2, label: l10n.inventoryInfo),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.shelves,
                  label: l10n.currentStock,
                  value: '${Medicine.formatStock(medicine.currentStock)} ${formLabel(l10n, medicine.form)}',
                ),
                if (!isBackup)
                  _InfoRow(
                    icon: Icons.notifications_active_outlined,
                    label: l10n.reminderThreshold,
                    value: l10n.belowThresholdReminder('${medicine.alertThreshold}'),
                  ),

                const SizedBox(height: 24),

                _buildQuickAdjust(context, storage, medicine),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 头部卡片装饰：渐变背景 + 柔和阴影，突出视觉焦点
  BoxDecoration _headerDecoration(ThemeData theme, Color base, Color accent) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(base, accent, 0.18)!, base],
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.22),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// 快速调整库存步进器：位于页面底部「快速调整库存」分组中
  Widget _buildQuickAdjust(
      BuildContext context, StorageService storage, Medicine medicine) {
    final theme = Theme.of(context);
    return Row(
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
    );
  }

  void _confirmDelete(
      BuildContext context, StorageService storage, Medicine medicine) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.confirmDeleteMedicine(medicine.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
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
            child: Text(l10n.delete),
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
    final l10n = AppLocalizations.of(context);
    final otherBoxes =
        storage.boxes.where((b) => b.id != medicine.boxId).toList();
    return showDialog<_MoveTarget>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.moveTo),
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
                Text(l10n.newBox),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 弹出新建药箱输入框，返回非空药箱名
  Future<String?> _showNewBoxNameDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.newBox),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.boxNameHint),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    ).then((value) {
      controller.dispose();
      return (value == null || value.isEmpty) ? null : value;
    });
  }
}

/// 服用安排胶囊标签：每个时间点/日期渲染为一个 Chip
class _ScheduleChips extends StatelessWidget {
  final Medicine medicine;

  const _ScheduleChips({required this.medicine});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final labels = _scheduleLabels(medicine);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.access_time,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.scheduleSection,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in labels)
                  Chip(
                    label: Text(label),
                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 生成服用安排胶囊的标签列表：每天→各时刻；每周/月→各日期 + 服用小时
List<String> _scheduleLabels(Medicine m) {
  if (m.periodUnit == '天') {
    return [
      for (final s in m.doseSlots)
        '${s.toString().padLeft(2, '0')}:00',
    ];
  }
  return [
    for (final d in m.nextRoundDates) '${d.month}/${d.day}',
    '${(m.doseHour ?? 8).toString().padLeft(2, '0')}:00',
  ];
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