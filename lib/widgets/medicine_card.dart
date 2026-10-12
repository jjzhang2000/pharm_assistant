import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/medicine.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';

/// 药品卡片：展示名称/剂量/剩余天数，支持快速加减库存与长按拖动移动
class MedicineCard extends StatefulWidget {
  final Medicine medicine;
  final void Function(String boxId) onMovedToBox;
  final VoidCallback onQuickAdjust;

  const MedicineCard({
    super.key,
    required this.medicine,
    required this.onMovedToBox,
    required this.onQuickAdjust,
  });

  @override
  State<MedicineCard> createState() => _MedicineCardState();
}

class _MedicineCardState extends State<MedicineCard> {
  Medicine get medicine => widget.medicine;

  /// 本地展示的库存：点击后立即刷新，存储数据也已同步落盘
  late double _stock;

  @override
  void initState() {
    super.initState();
    _stock = medicine.currentStock;
  }

  @override
  void didUpdateWidget(covariant MedicineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _stock = widget.medicine.currentStock;
  }

  void _adjust(int delta) {
    final newStock = _stock + delta;
    if (newStock < 0) return;
    setState(() => _stock = newStock);
    // 立即持久化（同步进入内存并为文件落盘排队），仅排序由首页延迟处理
    context.read<StorageService>().update(medicine.copyWith(
          currentStock: newStock,
          updatedAt: DateTime.now(),
          lastStockUpdate: DateTime.now(),
        ));
    widget.onQuickAdjust();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = context.read<StorageService>();
    final isBackup = storage.isBackupBox(medicine.boxId);
    final remainingDays = medicine.remainingDays;
    final isAlert = !isBackup && medicine.needsAlert;

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
            widget.onMovedToBox(result);
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
                  if (!isBackup) ...[
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
                ],
              ),

              const SizedBox(height: 4),
              Row(
                children: [
                  if (isBackup)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '备用',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  else
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        storage.update(medicine.copyWith(
                          isStarred: !medicine.isStarred,
                          updatedAt: DateTime.now(),
                        ));
                        // 切换星标后延迟重排，避免卡片位置立即突变
                        widget.onQuickAdjust();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          medicine.isStarred ? Icons.star : Icons.star_border,
                          size: 22,
                          color: medicine.isStarred
                              ? starRed
                              : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  const Spacer(),
                  _QuickAdjustButton(
                    icon: Icons.remove,
                    onTap: () => _adjust(-1),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: Text(
                      Medicine.formatStock(_stock),
                      key: ValueKey(_stock),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _QuickAdjustButton(
                    icon: Icons.add,
                    onTap: () => _adjust(1),
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

class _QuickAdjustButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAdjustButton({required this.icon, required this.onTap});

  @override
  State<_QuickAdjustButton> createState() => _QuickAdjustButtonState();
}

class _QuickAdjustButtonState extends State<_QuickAdjustButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      scale: _pressed ? 0.86 : 1.0,
      duration: const Duration(milliseconds: 90),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onTap,
          onHighlightChanged: (v) {
            if (_pressed != v) setState(() => _pressed = v);
          },
          // 38×38 正方形触控区
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(widget.icon, size: 20, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}