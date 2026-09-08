import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/medicine.dart';
import '../services/storage_service.dart';

/// 药品卡片：展示名称/剂量/剩余天数，支持快速加减库存与长按拖动移动
class MedicineCard extends StatelessWidget {
  final Medicine medicine;
  final void Function(String boxId) onMovedToBox;

  const MedicineCard({
    super.key,
    required this.medicine,
    required this.onMovedToBox,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = context.read<StorageService>();
    final remainingDays = medicine.remainingDays;
    final isAlert = medicine.needsAlert;

    return Card(
      elevation: isAlert ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isAlert
            ? BorderSide(color: theme.colorScheme.error, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.pushNamed(context, '/medicine/detail',
              arguments: medicine.id);
          if (result is String) {
            onMovedToBox(result);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      medicine.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: isAlert
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    remainingDays == double.infinity
                        ? '--'
                        : '${remainingDays.floor()} 天',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isAlert
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isAlert)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  const Spacer(),
                  Icon(
                    Icons.shelves,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  _QuickAdjustButton(
                    icon: Icons.remove,
                    onTap: () {
                      if (medicine.currentStock > 0) {
                        final updated = medicine.copyWith(
                          currentStock: medicine.currentStock - 1,
                          updatedAt: DateTime.now(),
                          lastStockUpdate: DateTime.now(),
                        );
                        storage.update(updated);
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${medicine.currentStock}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _QuickAdjustButton(
                    icon: Icons.add,
                    onTap: () {
                      final updated = medicine.copyWith(
                        currentStock: medicine.currentStock + 1,
                        updatedAt: DateTime.now(),
                        lastStockUpdate: DateTime.now(),
                      );
                      storage.update(updated);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAdjustButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAdjustButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}