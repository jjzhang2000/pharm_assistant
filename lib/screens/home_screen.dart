import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:gal/gal.dart';
import 'package:provider/provider.dart';

import '../models/medicine.dart';
import '../models/medicine_box.dart';
import '../services/storage_service.dart';
import '../widgets/medicine_card.dart';
import '../widgets/empty_state.dart';

/// 首页：多药箱左右滑动切换 + 短缺药品负一页；药品卡片支持长按拖动移动
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(initialPage: 1);
  int _currentIndex = 1;
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

  /// 快速增减库存时回调：重置排序冻结窗口（3 秒）
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
    await storage.addBox(name);

    if (!mounted) return;
    final newIndex = storage.boxes.length;
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
    final controller = TextEditingController(text: currentName);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名药箱'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '请输入新的药箱名'),
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

  /// 弹出删除药箱确认框
  Future<bool> _confirmDeleteBox(MedicineBox box) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除药箱「${box.name}」吗？其中的药品将一并删除，此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('删除'),
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
        _pageController.jumpToPage(pageIndex);
      }
    });
  }

  /// 长按拖动时展示的全屏药箱概览（类似安卓桌面的各页面缩略视图）
  Widget _buildBoxOverview(StorageService storage, ThemeData theme) {
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
                    '拖动药品到目标药箱',
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
                                      box.name,
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
                                    '${storage.medicinesForBox(box.id).length} 种药品',
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
                  '新药箱',
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
    await storage.addBox(name);
    final newBoxId = storage.boxes.last.id;
    await storage.update(
        medicine.copyWith(boxId: newBoxId, updatedAt: DateTime.now()));
  }

  /// 生成不重名的药箱名：新药箱、新药箱2、新药箱3……
  String _uniqueBoxName(StorageService storage) {
    final existing = storage.boxes.map((b) => b.name).toSet();
    if (!existing.contains('新药箱')) return '新药箱';
    var i = 2;
    while (existing.contains('新药箱$i')) {
      i++;
    }
    return '新药箱$i';
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

  /// 剩余时间不足的药品优先显示；同组内均按剩余时间递增排序。
  /// 快速增减库存后的冻结期内，复用缓存的顺序，避免卡片位置突变导致误点。
  List<Medicine> _sortedForBox(String boxId, List<Medicine> medicines) {
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
        if (a.needsAlert != b.needsAlert) return a.needsAlert ? -1 : 1;
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
                backgroundColor: onShortagePage
                    ? const Color(0xFFE8B4B4)
                    : Color(currentBox.color),
                foregroundColor: theme.colorScheme.onSurface,
                title: Text(onShortagePage ? '短缺药品' : currentBox.name),
                actions: [
                  if (onShortagePage)
                    IconButton(
                      tooltip: '分享短缺药品',
                      icon: const Icon(Icons.share_outlined),
                      onPressed: _shareShortage,
                    )
                  else
                    PopupMenuButton<_BoxAction>(
                      tooltip: '更多',
                      icon: const Icon(Icons.more_horiz),
                      onSelected: (action) => _handleBoxAction(action, currentBox),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: _BoxAction.newBox,
                          child: Text('新药箱'),
                        ),
                        const PopupMenuItem(
                          value: _BoxAction.rename,
                          child: Text('重命名'),
                        ),
                        PopupMenuItem(
                          value: _BoxAction.delete,
                          enabled: boxes.length > 1,
                          child: const Text('删除'),
                        ),
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
                        return Padding(
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
                        );
                      },
                    );
                  },
                ),
              ),
              // 页面底部药箱指示点（随系统底部导航栏显示/隐藏动态上移）
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
                  tooltip: '添加药品',
                  child: const Icon(Icons.add),
                ),
        );
      },
    );
  }

  /// 生成短缺药品整页长截图并保存到相册，随后弹出分享提示
  Future<void> _shareShortage() async {
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
        const SnackBar(content: Text('保存到相册失败，请检查相册权限后重试')),
      );
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('已保存到相册'),
        content: const Text('短缺药品页面长截图已保存到手机相册，可在微信、QQ 等应用中分享给好友。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// 短缺药品页：顶部聚合星标药品，其余按药箱分组显示
  Widget _buildShortagePage(StorageService storage) {
    final theme = Theme.of(context);
    final cards = <Widget>[];

    // 星标卡片：聚合所有药箱的短缺星标药品
    final starred = storage.medicines
        .where((m) => m.needsAlert && m.isStarred)
        .toList()
      ..sort((a, b) => a.remainingDays.compareTo(b.remainingDays));
    if (starred.isNotEmpty) {
      cards.add(_buildStarShortageCard(starred, theme));
    }

    for (final box in storage.boxes) {
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
                '暂无短缺药品',
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
    final titleColor = theme.colorScheme.onSurface;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：用药箱颜色作为底色
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Color(box.color),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 18, color: titleColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    box.name,
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

  /// 星标短缺药品卡片：聚合展示所有药箱的星标药品
  Widget _buildStarShortageCard(
      List<Medicine> medicines, ThemeData theme) {
    final titleColor = theme.colorScheme.onSurface;
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
            color: const Color(0xFFF2C9C9),
            child: Row(
              children: [
                const Icon(Icons.star, size: 18, color: Color(0xFFE53935)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '星标',
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
            '${Medicine.formatStock(m.currentStock)} ${m.form} / '
            '${m.remainingDays.floor()} 天',
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
