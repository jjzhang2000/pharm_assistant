import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/medicine.dart';
import '../services/storage_service.dart';

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

        final remainingDays = medicine.remainingDays;
        final isAlert = medicine.needsAlert;

        return Scaffold(
          appBar: AppBar(
            title: Text(medicine.name),
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: '编辑',
                onPressed: () async {
                  await Navigator.pushNamed(
                    context,
                    '/medicine/edit',
                    arguments: medicineId,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '删除',
                onPressed: () => _confirmDelete(context, storage, medicine),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 剩余天数卡片
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
                        remainingDays == double.infinity
                            ? '--'
                            : remainingDays.toStringAsFixed(1),
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
                            Icons.calendar_today,
                            size: 14,
                            color: isAlert
                                ? theme.colorScheme.onErrorContainer
                                    .withValues(alpha: 0.8)
                                : theme.colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '剩余天数',
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
                _SectionHeader(icon: Icons.medication, label: '药品信息'),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.medication_outlined,
                  label: '规格',
                  value: '${medicine.dosageStrength.toInt()} ${medicine.dosageStrengthUnit} / ${medicine.form}',
                ),

                const SizedBox(height: 24),

                // 服用方式
                _SectionHeader(icon: Icons.repeat, label: '服用方式'),
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
                if (medicine.isInfrequent)
                  _InfoRow(
                    icon: Icons.event,
                    label: '下次服用日期',
                    value: medicine.nextDoseDate != null
                        ? '${medicine.nextDoseDate!.year}/${medicine.nextDoseDate!.month}/${medicine.nextDoseDate!.day}'
                        : '未设置',
                  ),

                const SizedBox(height: 24),

                // 库存信息
                _SectionHeader(icon: Icons.inventory_2, label: '库存信息'),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.shelves,
                  label: '当前存量',
                  value: '${medicine.currentStock} ${medicine.form}',
                ),
                _InfoRow(
                  icon: Icons.notifications_active_outlined,
                  label: '提醒阈值',
                  value: '低于 ${medicine.alertThreshold} 天提醒',
                ),

                const SizedBox(height: 24),

                // 库存调整
                _SectionHeader(icon: Icons.tune, label: '快速调整库存'),
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
                            currentStock: medicine.currentStock + 7,
                            updatedAt: DateTime.now(),
                          );
                          storage.update(updated);
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor: theme.colorScheme.onPrimaryContainer,
                        ),
                        child: const Text('+7'),
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