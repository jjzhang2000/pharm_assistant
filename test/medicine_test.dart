import 'package:flutter_test/flutter_test.dart';
import 'package:pharm_assistant/models/medicine.dart';

void main() {
  group('Medicine', () {
    final medicine = Medicine(
      id: '1',
      name: '阿莫西林',
      dosagePerTime: 1.0,
      dosageUnit: '片',
      timesPerDay: 3,
      currentStock: 20.0,
      alertThreshold: 3,
      createdAt: DateTime(2026, 8, 12),
      updatedAt: DateTime(2026, 8, 12),
    );

    test('dailyConsumption should be dosagePerTime * timesPerDay', () {
      expect(medicine.dailyConsumption, 3.0);
    });

    test('remainingDays should be currentStock / dailyConsumption', () {
      expect(medicine.remainingDays, 20.0 / 3.0);
    });

    test('needsAlert should be true when remainingDays < alertThreshold', () {
      // 20/3 ≈ 6.67 days, threshold is 3, so should NOT alert
      expect(medicine.needsAlert, false);
    });

    test('needsAlert should be true when stock is low', () {
      final lowStock = medicine.copyWith(currentStock: 5.0);
      // 5/3 ≈ 1.67 days, threshold is 3, so SHOULD alert
      expect(lowStock.needsAlert, true);
    });

    test('toJson and fromJson should be reversible', () {
      final json = medicine.toJson();
      final restored = Medicine.fromJson(json);
      expect(restored.id, medicine.id);
      expect(restored.name, medicine.name);
      expect(restored.dosagePerTime, medicine.dosagePerTime);
      expect(restored.timesPerDay, medicine.timesPerDay);
      expect(restored.currentStock, medicine.currentStock);
      expect(restored.alertThreshold, medicine.alertThreshold);
    });

    test('remainingDays should be infinity when dailyConsumption is 0', () {
      final noDosage = medicine.copyWith(timesPerDay: 0);
      expect(noDosage.remainingDays, double.infinity);
    });
  });
}