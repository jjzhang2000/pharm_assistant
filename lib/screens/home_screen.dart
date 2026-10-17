import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:gal/gal.dart';
import 'package:provider/provider.dart';

import '../l10n/gen/app_localizations.dart';
import '../l10n/unit_labels.dart';
import '../models/medicine.dart';
import '../models/medicine_box.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/medicine_card.dart';
import '../widgets/empty_state.dart';

/// 首页：多药箱左右滑动切换 + 短缺药品负一页；药品卡片支持长按拖动移动
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentIndex = 0;
  double _dragDelta = 0;
  bool _draggingMedicine = false;

  /// 短缺药品页整页长截图的边界标识
  final GlobalKey _shortageKey = GlobalKey();

  /// 快速增减库存后延迟重排的定时器；连续增减时重置
  Timer? _resortTimer;

  /// 各药箱当前展示顺序缓存（boxId -> 有序药品 id），冻结期内保持稳定
  final Map<String, List<String>> _orderCache = {};

  @override
  void dispose() {
    _resortTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// 快速增减库存或切换星标时回调：重置排序冻结窗口（3 秒）
  void _onQuickAdjust() {
    _resortTimer?.cancel();
    _resortTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() {});
    });
  }

  /// 新建药箱并切换到新药箱页
  Future<void> _addBox() async {
    final name = await _showAddBoxDialog();
    if (name == null) return;
    if (!mounted) return;

    final storage = context.read<StorageService>();
    final box = await storage.addBox(name);

    if (!mounted) return;
    final newIndex = storage.boxes.indexWhere((b) => b.id == box.id) + 1;
    // 等待新页面挂载后再跳转
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.animateToPage(
          newIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// 弹出新建药箱输入框，返回非空药箱名
  Future<String?> _showAddBoxDialog() {
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

  /// 处理药箱菜单命令（新建 / 重命名 / 删除）
  Future<void> _handleBoxAction(_BoxAction action, MedicineBox box) async {
    final storage = context.read<StorageService>();
    switch (action) {
      case _BoxAction.newBox:
        await _addBox();
        break;
      case _BoxAction.rename:
        final name = await _showRenameBoxDialog(box.name);
        if (name == null || !mounted) return;
        await storage.renameBox(box.id, name);
        break;
      case _BoxAction.delete:
        final confirmed = await _confirmDeleteBox(box);
        if (!confirmed || !mounted) return;
        final boxIndex = _currentIndex - 1;
        await storage.deleteBox(box.id);
        if (!mounted) return;
        final newCount = storage.boxes.length;
        final newBoxIndex = boxIndex.clamp(0, newCount - 1);
        setState(() => _currentIndex = newBoxIndex + 1);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(newBoxIndex + 1);
          }
        });
        break;
    }
  }

  /// 弹出重命名药箱输入框，返回非空新名称
  Future<String?> _showRenameBoxDialog(String currentName) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameBox),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.newBoxNameHint),
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

  /// 弹出删除药箱确认框
  Future<bool> _confirmDeleteBox(MedicineBox box) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.confirmDeleteBox(box.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 跳转到添加药品页，返回后刷新通知
  void _navigateToAdd(String boxId) async {
    await Navigator.pushNamed(context, '/medicine/add', arguments: boxId);
  }

  /// 切换到指定药箱
  void _goToBox(String boxId) {
    final storage = context.read<StorageService>();
    final boxIndex = storage.boxes.indexWhere((b) => b.id == boxId);
    if (boxIndex < 0) return;
    final pageIndex = boxIndex + 1;
    if (pageIndex == _currentIndex) return;
    setState(() => _currentIndex = pageIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// 长按拖动时展示的全屏药箱概览（类似安卓桌面的各页面缩略视图）
  Widget _buildBoxOverview(StorageService storage, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Text(
                    l10n.dragMedicineHint,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 240,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: storage.boxes.length + 1,
                    itemBuilder: (context, i) {
                      if (i == storage.boxes.length) {
                        return _buildNewBoxTarget(theme);
                      }
                      final box = storage.boxes[i];
                      return DragTarget<Medicine>(
                        onWillAcceptWithDetails: (d) =>
                            d.data.boxId != box.id,
                        onAcceptWithDetails: (d) =>
                            _moveMedicine(d.data, box.id),
                        builder: (context, candidate, rejected) {
                          final active = candidate.isNotEmpty;
                          return AnimatedScale(
                            scale: active ? 1.05 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Color(box.color),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: active
                                      ? theme.colorScheme.primary
                                      : Colors.white24,
                                  width: active ? 3 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 44,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text(
                                      box.isBackup ? l10n.backupBox : box.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.medicineCount(storage
                                        .medicinesForBox(box.id)
                                        .length),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 概览中的「新药箱」卡片：拖入即新建药箱并移入
  Widget _buildNewBoxTarget(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return DragTarget<Medicine>(
      onAcceptWithDetails: (d) => _moveMedicineToNewBox(d.data),
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty;
        return AnimatedScale(
          scale: active ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active ? theme.colorScheme.primary : Colors.white24,
                width: active ? 3 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, size: 44, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  l10n.newBox,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 新建一个不重名的药箱，并把药品移入
  Future<void> _moveMedicineToNewBox(Medicine medicine) async {
    final storage = context.read<StorageService>();
    final name = _uniqueBoxName(storage);
    final box = await storage.addBox(name);
    await storage.update(
        medicine.copyWith(boxId: box.id, updatedAt: DateTime.now()));
  }

  /// 生成不重名的药箱名：新药箱、新药箱2、新药箱3……
  String _uniqueBoxName(StorageService storage) {
    final base = AppLocalizations.of(context).newBox;
    final existing = storage.boxes.map((b) => b.name).toSet();
    if (!existing.contains(base)) return base;
    var i = 2;
    while (existing.contains('$base$i')) {
      i++;
    }
    return '$base$i';
  }

  /// 拖动时跟随手指的药品预览
  Widget _medicineDragFeedback(Medicine medicine, ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: Card(
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            medicine.name,
            style: theme.textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  /// 把药品移动到指定药箱
  void _moveMedicine(Medicine medicine, String boxId) {
    if (medicine.boxId == boxId) return;
    context.read<StorageService>().update(
        medicine.copyWith(boxId: boxId, updatedAt: DateTime.now()));
  }

  /// 切换到下一个药箱
  void _goToNext() {
    if (_pageController.hasClients) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 切换到上一个药箱
  void _goToPrevious() {
    if (_pageController.hasClients) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 星标药品优先显示；星标与非星标各自按剩余天数递增排序。
  /// 快速增减库存或切换星标后的冻结期内，复用缓存的顺序，避免卡片位置突变导致误点。
  List<Medicine> _sortedForBox(String boxId, List<Medicine> medicines) {
    // 备用药箱只记录存量，不按剩余天数/短缺排序，保持添加顺序
    if (context.read<StorageService>().isBackupBox(boxId)) {
      return List.of(medicines);
    }
    final frozen = _resortTimer != null && _resortTimer!.isActive;
    if (frozen) {
      final order = _orderCache[boxId];
      if (order != null) {
        final byId = {for (final m in medicines) m.id: m};
        return [
          for (final id in order)
            if (byId.containsKey(id)) byId[id]!,
        ];
      }
    }
    final sorted = [...medicines]
      ..sort((a, b) {
        if (a.isStarred != b.isStarred) return a.isStarred ? -1 : 1;
        return a.remainingDays.compareTo(b.remainingDays);
      });
    if (!frozen) {
      _orderCache[boxId] = sorted.map((m) => m.id).toList();
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Consumer<StorageService>(
      builder: (context, storage, _) {
        if (!storage.initialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final boxes = storage.boxes;
        if (boxes.isEmpty) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final onShortagePage = _currentIndex == 0;
        final boxIndex = onShortagePage
            ? 0
            : (_currentIndex - 1).clamp(0, boxes.length - 1);
        final currentBox = boxes[boxIndex];

        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => _dragDelta = 0,
              onHorizontalDragUpdate: (details) => _dragDelta += details.delta.dx,
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v.abs() > 50) {
                  v < 0 ? _goToNext() : _goToPrevious();
                } else if (_dragDelta.abs() > 40) {
                  _dragDelta < 0 ? _goToNext() : _goToPrevious();
                }
              },
              child: AppBar(
                backgroundColor: softSurface(
                  onShortagePage ? shortageSoft : Color(currentBox.color),
                  theme.brightness,
                ),
                foregroundColor: onSoftSurface(theme.brightness),
                title: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: Text(
                    onShortagePage
                        ? l10n.shortagePageTitle
                        : (currentBox.isBackup
                            ? l10n.backupBox
                            : currentBox.name),
                    key: ValueKey(onShortagePage ? 'shortage' : currentBox.id),
                  ),
                ),
                actions: [
                  if (onShortagePage) ...[
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 32, height: 32),
                      style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      tooltip: l10n.shareShortageTooltip,
                      icon: const Icon(Icons.share_outlined),
                      onPressed: _shareShortage,
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 32, height: 32),
                      style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      tooltip: l10n.settings,
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () =>
                          Navigator.pushNamed(context, '/settings'),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 32, height: 32),
                      style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      tooltip: l10n.about,
                      icon: const Icon(Icons.info_outline),
                      onPressed: () =>
                          Navigator.pushNamed(context, '/info'),
                    ),
                  ] else
                    PopupMenuButton<_BoxAction>(
                      tooltip: l10n.more,
                      icon: const Icon(Icons.more_horiz),
                      onSelected: (action) => _handleBoxAction(action, currentBox),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _BoxAction.newBox,
                          child: Text(l10n.newBox),
                        ),
                        if (!currentBox.isBackup) ...[
                          PopupMenuItem(
                            value: _BoxAction.rename,
                            child: Text(l10n.rename),
                          ),
                          PopupMenuItem(
                            value: _BoxAction.delete,
                            enabled: boxes.length > 1,
                            child: Text(l10n.delete),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  itemCount: boxes.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildShortagePage(storage);
                    }
                    final box = boxes[index - 1];
                    final medicines = _sortedForBox(
                        box.id, storage.medicinesForBox(box.id));

                    if (medicines.isEmpty) {
                      return const EmptyState();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: medicines.length,
                      itemBuilder: (context, i) {
                        final medicine = medicines[i];
                        return _CardEntrance(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: LongPressDraggable<Medicine>(
                              data: medicine,
                              onDragStarted: () =>
                                  setState(() => _draggingMedicine = true),
                              onDragEnd: (_) =>
                                  setState(() => _draggingMedicine = false),
                              onDraggableCanceled: (_, __) =>
                                  setState(() => _draggingMedicine = false),
                              feedback: _medicineDragFeedback(medicine, theme),
                              child: MedicineCard(
                                medicine: medicine,
                                onMovedToBox: _goToBox,
                                onQuickAdjust: _onQuickAdjust,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // 页面底部药箱指示：指示点（随系统底部导航栏显示/隐藏动态上移）
              Padding(
                padding: EdgeInsets.only(
                  bottom: 8 + MediaQuery.of(context).padding.bottom,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < boxes.length; i++)
                      _dot(!onShortagePage && i == boxIndex, theme),
                  ],
                ),
              ),
                ],
              ),
              if (_draggingMedicine) _buildBoxOverview(storage, theme),
            ],
          ),
          floatingActionButton: onShortagePage
              ? null
              : FloatingActionButton(
                  onPressed: () => _navigateToAdd(currentBox.id),
                  shape: const CircleBorder(),
                  tooltip: l10n.addMedicineTooltip,
                  child: const Icon(Icons.add),
                ),
        );
      },
    );
  }

  /// 生成短缺药品整页长截图并保存到相册，随后弹出分享提示
  Future<void> _shareShortage() async {
    final l10n = AppLocalizations.of(context);
    final boundary = _shortageKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null || !mounted) return;

    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null || !mounted) return;
    final bytes = byteData.buffer.asUint8List();

    try {
      await Gal.putImageBytes(bytes);
    } on GalException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saveToAlbumFailed)),
      );
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.savedToAlbum),
        content: Text(l10n.savedToAlbumMessage),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.gotIt),
          ),
        ],
      ),
    );
  }

  /// 短缺药品页：顶部聚合星标药品，其余按药箱分组显示
  Widget _buildShortagePage(StorageService storage) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cards = <Widget>[];

    // 星标卡片：聚合所有药箱的短缺星标药品（备用药箱不参与短缺统计）
    final starred = storage.medicines
        .where((m) =>
            m.needsAlert &&
            m.isStarred &&
            !storage.isBackupBox(m.boxId))
        .toList()
      ..sort((a, b) => a.remainingDays.compareTo(b.remainingDays));
    if (starred.isNotEmpty) {
      cards.add(_buildStarShortageCard(starred, theme));
    }

    for (final box in storage.boxes) {
      if (box.isBackup) continue;
      final shortage = storage
          .medicinesForBox(box.id)
          .where((m) => m.needsAlert && !m.isStarred)
          .toList()
        ..sort((a, b) => a.remainingDays.compareTo(b.remainingDays));
      if (shortage.isNotEmpty) {
        cards.add(_buildShortageCard(box, shortage, theme));
      }
    }

    if (cards.isEmpty) {
      return RepaintBoundary(
        key: _shortageKey,
        child: Container(
          color: theme.scaffoldBackgroundColor,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.noShortageMedicine,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 用 SingleChildScrollView + Column 渲染全部内容（非懒加载），
    // 使整页长截图能一次性捕获完整滚动区域。
    return SingleChildScrollView(
      child: RepaintBoundary(
        key: _shortageKey,
        child: Container(
          color: theme.scaffoldBackgroundColor,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards,
          ),
        ),
      ),
    );
  }

  /// 单个药箱的短缺药品卡片
  Widget _buildShortageCard(
      MedicineBox box, List<Medicine> medicines, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final titleColor = onSoftSurface(theme.brightness);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _goToBox(box.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行：用药箱颜色作为底色
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: softSurface(Color(box.color), theme.brightness),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 18, color: titleColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    box.isBackup ? l10n.backupBox : box.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  for (final m in medicines)
                    _buildShortageMedicineRow(m, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 星标短缺药品卡片：聚合展示所有药箱的星标药品
  Widget _buildStarShortageCard(
      List<Medicine> medicines, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final titleColor = onSoftSurface(theme.brightness);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: softSurface(starSoft, theme.brightness),
            child: Row(
              children: [
                const Icon(Icons.star, size: 18, color: starRed),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.starred,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final m in medicines) _buildShortageMedicineRow(m, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 单个短缺药品条目：名称 + 剩余存量 / 剩余天数
  Widget _buildShortageMedicineRow(Medicine m, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final form = formLabel(l10n, m.form);
    final days = m.remainingDays.floor();
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 4, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              m.name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${Medicine.formatStock(m.currentStock)} $form / '
            '${l10n.daysRemaining(days)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 药箱指示点（当前药箱高亮并拉长）
  Widget _dot(bool active, ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 16 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active
            ? theme.colorScheme.primary
            : theme.colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

enum _BoxAction { newBox, rename, delete }

/// 卡片入场动画：首次出现时淡入并轻微上移，仅播放一次
class _CardEntrance extends StatelessWidget {
  final Widget child;

  const _CardEntrance({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}
