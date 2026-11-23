import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Material & Points Tests', () {
    
    // أوزان المواد من الكود الأصلي
    final Map<String, int> weights = {
      'plastic_small': 20,
      'plastic_medium': 35,
      'plastic_large': 50,
      'cans_small': 15,
      'cans_medium': 18,
      'cans_large': 22,
      'glass_small': 150,
      'glass_medium': 200,
      'glass_large': 300,
    };

    int calculatePoints(String itemKey, int count) {
      final weight = weights[itemKey] ?? 0;
      final totalGrams = weight * count;
      return ((totalGrams / 100) * 10).round();
    }

    double calculateWeightKg(String itemKey, int count) {
      final weight = weights[itemKey] ?? 0;
      return (weight * count) / 1000.0;
    }

    group('Plastic Tests', () {
      test('1- Small Plastic x5 = 10 pts, 0.10 kg', () {
        expect(calculatePoints('plastic_small', 5), 10);
        expect(calculateWeightKg('plastic_small', 5), 0.10);
      });

      test('2- Medium Plastic x3 = 11 pts, 0.105 kg', () {
        expect(calculatePoints('plastic_medium', 3), 11);
        expect(calculateWeightKg('plastic_medium', 3), 0.105);
      });

      test('3- Large Plastic x5 = 25 pts, 0.25 kg', () {
        expect(calculatePoints('plastic_large', 5), 25);
        expect(calculateWeightKg('plastic_large', 5), 0.25);
      });
    });

    group('Cans Tests', () {
      test('4- Small Can x10 = 15 pts, 0.15 kg', () {
        expect(calculatePoints('cans_small', 10), 15);
        expect(calculateWeightKg('cans_small', 10), 0.15);
      });

      test('5- Medium Can x5 = 9 pts, 0.09 kg', () {
        expect(calculatePoints('cans_medium', 5), 9);
        expect(calculateWeightKg('cans_medium', 5), 0.09);
      });

      test('6- Large Can x10 = 22 pts, 0.22 kg', () {
        expect(calculatePoints('cans_large', 10), 22);
        expect(calculateWeightKg('cans_large', 10), 0.22);
      });
    });

    group('Glass Tests', () {
      test('7- Small Glass x2 = 30 pts, 0.30 kg', () {
        expect(calculatePoints('glass_small', 2), 30);
        expect(calculateWeightKg('glass_small', 2), 0.30);
      });

      test('8- Medium Glass x2 = 40 pts, 0.40 kg', () {
        expect(calculatePoints('glass_medium', 2), 40);
        expect(calculateWeightKg('glass_medium', 2), 0.40);
      });

      test('9- Large Glass x1 = 30 pts, 0.30 kg', () {
        expect(calculatePoints('glass_large', 1), 30);
        expect(calculateWeightKg('glass_large', 1), 0.30);
      });
    });

    group('Mixed Materials', () {
      test('10- Plastic Large x3 + Glass Small x2 + Cans Medium x5', () {
        int totalPoints = 0;
        double totalWeight = 0;
        
        totalPoints += calculatePoints('plastic_large', 3);  // 15
        totalWeight += calculateWeightKg('plastic_large', 3); // 0.15
        
        totalPoints += calculatePoints('glass_small', 2);     // 30
        totalWeight += calculateWeightKg('glass_small', 2);   // 0.30
        
        totalPoints += calculatePoints('cans_medium', 5);     // 9
        totalWeight += calculateWeightKg('cans_medium', 5);   // 0.09
        
        expect(totalPoints, 54);
        expect(totalWeight, closeTo(0.54, 0.01));
      });
    });

    group('Edge Cases', () {
      test('11- Zero items = zero points', () {
        expect(calculatePoints('plastic_large', 0), 0);
        expect(calculateWeightKg('plastic_large', 0), 0.0);
      });

      test('12- Unknown item = zero', () {
        expect(calculatePoints('unknown_item', 5), 0);
        expect(calculateWeightKg('unknown_item', 5), 0.0);
      });
    });
  });
}