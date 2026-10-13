import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../l10n/gen/app_localizations.dart';
import '../l10n/unit_labels.dart';
import '../models/medicine.dart';
import '../services/medicine_lookup_service.dart';
import '../services/storage_service.dart';
import 'scan_screen.dart';

/// 添加/编辑药品表单：按「药品 / 服用 / 库存」三组录入，支持扫码与联网查询
class AddEditMedicineScreen extends StatefulWidget {
  final String? medicineId;
  final String? boxId;

  const AddEditMedicineScreen({super.key, this.medicineId, this.boxId});

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

  /// 是否正在联网查询药品信息
  bool _isLookingUp = false;

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

  /// 扫描药盒条码/二维码，识别结果填入名称框并尝试联网查询
  Future<void> _scanMedicine() async {
    final l10n = AppLocalizations.of(context);
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (scanned == null || !mounted) return;
    final text = scanned.trim();
    if (text.isEmpty) return;

    // 纯数字：商品条码/追溯码，先按条码查名称
    if (RegExp(r'^[0-9]{6,}$').hasMatch(text)) {
      // 20 位药品追溯码：官方查询接口不开放，直接提示手动输入
      if (text.length == 20) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.traceCodeUnsupported)),
        );
        return;
      }
      setState(() => _isLookingUp = true);
      BarcodeInfo? info;
      try {
        info = await MedicineLookupService().lookupByBarcode(text);
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLookingUp = false);
        final msg = e.toString();
        final hint = msg.contains('未申请') || msg.contains('160')
            ? l10n.barcodeApiNotApplied
            : l10n.barcodeLookupFailed(msg);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hint)));
        return;
      }
      if (!mounted) return;
      if (info == null) {
        setState(() => _isLookingUp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.barcodeNotFound(text))),
        );
        return;
      }
      // 先填名称与条码规格（剂量/剂型），再查说明书补全周期/每次剂量
      _nameController.text = info.name;
      if (info.dosageStrength != null) {
        _dosageStrengthController.text = _trimNum(info.dosageStrength!);
      }
      if (info.dosageStrengthUnit != null &&
          _strengthUnits.contains(info.dosageStrengthUnit)) {
        _dosageStrengthUnit = info.dosageStrengthUnit!;
      }
      if (info.form != null && _forms.contains(info.form)) {
        _form = info.form!;
      }
      setState(() => _isLookingUp = false);
      await _lookupMedicine();
      return;
    }

    // 含文字：当作药品名称直接查说明书
    _nameController.text = text;
    await _lookupMedicine();
  }

  /// 联网查询药品规范信息并填入表单
  Future<void> _lookupMedicine() async {
    final l10n = AppLocalizations.of(context);
    final keyword = _nameController.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterMedicineNameFirst)),
      );
      return;
    }
    setState(() => _isLookingUp = true);
    try {
      final result = await MedicineLookupService().lookup(keyword);
      if (!mounted) return;
      setState(() => _applyLookupResult(result));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.lookupApplied(result.name))),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final hint = msg.contains('未查询到') || msg.contains('数据返回为空')
          ? l10n.lookupNameOnly
          : l10n.lookupFailed(msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hint)));
    } finally {
      if (mounted) setState(() => _isLookingUp = false);
    }
  }

  /// 将查询结果写入对应输入项
  void _applyLookupResult(DrugLookupResult r) {
    _nameController.text = r.name;
    if (r.dosageStrength != null) {
      _dosageStrengthController.text = _trimNum(r.dosageStrength!);
    }
    if (r.dosageStrengthUnit != null &&
        _strengthUnits.contains(r.dosageStrengthUnit)) {
      _dosageStrengthUnit = r.dosageStrengthUnit!;
    }
    if (r.form != null && _forms.contains(r.form)) {
      _form = r.form!;
    }
    if (r.periodUnit != null && _periodUnits.contains(r.periodUnit)) {
      if (r.periodUnit != _periodUnit) {
        _periodUnit = r.periodUnit!;
        _doseSlots = [];
        _nextRoundDates = [];
        _doseHour = null;
      }
    }
    if (r.periodValue != null && r.periodValue! > 0) {
      _periodValueController.text = r.periodValue.toString();
    }
    if (r.timesPerPeriod != null && r.timesPerPeriod! > 0) {
      _timesPerPeriodController.text = r.timesPerPeriod.toString();
    }
    if (r.dosagePerTime != null && r.dosagePerTime! > 0) {
      _dosagePerTimeController.text = _trimNum(r.dosagePerTime!);
    }
    _syncSlotsToCount();
  }

  String _trimNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
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
        boxId: widget.boxId ?? '',
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

  /// 分组标题：图标 + 文字，尺寸与卡片内其它字段一致
  Widget _sectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String Function(String)? labelFor,
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
              .map((e) => DropdownMenuItem(
                  value: e, child: Text(labelFor == null ? e : labelFor(e))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _formDropdown() {
    final l10n = AppLocalizations.of(context);
    return _buildDropdown(
      value: _form,
      items: _forms,
      labelFor: (e) => formLabel(l10n, e),
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
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.access_time, size: 20),
            Text(isDaily ? l10n.doseTime : l10n.nextRound),
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
              Text(l10n.timeLabel),
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? l10n.editMedicine : l10n.addMedicine),
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
                      _sectionHeader(l10n.medicineInfo, Icons.medication_outlined),
                      Row(
                        children: [
                          const Icon(Icons.medication_outlined, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _nameController,
                              decoration: _decoration(hintText: l10n.medicineName),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? l10n.medicineNameRequired
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _isLookingUp ? null : _lookupMedicine,
                            tooltip: l10n.lookupTooltip,
                            icon: _isLookingUp
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.search),
                          ),
                          IconButton(
                            onPressed: _isLookingUp ? null : _scanMedicine,
                            tooltip: l10n.scanTooltip,
                            icon: const Icon(Symbols.barcode_scanner),
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
                              decoration: _decoration(hintText: l10n.dosage),
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
                      _sectionHeader(l10n.scheduleSection, Icons.schedule),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 20),
                          const SizedBox(width: 8),
                          Text(l10n.every),
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
                            labelFor: (e) => periodUnitLabel(l10n, e),
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
                          Text(l10n.times),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.local_pharmacy, size: 20),
                          const SizedBox(width: 8),
                          Text(l10n.perDose),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _dosagePerTimeController,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: _decoration(hintText: l10n.dosage),
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
                      _sectionHeader(l10n.inventoryInfo, Icons.shelves),
                      Row(
                        children: [
                          const Icon(Icons.shelves, size: 20),
                          const SizedBox(width: 8),
                          Text(l10n.currentStock),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _stockController,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: _decoration(hintText: l10n.quantity),
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
                          Text(l10n.below),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _thresholdController,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: _decoration(hintText: l10n.quantity),
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                if (n == null || n <= 0) return ' ';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(l10n.dayReminder),
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
                label: Text(widget.isEditing ? l10n.save : l10n.add),
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