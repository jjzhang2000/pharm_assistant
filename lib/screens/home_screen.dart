import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../models/medicine.dart';
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

  void _checkNotifications() {
    final storage = context.read<StorageService>();
    NotificationService().checkAndNotify(storage.medicines);
  }

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

  void _navigateToAdd(String boxId) async {
    await Navigator.pushNamed(context, '/medicine/add', arguments: boxId);
    _checkNotifications();
  }

  void _goToNext() {
    if (_pageController.hasClients) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

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
                  IconButton(
                    onPressed: _addBox,
                    tooltip: '新药箱',
                    icon: const Icon(Symbols.library_add),
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
