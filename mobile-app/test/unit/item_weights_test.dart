import 'package:flutter_test/flutter_test.dart';
import 'package:trash_to_cash/main.dart';

void main() {
  group('اختبارات ItemWeights', () {
    test('حساب نقاط زجاجة صغيرة (glass_small) = 15', () {
      final points = ItemWeights.calculatePoints('glass_small', 1);
      expect(points, 15);
    });

    test('حساب وزن علبتين كبيرتين (cans_large) = 0.044 kg', () {
      final weight = ItemWeights.calculateWeightInKg('cans_large', 2);
      expect(weight, 0.044);
    });

    test('نقاط 3 بلاستيكات متوسطة = 11', () {
      final points = ItemWeights.calculatePoints('plastic_medium', 3);
      expect(points, 11);
    });

    test('الكمية بصفر تعطي نقاط = 0', () {
      expect(ItemWeights.calculatePoints('glass_small', 0), 0);
    });

    test('الكمية بصفر تعطي وزن = 0.0', () {
      expect(ItemWeights.calculateWeightInKg('cans_medium', 0), 0.0);
    });

    test('مفتاح غير موجود يعطي نقاط = 0', () {
      expect(ItemWeights.calculatePoints('unknown_key', 5), 0);
    });

    test('مفتاح غير موجود يعطي وزن = 0.0', () {
      expect(ItemWeights.calculateWeightInKg('unknown_key', 5), 0.0);
    });
  });
}