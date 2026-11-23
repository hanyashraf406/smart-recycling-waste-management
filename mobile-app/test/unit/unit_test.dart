import 'package:flutter_test/flutter_test.dart';
import 'package:trash_to_cash/main.dart'; // تأكد من صحة اسم الحزمة

void main() {
  group('اختبارات حساب النقاط والوزن في ItemWeights', () {
    // الاختبارات الأصلية (الثلاثة)
    test('نقاط زجاجة صغيرة (glass_small) = 15', () {
      final points = ItemWeights.calculatePoints('glass_small', 1);
      expect(points, 15);
    });

    test('وزن علبتين كبيرتين (cans_large) = 0.044 kg', () {
      final weight = ItemWeights.calculateWeightInKg('cans_large', 2);
      expect(weight, 0.044);
    });

    test('نقاط 3 بلاستيكات متوسطة = 11', () {
      final points = ItemWeights.calculatePoints('plastic_medium', 3);
      expect(points, 11);
    });

    // ✅ الاختبارات الجديدة (حالات الصفر والمفاتيح الخاطئة)
    test('الكمية بصفر تعطي نقاط = 0', () {
      expect(ItemWeights.calculatePoints('glass_small', 0), 0);
      expect(ItemWeights.calculatePoints('cans_medium', 0), 0);
      expect(ItemWeights.calculatePoints('plastic_large', 0), 0);
    });

    test('الكمية بصفر تعطي وزن = 0.0', () {
      expect(ItemWeights.calculateWeightInKg('glass_small', 0), 0.0);
      expect(ItemWeights.calculateWeightInKg('cans_medium', 0), 0.0);
      expect(ItemWeights.calculateWeightInKg('plastic_large', 0), 0.0);
    });

    test('مفتاح غير موجود (unknown_key) يعطي نقاط = 0', () {
      expect(ItemWeights.calculatePoints('unknown_key', 5), 0);
    });

    test('مفتاح غير موجود (unknown_key) يعطي وزن = 0.0', () {
      expect(ItemWeights.calculateWeightInKg('unknown_key', 5), 0.0);
    });
  });
}