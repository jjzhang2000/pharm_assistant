import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/medicine.dart';
import '../services/storage_service.dart';

class AddEditMedicineScreen extends StatefulWidget {
  final String? medicineId;

  const AddEditMedicineScreen({super.key, this.medicineId});

  bool get isEditing => medicineId != null;

  @override
  State<AddEditMedicineScreen> createState() => _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends State<AddEditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _dosageStrengthController;
  late final TextEditingController _periodValueController;
  late final TextEditingController _timesPerPeriodController;
  late final TextEditingController _dosagePerTimeController;
  late final TextEditingController _stockController;
  late final TextEditingController _thresholdController;

  late String _dosageStrengthUnit;
  late String _form;
  late String _periodUnit;

  final List<String> _strengthUnits = ['mg', 'g', 'ml', 'IU', 'mcg'];
  final List<String> _forms = ['片', '粒', '胶囊', '包', '瓶', '支', '滴'];
  final List<String> _periodUnits = ['天', '周', '月'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _dosageStrengthController = TextEditingController();
    _periodValueController = TextEditingController(text: '1');
    _timesPerPeriodController = TextEditingController(text: '1');
    _dosagePerTimeController = TextEditingController(text: '1');
    _stockController = TextEditingController();
    _thresholdController = TextEditingController(text: '7');

    _dosageStrengthUnit = 'mg';
    _form = '片';
    _periodUnit = '天';

    if (widget.isEditing) {
      _loadMedicine();
    }
  }

  void _loadMedicine() {
    final storage = context.read<StorageService>();
    final medicine = storage.findById(widget.medicineId!);
    if (medicine != null) {
      _nameController.text = medicine.name;
      _dosageStrengthController.text =
          medicine.dosageStrength > 0 ? medicine.dosageStrength.toString() : '';
      _dosageStrengthUnit = medicine.dosageStrengthUnit.isNotEmpty
          ? medicine.dosageStrengthUnit
          : 'mg';
      _form = medicine.form;
      _periodValueController.text = medicine.periodValue.toString();
      _periodUnit = medicine.periodUnit;
      _timesPerPeriodController.text = medicine.timesPerPeriod.toString();
      _dosagePerTimeController.text = medicine.dosagePerTime.toString();
      _stockController.text = medicine.currentStock.toStringAsFixed(1);
      _thresholdController.text = medicine.alertThreshold.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageStrengthController.dispose();
    _periodValueController.dispose();
    _timesPerPeriodController.dispose();
    _dosagePerTimeController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final storage = context.read<StorageService>();
    final now = DateTime.now();

    final strength = double.tryParse(_dosageStrengthController.text) ?? 0;
    final periodVal = int.tryParse(_periodValueController.text) ?? 1;
    final times = int.tryParse(_timesPerPeriodController.text) ?? 1;
    final dosage = double.tryParse(_dosagePerTimeController.text) ?? 0;
    final stock = double.tryParse(_stockController.text) ?? 0;
    final threshold = double.tryParse(_thresholdController.text) ?? 7;

    if (widget.isEditing) {
      final existing = storage.findById(widget.medicineId!)!;
      final stockChanged = stock != existing.currentStock;
      final updated = existing.copyWith(
        name: _nameController.text.trim(),
        dosageStrength: strength,
        dosageStrengthUnit: _dosageStrengthUnit,
        form: _form,
        periodValue: periodVal,
        periodUnit: _periodUnit,
        timesPerPeriod: times,
        dosagePerTime: dosage,
        currentStock: stock,
        alertThreshold: threshold,
        lastStockUpdate: stockChanged ? now : existing.lastStockUpdate,
        updatedAt: now,
      );
      await storage.update(updated);
    } else {
      final medicine = Medicine(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        dosageStrength: strength,
        dosageStrengthUnit: _dosageStrengthUnit,
        form: _form,
        periodValue: periodVal,
        periodUnit: _periodUnit,
        timesPerPeriod: times,
        dosagePerTime: dosage,
        currentStock: stock,
        alertThreshold: threshold,
        lastStockUpdate: now,
        createdAt: now,
        updatedAt: now,
      );
      await storage.add(medicine);
    }

    if (mounted) Navigator.pop(context, true);
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _formDropdown() {
    return _buildDropdown(
      value: _form,
      items: _forms,
      onChanged: (v) => setState(() => _form = v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑药品' : '添加药品'),
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 第一组：药品
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.medication_outlined, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                hintText: '药品名称',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? '请输入药品名称'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.straighten, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _dosageStrengthController,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: const InputDecoration(
                                hintText: '剂量',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildDropdown(
                            value: _dosageStrengthUnit,
                            items: _strengthUnits,
                            onChanged: (v) =>
                                setState(() => _dosageStrengthUnit = v),
                          ),
                          const SizedBox(width: 8),
                          const Text('/'),
                          const SizedBox(width: 8),
                          _formDropdown(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 第二组：服用
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 20),
                          const SizedBox(width: 8),
                          const Text('每'),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 48,
                            child: TextFormField(
                              controller: _periodValueController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 10),
                              ),
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                if (n == null || n <= 0) return ' ';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildDropdown(
                            value: _periodUnit,
                            items: _periodUnits,
                            onChanged: (v) =>
                                setState(() => _periodUnit = v),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 48,
                            child: TextFormField(
                              controller: _timesPerPeriodController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 10),
                              ),
                              validator: (v) {
                                final n = int.tryParse(v ?? '');
                                if (n == null || n <= 0) return ' ';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('次'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.local_pharmacy, size: 20),
                          const SizedBox(width: 8),
                          const Text('每次'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _dosagePerTimeController,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: const InputDecoration(
                                hintText: '剂量',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                if (n == null || n <= 0) return ' ';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          _formDropdown(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 第三组：库存
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shelves, size: 20),
                          const SizedBox(width: 8),
                          const Text('当前存量'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _stockController,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: const InputDecoration(
                                hintText: '数量',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                if (n == null || n < 0) return ' ';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          _formDropdown(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.notifications_active_outlined, size: 20),
                          const SizedBox(width: 8),
                          const Text('低于'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _thresholdController,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: const InputDecoration(
                                hintText: '数量',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                if (n == null || n <= 0) return ' ';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          _formDropdown(),
                          const SizedBox(width: 8),
                          const Text('提醒'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _save,
                icon: Icon(widget.isEditing ? Icons.save : Icons.add),
                label: Text(widget.isEditing ? '保存' : '添加'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}