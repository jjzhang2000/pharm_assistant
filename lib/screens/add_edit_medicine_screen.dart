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

  /// 服用时间安排：天-小时(0-23)。周/月用 [_nextRoundDates]
  List<int> _doseSlots = [];

  /// 周/月安排：下一轮各次服用的日期
  List<DateTime> _nextRoundDates = [];

  /// 周/月安排中各服用日的小时数（0-23）
  int? _doseHour;

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

    _syncSlotsToCount();

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
      if (medicine.periodUnit == '天') {
        _doseSlots = List<int>.from(medicine.doseSlots);
        _doseHour = null;
      } else {
        _nextRoundDates = List<DateTime>.from(medicine.nextRoundDates);
        _doseHour = medicine.doseHour;
      }
    }
    // 保证时间安排槽位数量与服用次数一致
    _syncSlotsToCount();
  }

  /// 天安排默认服用小时（均匀分布在 08:00 附近）
  int _defaultSlot(int index, int times) {
    if (index == 0) return 8;
    return (8 + (24 * index / times).round()) % 24;
  }

  /// 周/月安排：下一轮第 index 次的默认日期（在本周期内均匀分布）
  DateTime _nextRoundDefault(int index, int times) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final periodDays = Medicine.periodToDays(
        _periodUnit, int.tryParse(_periodValueController.text) ?? 1);
    if (times <= 1 || periodDays <= 1) {
      return today.add(const Duration(days: 1));
    }
    final span = periodDays - 1;
    final off = (1 + span * index / times).round().clamp(1, span);
    return today.add(Duration(days: off));
  }

  /// 让时间安排的数量与服用次数一致（天→小时槽位；周/月→下一轮日期），不足补默认、超出截断
  void _syncSlotsToCount() {
    final times = int.tryParse(_timesPerPeriodController.text) ?? 1;
    if (times < 1) return;
    if (_periodUnit == '天') {
      while (_doseSlots.length < times) {
        _doseSlots.add(_defaultSlot(_doseSlots.length, times));
      }
      if (_doseSlots.length > times) {
        _doseSlots = _doseSlots.sublist(0, times);
      }
    } else {
      while (_nextRoundDates.length < times) {
        _nextRoundDates.add(_nextRoundDefault(_nextRoundDates.length, times));
      }
      if (_nextRoundDates.length > times) {
        _nextRoundDates = _nextRoundDates.sublist(0, times);
      }
      // 周/月安排缺省服用小时设为 08:00
      _doseHour ??= 8;
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

    // 服用时间安排：同步到当前服用次数，优先以具体时刻/日期精确扣减
    _syncSlotsToCount();
    final isDaily = _periodUnit == '天';
    final slots = isDaily ? List<int>.from(_doseSlots) : const <int>[];
    final rounds = isDaily
        ? const <DateTime>[]
        : _nextRoundDates
            .map((d) => DateTime(d.year, d.month, d.day))
            .toList();
    final hour = isDaily ? null : _doseHour;

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
        // 有服用安排后由 schedule 驱动扣减，清空旧的“下次服用日期”
        nextDoseDate: null,
        doseSlots: slots,
        doseHour: hour,
        nextRoundDates: rounds,
        lastStockUpdate: now,
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
        doseSlots: slots,
        doseHour: hour,
        nextRoundDates: rounds,
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
        horizontal: compact ? 4 : 8,
        vertical: 4,
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
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

  /// 天安排的时间槽位（值, 标签）
  (List<int>, List<String>) get _slotOptions {
    return (
      List<int>.generate(24, (i) => i),
      List<String>.generate(24, (i) => '${i.toString().padLeft(2, '0')}:00'),
    );
  }

  /// 把小时槽位值限制在 0-23，避免旧数据越界导致 DropdownButton 抛错
  int _clampSlot(int v) => v.clamp(0, 23);

  Widget _slotPicker(int index, int value) {
    final (values, labels) = _slotOptions;
    final normal = _clampSlot(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: normal,
          isDense: true,
          items: [
            for (var i = 0; i < values.length; i++)
              DropdownMenuItem(value: values[i], child: Text(labels[i])),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _doseSlots[index] = v);
          },
        ),
      ),
    );
  }

  /// 周/月安排的日期选择框：点击弹出日历，显示所选日期
  Widget _dateBox(int index, DateTime date) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        );
        if (picked != null) {
          setState(() => _nextRoundDates[index] = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text('${date.month}/${date.day}'),
          ],
        ),
      ),
    );
  }

  Widget _doseTimePicker() {
    final hour = _doseHour ?? 8;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: hour,
          isDense: true,
          items: [
            for (var h = 0; h < 24; h++)
              DropdownMenuItem(
                  value: h,
                  child:
                      Text('${h.toString().padLeft(2, '0')}:00')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _doseHour = v);
          },
        ),
      ),
    );
  }

  /// 第三行：服用时间。每天→n个时间框；每周/月→n个下轮日期框 + 时间选择框，统一在一行
  Widget _buildTimeSchedule() {
    final times = int.tryParse(_timesPerPeriodController.text) ?? 1;
    final isDaily = _periodUnit == '天';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.access_time, size: 20),
            Text(isDaily ? '服用时间' : '下轮'),
            if (isDaily)
              for (var i = 0; i < times; i++)
                _slotPicker(i,
                    i < _doseSlots.length ? _doseSlots[i] : _defaultSlot(i, times))
            else ...[
              for (var i = 0; i < times; i++)
                _dateBox(
                    i,
                    i < _nextRoundDates.length
                        ? _nextRoundDates[i]
                        : DateTime.now()),
              const Text('时间'),
              _doseTimePicker(),
            ],
          ],
        ),
      ],
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                              if (v != null) {
                                setState(() {
                                  _periodUnit = v;
                                  // 切换单位后重置时间安排为默认
                                  _doseSlots = [];
                                  _nextRoundDates = [];
                                  _doseHour = null;
                                  _syncSlotsToCount();
                                });
                              }
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
                              onChanged: (_) => setState(_syncSlotsToCount),
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
                      const SizedBox(height: 12),
                      _buildTimeSchedule(),
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