class Medicine {
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

  /// 剩余天数
  double get remainingDays =>
      dailyConsumption > 0 ? currentStock / dailyConsumption : double.infinity;

  /// 是否需要提醒（库存低于阈值）
  bool get needsAlert => currentStock < alertThreshold;

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
      'notes': notes,
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
      notes: notes ?? this.notes,
    );
  }
}