import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotifications();
    });
  }

  void _checkNotifications() {
    final storage = context.read<StorageService>();
    NotificationService().checkAndNotify(storage.medicines);
  }

  void _navigateToAdd() async {
    await Navigator.pushNamed(context, '/medicine/add');
    _checkNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('小药箱'),
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
      ),
      body: Consumer<StorageService>(
        builder: (context, storage, _) {
          if (!storage.initialized) {
            return const Center(child: CircularProgressIndicator());
          }

          if (storage.medicines.isEmpty) {
            return const EmptyState();
          }

          // 剩余时间不足的药品优先显示；同组内均按剩余时间递增排序
          final medicines = [...storage.medicines]
            ..sort((a, b) {
              if (a.needsAlert != b.needsAlert) return a.needsAlert ? -1 : 1;
              return a.remainingDays.compareTo(b.remainingDays);
            });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: medicines.length,
            itemBuilder: (context, index) {
              final medicine = medicines[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MedicineCard(medicine: medicine),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAdd,
        shape: const CircleBorder(),
        tooltip: '添加药品',
        child: const Icon(Icons.add),
      ),
    );
  }
}