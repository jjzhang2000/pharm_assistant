import 'package:flutter_test/flutter_test.dart';
import 'package:pharm_assistant/models/medicine.dart';

void main() {
  group('Medicine', () {
    final medicine = Medicine(
      id: '1',
      name: '阿莫西林',
      dosageStrength: 250,
      dosageStrengthUnit: 'mg',
      form: '片',
      periodValue: 1,
      periodUnit: '天',
      timesPerPeriod: 3,
      dosagePerTime: 1.0,
      currentStock: 20.0,
      alertThreshold: 3,
      lastStockUpdate: DateTime.now(),
      createdAt: DateTime(2026, 8, 12),
      updatedAt: DateTime(2026, 8, 12),
    );

    test('dailyConsumption should be dosagePerTime * timesPerPeriod / periodToDays', () {
      expect(medicine.dailyConsumption, 3.0);
    });

    test('remainingDays should be adjustedStock / dailyConsumption', () {
      // lastStockUpdate 是今天，refDay = 明天，elapsedDays = 0 → adjustedStock = 20
      expect(medicine.remainingDays, closeTo(20.0 / 3.0, 0.01));
    });

    test('needsAlert should be false when remaining days above threshold', () {
      // remainingDays = 20/3 ≈ 6.7 天, threshold = 3 天
      expect(medicine.needsAlert, false);
    });

    test('needsAlert should be true when remaining days below threshold', () {
      final lowStock = medicine.copyWith(currentStock: 2.0);
      // remainingDays = 2/3 ≈ 0.67 天 < 3 天
      expect(lowStock.needsAlert, true);
    });

    test('adjustedStock should not deduct when lastStockUpdate is today', () {
      final today = medicine.copyWith(
        currentStock: 20.0,
        lastStockUpdate: DateTime.now(),
      );
      // refDay = 明天 00:00，nextMidnight = 明天 00:00 → 0 天
      expect(today.adjustedStock, 20.0);
    });

    test('adjustedStock should deduct 1 day when lastStockUpdate was yesterday', () {
      final yesterday = medicine.copyWith(
        currentStock: 20.0,
        lastStockUpdate: DateTime.now().subtract(const Duration(days: 1)),
      );
      // refDay = 今天 00:00，nextMidnight = 明天 00:00 → 1 天 → 扣 3
      expect(yesterday.adjustedStock, 17.0);
    });

    test('adjustedStock should not go below 0', () {
      final longAgo = medicine.copyWith(
        currentStock: 5.0,
        lastStockUpdate: DateTime.now().subtract(const Duration(days: 10)),
      );
      expect(longAgo.adjustedStock, 0.0);
    });

    test('adjustedStock should use updatedAt when lastStockUpdate is null', () {
      final noLastUpdate = medicine.copyWith(
        currentStock: 20.0,
        lastStockUpdate: null,
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      // refDay = 今天 00:00，nextMidnight = 明天 00:00 → 1 天 → 扣 3
      expect(noLastUpdate.adjustedStock, 17.0);
    });

    test('toJson and fromJson should be reversible', () {
      final json = medicine.toJson();
      final restored = Medicine.fromJson(json);
      expect(restored.id, medicine.id);
      expect(restored.name, medicine.name);
      expect(restored.dosagePerTime, medicine.dosagePerTime);
      expect(restored.timesPerPeriod, medicine.timesPerPeriod);
      expect(restored.currentStock, medicine.currentStock);
      expect(restored.alertThreshold, medicine.alertThreshold);
    });

    test('toJson and fromJson should handle lastStockUpdate', () {
      final withUpdate = medicine.copyWith(
        lastStockUpdate: DateTime(2026, 8, 13, 10, 0),
      );
      final json = withUpdate.toJson();
      final restored = Medicine.fromJson(json);
      expect(restored.lastStockUpdate, DateTime(2026, 8, 13, 10, 0));
    });

    test('remainingDays should be infinity when dailyConsumption is 0', () {
      final noDosage = medicine.copyWith(timesPerPeriod: 0);
      expect(noDosage.remainingDays, double.infinity);
    });

    test('long-cycle medicine should not deduct before one dose is reached', () {
      // 每2周1次，每次1片 → dailyConsumption = 1/14 ≈ 0.0714
      final weekly = Medicine(
        id: '2',
        name: '维生素D',
        dosageStrength: 400,
        dosageStrengthUnit: 'IU',
        form: '粒',
        periodValue: 2,
        periodUnit: '周',
        timesPerPeriod: 1,
        dosagePerTime: 1.0,
        currentStock: 10.0,
        alertThreshold: 2,
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
        lastStockUpdate: DateTime.now().subtract(const Duration(days: 7)),
      );
      // 7天 × 0.0714 = 0.5 < 1.0 → 不扣减
      expect(weekly.adjustedStock, 10.0);
    });

    test('long-cycle medicine should deduct after one full dose is reached', () {
      final biweekly = Medicine(
        id: '3',
        name: '维生素D',
        dosageStrength: 400,
        dosageStrengthUnit: 'IU',
        form: '粒',
        periodValue: 2,
        periodUnit: '周',
        timesPerPeriod: 1,
        dosagePerTime: 1.0,
        currentStock: 10.0,
        alertThreshold: 2,
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
        lastStockUpdate: DateTime.now().subtract(const Duration(days: 15)),
      );
      // 15天 × (1/14) ≈ 1.07 ≥ 1.0 → 扣减
      expect(biweekly.adjustedStock, closeTo(10.0 - 15.0 / 14.0, 0.1));
    });

    group('nextDoseDate (低频药品)', () {
      Medicine makeInfrequent({
        required DateTime nextDoseDate,
        double currentStock = 10.0,
        double dosagePerTime = 1.0,
        int periodValue = 2,
        String periodUnit = '天',
        int timesPerPeriod = 1,
      }) {
        return Medicine(
          id: '10',
          name: '低频药',
          dosageStrength: 10,
          dosageStrengthUnit: 'mg',
          form: '片',
          periodValue: periodValue,
          periodUnit: periodUnit,
          timesPerPeriod: timesPerPeriod,
          dosagePerTime: dosagePerTime,
          currentStock: currentStock,
          alertThreshold: 2,
          nextDoseDate: nextDoseDate,
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        );
      }

      test('isInfrequent should be true when frequency < 1/day', () {
        final m = makeInfrequent(nextDoseDate: DateTime.now());
        expect(m.isInfrequent, true);
        // 每天 3 次不是低频
        expect(medicine.isInfrequent, false);
      });

      test('should not deduct when next dose date is in the future', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final m = makeInfrequent(nextDoseDate: tomorrow);
        expect(m.adjustedStock, 10.0);
      });

      test('should deduct 1 dose when next dose date is today', () {
        final today = DateTime.now();
        final m = makeInfrequent(nextDoseDate: today);
        expect(m.adjustedStock, 9.0);
      });

      test('should deduct multiple doses for overdue interval medicine', () {
        // 每 2 天 1 次，下次服用日期是 5 天前 → 到期服用 3 次（第0、2、4天）
        final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
        final m = makeInfrequent(nextDoseDate: fiveDaysAgo);
        expect(m.adjustedStock, 7.0);
      });

      test('adjustedNextDoseDate should advance past today', () {
        final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
        final m = makeInfrequent(nextDoseDate: fiveDaysAgo);
        final next = m.adjustedNextDoseDate!;
        final today = DateTime.now();
        expect(next.isAfter(DateTime(today.year, today.month, today.day)), true);
      });

      test('weekly medicine should deduct based on 7-day interval', () {
        // 每周 1 次，下次服用日期是 15 天前 → 到期 3 次（第0、7、14天）
        final fifteenDaysAgo =
            DateTime.now().subtract(const Duration(days: 15));
        final m = makeInfrequent(
          nextDoseDate: fifteenDaysAgo,
          periodValue: 1,
          periodUnit: '周',
        );
        expect(m.adjustedStock, 7.0);
      });

      test('toJson and fromJson should handle nextDoseDate', () {
        final m = makeInfrequent(nextDoseDate: DateTime(2026, 9, 1));
        final restored = Medicine.fromJson(m.toJson());
        expect(restored.nextDoseDate, DateTime(2026, 9, 1));
      });
    });
  });
}