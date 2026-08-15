class Medicine {
  static const _sentinel = Object();

  final String id;
  final String name;
  final double dosageStrength;
  final String dosageStrengthUnit;
  final String form;
  final int periodValue;
  final String periodUnit;
  final int timesPerPeriod;
  final double dosagePerTime;
  final double currentStock;
  final double alertThreshold;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastStockUpdate;
  /// 低频药品（频次低于每天1次）的下一次服用日期
  final DateTime? nextDoseDate;
  final String? notes;

  Medicine({
    required this.id,
    required this.name,
    required this.dosageStrength,
    required this.dosageStrengthUnit,
    required this.form,
    required this.periodValue,
    required this.periodUnit,
    required this.timesPerPeriod,
    required this.dosagePerTime,
    required this.currentStock,
    required this.alertThreshold,
    required this.createdAt,
    required this.updatedAt,
    this.lastStockUpdate,
    this.nextDoseDate,
    this.notes,
  });

  /// 周期换算天数
  static int periodToDays(String unit, int value) {
    switch (unit) {
      case '天':
        return value;
      case '周':
        return value * 7;
      case '月':
        return value * 30;
      default:
        return value;
    }
  }

  /// 每日消耗量（形态单位）
  double get dailyConsumption {
    final days = periodToDays(periodUnit, periodValue);
    return days > 0 ? dosagePerTime * timesPerPeriod / days : 0;
  }

  /// 是否为低频药品（服用频次低于每天 1 次，如每 2 天 1 次、每周 1 次）
  bool get isInfrequent =>
      timesPerPeriod < periodToDays(periodUnit, periodValue);

  /// 两次服用之间的间隔天数（如每 2 天 1 次 → 2，每周 1 次 → 7）
  int get doseIntervalDays {
    final days = periodToDays(periodUnit, periodValue);
    final interval = days ~/ timesPerPeriod;
    return interval < 1 ? 1 : interval;
  }

  /// 服用一次后，下一次服用日期
  DateTime nextDoseDateAfterDose(DateTime doseDate) {
    return DateTime(
        doseDate.year, doseDate.month, doseDate.day + doseIntervalDays);
  }

  /// 根据时间自动扣减后的库存（以午夜为界，仅当累计消耗达到一次服用量时才扣减）
  double get adjustedStock {
    if (dailyConsumption <= 0) return currentStock;
    final now = DateTime.now();

    // 低频药品：根据下次服用日期计算已过期的服用次数
    if (isInfrequent && nextDoseDate != null) {
      final doseDay = DateTime(
          nextDoseDate!.year, nextDoseDate!.month, nextDoseDate!.day);
      final today = DateTime(now.year, now.month, now.day);
      if (doseDay.isAfter(today)) return currentStock;
      // 已过期的完整服用次数（含今天）
      final dosesDue =
          today.difference(doseDay).inDays ~/ doseIntervalDays + 1;
      final deducted = dosesDue * dosagePerTime;
      return (currentStock - deducted).clamp(0, double.infinity);
    }

    final refTime = lastStockUpdate ?? updatedAt;
    // 下次计数的起始午夜（上次扣减已覆盖到 refTime 当天，从下一天午夜开始算）
    final refDay = DateTime(refTime.year, refTime.month, refTime.day + 1);
    // 今天的下一个午夜
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    // 整日数
    final elapsedDays = nextMidnight.difference(refDay).inDays;
    if (elapsedDays <= 0) return currentStock;
    final deducted = dailyConsumption * elapsedDays;
    // 累计消耗未达到一次服用量，不扣减（使用 epsilon 避免浮点精度问题）
    if (deducted < dosagePerTime - 1e-9) return currentStock;
    return (currentStock - deducted).clamp(0, double.infinity);
  }

  /// 自动扣减后，低频药品的下一次服用日期
  DateTime? get adjustedNextDoseDate {
    if (!isInfrequent || nextDoseDate == null) return nextDoseDate;
    final now = DateTime.now();
    final doseDay =
        DateTime(nextDoseDate!.year, nextDoseDate!.month, nextDoseDate!.day);
    final today = DateTime(now.year, now.month, now.day);
    if (doseDay.isAfter(today)) return nextDoseDate;
    final dosesDue = today.difference(doseDay).inDays ~/ doseIntervalDays + 1;
    // 最后一次到期服用日 + 一个间隔 = 下次服用日
    final lastDueDay =
        doseDay.add(Duration(days: (dosesDue - 1) * doseIntervalDays));
    return nextDoseDateAfterDose(lastDueDay);
  }

  /// 剩余天数（基于自动扣减后的库存）
  double get remainingDays =>
      dailyConsumption > 0 ? adjustedStock / dailyConsumption : double.infinity;

  /// 是否需要提醒（剩余天数低于阈值天数）
  bool get needsAlert => remainingDays < alertThreshold;

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'] as String,
      name: json['name'] as String,
      dosageStrength: (json['dosageStrength'] as num?)?.toDouble() ?? 0,
      dosageStrengthUnit: json['dosageStrengthUnit'] as String? ?? '',
      form: json['form'] as String? ?? json['dosageUnit'] as String? ?? '片',
      periodValue: json['periodValue'] as int? ?? 1,
      periodUnit: json['periodUnit'] as String? ?? '天',
      timesPerPeriod: json['timesPerPeriod'] as int? ?? json['timesPerDay'] as int? ?? 1,
      dosagePerTime: (json['dosagePerTime'] as num).toDouble(),
      currentStock: (json['currentStock'] as num).toDouble(),
      alertThreshold: (json['alertThreshold'] as num?)?.toDouble() ??
          (json['alertThreshold'] as int?)?.toDouble() ??
          0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastStockUpdate: json['lastStockUpdate'] != null
          ? DateTime.parse(json['lastStockUpdate'] as String)
          : null,
      nextDoseDate: json['nextDoseDate'] != null
          ? DateTime.parse(json['nextDoseDate'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dosageStrength': dosageStrength,
      'dosageStrengthUnit': dosageStrengthUnit,
      'form': form,
      'periodValue': periodValue,
      'periodUnit': periodUnit,
      'timesPerPeriod': timesPerPeriod,
      'dosagePerTime': dosagePerTime,
      'currentStock': currentStock,
      'alertThreshold': alertThreshold,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (lastStockUpdate != null)
        'lastStockUpdate': lastStockUpdate!.toIso8601String(),
      if (nextDoseDate != null)
        'nextDoseDate': nextDoseDate!.toIso8601String(),
      if (notes != null) 'notes': notes,
    };
  }

  Medicine copyWith({
    String? id,
    String? name,
    double? dosageStrength,
    String? dosageStrengthUnit,
    String? form,
    int? periodValue,
    String? periodUnit,
    int? timesPerPeriod,
    double? dosagePerTime,
    double? currentStock,
    double? alertThreshold,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? lastStockUpdate = _sentinel,
    Object? nextDoseDate = _sentinel,
    String? notes,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      dosageStrength: dosageStrength ?? this.dosageStrength,
      dosageStrengthUnit: dosageStrengthUnit ?? this.dosageStrengthUnit,
      form: form ?? this.form,
      periodValue: periodValue ?? this.periodValue,
      periodUnit: periodUnit ?? this.periodUnit,
      timesPerPeriod: timesPerPeriod ?? this.timesPerPeriod,
      dosagePerTime: dosagePerTime ?? this.dosagePerTime,
      currentStock: currentStock ?? this.currentStock,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastStockUpdate: lastStockUpdate == _sentinel
          ? this.lastStockUpdate
          : lastStockUpdate as DateTime?,
      nextDoseDate: nextDoseDate == _sentinel
          ? this.nextDoseDate
          : nextDoseDate as DateTime?,
      notes: notes ?? this.notes,
    );
  }
}