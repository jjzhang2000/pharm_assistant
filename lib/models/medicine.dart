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
  /// 低频药品（频次低于每天1次）的下一次服用日期（无服用时间安排时使用的回退字段）
  final DateTime? nextDoseDate;
  /// '天'：每次服用的小时数（0-23），每天固定这些时刻各服一次
  final List<int> doseSlots;
  /// 周/月安排中各服用日共用的小时数（0-23）；天安排不用此字段
  final int? doseHour;
  /// '周'/'月'：下一轮各次服用的日期（仅日期，服用时刻由 doseHour 决定）。
  /// 本轮服完后按周期自动推进到下一轮。天安排不用此字段。
  final List<DateTime> nextRoundDates;
  final String? notes;
  /// 所属药箱 ID（空串表示尚未归属，加载时归入默认药箱）
  final String boxId;

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
    this.doseSlots = const [],
    this.doseHour,
    this.nextRoundDates = const [],
    this.notes,
    this.boxId = '',
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

  /// 是否有具体的服用时间安排（天：doseSlots；周/月：nextRoundDates）
  bool get hasSchedule => doseSlots.isNotEmpty || nextRoundDates.isNotEmpty;

  /// 根据服用时间自动扣减后的库存（优先按具体服用安排精确扣减）
  double get adjustedStock {
    // 有服用时间安排：按实际已到点的服用次数精确扣减
    if (hasSchedule) return scheduledAdjustedStock;
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
    // 从基准时刻起按小时累计消耗，精确到小时而非整天，使扣减更精准
    final elapsedHours = now.difference(refTime).inHours;
    if (elapsedHours <= 0) return currentStock;
    final hourlyConsumption = dailyConsumption / 24;
    final deducted = hourlyConsumption * elapsedHours;
    // 累计消耗未达到一次服用量，不扣减（使用 epsilon 避免浮点精度问题）
    if (deducted < dosagePerTime - 1e-9) return currentStock;
    return (currentStock - deducted).clamp(0, double.infinity);
  }

  /// 统计在 [after, atOrBefore] 时间窗内应当服用的次数
  /// （after 严格早于、atOrBefore 小于等于才算一次）——天安排：每日各小时
  int _countScheduledDoses(DateTime after, DateTime atOrBefore) {
    if (doseSlots.isEmpty) return 0;
    final slots = doseSlots.toSet();
    int count = 0;
    var day = DateTime(after.year, after.month, after.day);
    final end = DateTime(atOrBefore.year, atOrBefore.month, atOrBefore.day);
    while (!day.isAfter(end)) {
      for (final h in slots) {
        final t = DateTime(day.year, day.month, day.day, h);
        if (t.isAfter(after) && !t.isAfter(atOrBefore)) count++;
      }
      day = day.add(const Duration(days: 1));
    }
    return count;
  }

  /// 将日期按周期推进 periods 轮（周按日推进、月按日推进并夹紧到月末）
  static DateTime _shiftRoundDate(DateTime date, String unit, int periodValue, int periods) {
    final d = DateTime(date.year, date.month, date.day);
    if (unit == '周') {
      return d.add(Duration(days: 7 * periodValue * periods));
    }
    final m0 = d.month - 1 + periodValue * periods; // 0 起月
    final y = d.year + m0 ~/ 12;
    final mm = m0 % 12; // 0 起月
    final lastDay = DateTime(y, mm + 2, 0).day;
    final day = d.day > lastDay ? lastDay : d.day;
    return DateTime(y, mm + 1, day);
  }

  /// 一次服用的具体时刻（由日期 + doseHour 得到）
  DateTime _roundInstance(DateTime date) =>
      DateTime(date.year, date.month, date.day, doseHour ?? 0);

  /// 统计在 [after, atOrBefore] 时间窗内的具体服用次数（周/月：按下一轮日期推进）
  int _countRoundDoses(DateTime after, DateTime atOrBefore) {
    final dates = nextRoundDates;
    if (dates.isEmpty) return 0;
    int count = 0;
    // 前向：R_0, R_1, ...
    for (var k = 0; k < 500; k++) {
      final round = dates.map((d) => _shiftRoundDate(d, periodUnit, periodValue, k)).toList();
      DateTime? earliest;
      for (final d in round) {
        final t = _roundInstance(d);
        if (earliest == null || t.isBefore(earliest)) earliest = t;
      }
      if (earliest!.isAfter(atOrBefore)) break; // 整轮都在窗口之后
      for (final d in round) {
        final t = _roundInstance(d);
        if (t.isAfter(after) && !t.isAfter(atOrBefore)) count++;
      }
    }
    // 后向：R_{-1}, R_{-2}, ...
    for (var k = 1; k < 500; k++) {
      final round = dates.map((d) => _shiftRoundDate(d, periodUnit, periodValue, -k)).toList();
      DateTime? latest;
      for (final d in round) {
        final t = _roundInstance(d);
        if (latest == null || t.isAfter(latest)) latest = t;
      }
      if (!latest!.isAfter(after)) break; // 整轮都在窗口之前（含 after）
      for (final d in round) {
        final t = _roundInstance(d);
        if (t.isAfter(after) && !t.isAfter(atOrBefore)) count++;
      }
    }
    return count;
  }

  /// 根据服用时间安排精确扣减后的库存
  double get scheduledAdjustedStock {
    if (dosagePerTime <= 0) return currentStock;
    if (periodUnit == '天') {
      if (doseSlots.isEmpty) return currentStock;
      final refTime = lastStockUpdate ?? updatedAt;
      final count = _countScheduledDoses(refTime, DateTime.now());
      return (currentStock - count * dosagePerTime).clamp(0, double.infinity);
    }
    if (nextRoundDates.isEmpty) return currentStock;
    final refTime = lastStockUpdate ?? updatedAt;
    final count = _countRoundDoses(refTime, DateTime.now());
    return (currentStock - count * dosagePerTime).clamp(0, double.infinity);
  }

  /// 有服用时间安排时，未来的下一次服用时刻；无安排返回 null
  DateTime? get scheduledNextDose {
    final now = DateTime.now();
    if (periodUnit == '天') {
      if (doseSlots.isEmpty) return null;
      final slots = doseSlots.toSet();
      var day = DateTime(now.year, now.month, now.day);
      for (int i = 0; i < 400; i++) {
        for (final h in (slots.toList()..sort())) {
          final t = DateTime(day.year, day.month, day.day, h);
          if (t.isAfter(now)) return t;
        }
        day = day.add(const Duration(days: 1));
      }
      return null;
    }
    // 周/月：沿下一轮日期往前推进找第一个未来时刻
    if (nextRoundDates.isEmpty) return null;
    for (var k = 0; k < 500; k++) {
      final round = nextRoundDates.map((d) => _shiftRoundDate(d, periodUnit, periodValue, k)).toList();
      DateTime? best;
      for (final d in round) {
        final t = _roundInstance(d);
        if (t.isAfter(now) && (best == null || t.isBefore(best))) best = t;
      }
      if (best != null) return best;
    }
    return null;
  }

  /// 根据服用时间安排计算下一次服用日期
  DateTime? get scheduledNextDoseDate {
    if (!hasSchedule) return null;
    final next = scheduledNextDose;
    if (next == null) return null;
    return DateTime(next.year, next.month, next.day);
  }

  /// 扣减后推进到下一轮次：返回第一个仍含未来服用的轮次日期（仅日期）
  List<DateTime>? get advancedRoundDates {
    if (nextRoundDates.isEmpty) return null;
    final now = DateTime.now();
    for (var k = 0; k < 500; k++) {
      final round = nextRoundDates.map((d) => _shiftRoundDate(d, periodUnit, periodValue, k)).toList();
      var hasFuture = false;
      for (final d in round) {
        if (_roundInstance(d).isAfter(now)) { hasFuture = true; break; }
      }
      if (hasFuture) {
        return round.map((d) => DateTime(d.year, d.month, d.day)).toList();
      }
    }
    return null;
  }

  /// 自动扣减后，低频药品（或有服用安排）的下一次服用日期
  DateTime? get adjustedNextDoseDate {
    // 有服用时间安排时，直接由安排的未来下一次服用计算
    if (hasSchedule) return scheduledNextDoseDate;
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
  double get remainingDays {
    if (dailyConsumption <= 0) return double.infinity;
    // 长周期药品（频次低于每天 1 次）：按离散剂量计算，避免把当前已
    // 部分过去的服药周期再按一个完整周期计入剩余天数。
    if (isInfrequent) {
      final next = adjustedNextDoseDate;
      if (next != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final nextDay = DateTime(next.year, next.month, next.day);
        final dosesRemaining = adjustedStock / dosagePerTime;
        if (dosesRemaining <= 0) return 0;
        final daysUntilNext = nextDay.difference(today).inDays;
        final days = daysUntilNext + (dosesRemaining - 1) * doseIntervalDays;
        return days.clamp(0, double.infinity).toDouble();
      }
    }
    // 有具体服药时刻（每天固定时段）的短周期药品：剩余天数 = 剩余库存 / 每日消耗，
    // 与无安排时的连续均摊口径一致。不要锚定到「距下次服药的小段时间」，
    // 否则会把那不足一天的一截从整天数里扣掉，导致整片/整剂场景少算一天。
    return adjustedStock / dailyConsumption;
  }

  /// 是否需要提醒（剩余天数低于阈值天数）
  bool get needsAlert => remainingDays < alertThreshold;

  /// 旧数据迁移：周/月旧字段 doseSlots 存的是星期/日期特征，
  /// 缺 nextRoundDates 时据此补一轮默认日期（从今天起向未来取 count 个命中日）
  static List<DateTime> _legacyRoundFromSlots(
      String unit, List<int> slots, int count) {
    if (slots.isEmpty || count <= 0) return const [];
    final now = DateTime.now();
    final set = slots.toSet();
    final result = <DateTime>[];
    var d = DateTime(now.year, now.month, now.day);
    if (unit == '周') {
      while (result.length < count) {
        if (set.contains(d.weekday)) {
          result.add(DateTime(d.year, d.month, d.day));
        }
        d = d.add(const Duration(days: 1));
      }
    } else {
      for (var guard = 0; guard < 4000 && result.length < count; guard++) {
        if (set.contains(d.day) && !d.isBefore(now)) {
          result.add(DateTime(d.year, d.month, d.day));
        }
        d = d.add(const Duration(days: 1));
      }
    }
    return result;
  }

  factory Medicine.fromJson(Map<String, dynamic> json) {
    final unit = json['periodUnit'] as String? ?? '天';
    final parsedSlots =
        (json['doseSlots'] as List?)?.cast<int>() ?? const <int>[];
    final parsedRound = (json['nextRoundDates'] as List?)
            ?.map((e) => DateTime.parse(e as String))
            .toList() ??
        const <DateTime>[];
    // 天安排用 doseSlots(小时)；周/月用 nextRoundDates；缺省时从旧特征迁移
    return Medicine(
      id: json['id'] as String,
      name: json['name'] as String,
      dosageStrength: (json['dosageStrength'] as num?)?.toDouble() ?? 0,
      dosageStrengthUnit: json['dosageStrengthUnit'] as String? ?? '',
      form: json['form'] as String? ?? json['dosageUnit'] as String? ?? '片',
      periodValue: json['periodValue'] as int? ?? 1,
      periodUnit: unit,
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
      doseSlots: unit == '天' ? parsedSlots : const [],
      doseHour: (json['doseHour'] as num?)?.toInt(),
      nextRoundDates: (unit == '天' || parsedRound.isNotEmpty)
          ? parsedRound
          : _legacyRoundFromSlots(
              unit, parsedSlots,
              json['timesPerPeriod'] as int? ??
                  json['timesPerDay'] as int? ??
                  1),
      notes: json['notes'] as String?,
      boxId: json['boxId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'boxId': boxId,
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
      if (doseSlots.isNotEmpty) 'doseSlots': doseSlots,
      if (doseHour != null) 'doseHour': doseHour,
      if (nextRoundDates.isNotEmpty)
        'nextRoundDates': nextRoundDates
            .map((d) => DateTime(d.year, d.month, d.day).toIso8601String())
            .toList(),
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
    Object? doseSlots = _sentinel,
    Object? doseHour = _sentinel,
    Object? nextRoundDates = _sentinel,
    String? notes,
    String? boxId,
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
      doseSlots: doseSlots == _sentinel ? this.doseSlots : (doseSlots as List<int>),
      doseHour: doseHour == _sentinel ? this.doseHour : doseHour as int?,
      nextRoundDates: nextRoundDates == _sentinel
          ? this.nextRoundDates
          : ((nextRoundDates as List<DateTime>?) ?? const <DateTime>[]),
      notes: notes ?? this.notes,
      boxId: boxId ?? this.boxId,
    );
  }
}