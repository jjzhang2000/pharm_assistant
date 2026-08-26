import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/medicine.dart';
import '../models/medicine_box.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/medicine_card.dart';
import '../widgets/empty_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  double _dragDelta = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotifications();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 检查并发送库存不足通知
  void _checkNotifications() {
    final storage = context.read<StorageService>();
    NotificationService().checkAndNotify(storage.medicines);
  }

  /// 新建药箱并切换到新药箱页
  Future<void> _addBox() async {
    final name = await _showAddBoxDialog();
    if (name == null) return;
    if (!mounted) return;

    final storage = context.read<StorageService>();
    await storage.addBox(name);

    if (!mounted) return;
    final newIndex = storage.boxes.length - 1;
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
        final index = _currentIndex;
        await storage.deleteBox(box.id);
        if (!mounted) return;
        final newCount = storage.boxes.length;
        final newIndex = index.clamp(0, newCount - 1);
        setState(() => _currentIndex = newIndex);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(newIndex);
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
    _checkNotifications();
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

  /// 剩余时间不足的药品优先显示；同组内均按剩余时间递增排序
  List<Medicine> _sorted(List<Medicine> medicines) {
    final list = [...medicines]
      ..sort((a, b) {
        if (a.needsAlert != b.needsAlert) return a.needsAlert ? -1 : 1;
        return a.remainingDays.compareTo(b.remainingDays);
      });
    return list;
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

        final safeIndex = _currentIndex.clamp(0, boxes.length - 1);
        final currentBox = boxes[safeIndex];

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
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                title: Text(currentBox.name),
                actions: [
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
          body: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  itemCount: boxes.length,
                  itemBuilder: (context, index) {
                    final box = boxes[index];
                    final medicines =
                        _sorted(storage.medicinesForBox(box.id));

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
                          child: MedicineCard(medicine: medicine),
                        );
                      },
                    );
                  },
                ),
              ),
              // 页面底部药箱指示点
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < boxes.length; i++)
                      _dot(i == safeIndex, theme),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _navigateToAdd(currentBox.id),
            shape: const CircleBorder(),
            tooltip: '添加药品',
            child: const Icon(Icons.add),
          ),
        );
      },
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
