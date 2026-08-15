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

  /// 低频药品的下次服用日期
  DateTime? _nextDoseDate;

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
      _stockController.text = medicine.currentStock.toString();
      _thresholdController.text = medicine.alertThreshold.toString();
      _nextDoseDate = medicine.nextDoseDate;
    }
  }

  /// 当前表单填写的频次是否为低频（低于每天 1 次）
  bool get _isInfrequent {
    final periodVal = int.tryParse(_periodValueController.text) ?? 1;
    final times = int.tryParse(_timesPerPeriodController.text) ?? 1;
    return times < Medicine.periodToDays(_periodUnit, periodVal);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '请选择';
    return '${date.year}/${date.month}/${date.day}';
  }

  Future<void> _pickNextDoseDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDoseDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() => _nextDoseDate = picked);
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

    // 低频药品需要记录下次服用日期；未选择则默认明天
    final infrequent = times < Medicine.periodToDays(_periodUnit, periodVal);
    final nextDoseDate = infrequent
        ? (_nextDoseDate ?? DateTime(now.year, now.month, now.day + 1))
        : null;

    if (widget.isEditing) {
      final existing = storage.findById(widget.medicineId!)!;
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
        nextDoseDate: nextDoseDate,
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
        nextDoseDate: nextDoseDate,
        createdAt: now,
        updatedAt: now,
      );
      await storage.add(medicine);
    }

    if (mounted) Navigator.pop(context, true);
  }

  /// 统一的输入框装饰，保证所有输入框/选择框高度一致
  InputDecoration _decoration({String? hintText, bool compact = false}) {
    return InputDecoration(
      hintText: hintText,
      isDense: true,
      border: const OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 12,
        vertical: 12,
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _formDropdown() {
    return _buildDropdown(
      value: _form,
      items: _forms,
      onChanged: (v) {
        if (v != null) setState(() => _form = v);
      },
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
                              decoration: _decoration(hintText: '药品名称'),
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
                              decoration: _decoration(hintText: '剂量'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildDropdown(
                            value: _dosageStrengthUnit,
                            items: _strengthUnits,
                            onChanged: (v) {
                              if (v != null) setState(() => _dosageStrengthUnit = v);
                            },
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
                              decoration: _decoration(compact: true),
                              onChanged: (_) => setState(() {}),
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
                            onChanged: (v) {
                              if (v != null) setState(() => _periodUnit = v);
                            },
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 48,
                            child: TextFormField(
                              controller: _timesPerPeriodController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: _decoration(compact: true),
                              onChanged: (_) => setState(() {}),
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
                      // 低频药品：下次服用日期输入行
                      if (_isInfrequent) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _pickNextDoseDate,
                          child: Row(
                            children: [
                              const Icon(Icons.event, size: 20),
                              const SizedBox(width: 8),
                              const Text('下次服用'),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(_formatDate(_nextDoseDate)),
                                      const Spacer(),
                                      Icon(Icons.arrow_drop_down,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                              decoration: _decoration(hintText: '剂量'),
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
                              decoration: _decoration(hintText: '数量'),
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
                              decoration: _decoration(hintText: '数量'),
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                if (n == null || n <= 0) return ' ';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('天提醒'),
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