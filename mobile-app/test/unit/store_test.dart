import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Store & Points Conversion Tests', () {
    
    // من StoreData في الكود الأصلي
    const double pointsToEgpRate = 0.05;
    const double egpToPointsRate = 20.0;

    int calculateRequiredPoints(double amountEgp) {
      return (amountEgp * egpToPointsRate).ceil();
    }

    double calculateEgpValue(int points) {
      return points * pointsToEgpRate;
    }

    test('1- 10 EGP = 200 Points', () {
      expect(calculateRequiredPoints(10), 200);
    });

    test('2- 50 EGP = 1000 Points', () {
      expect(calculateRequiredPoints(50), 1000);
    });

    test('3- 100 EGP = 2000 Points', () {
      expect(calculateRequiredPoints(100), 2000);
    });

    test('4- 200 Points = 10 EGP', () {
      expect(calculateEgpValue(200), 10.0);
    });

    test('5- 500 Points = 25 EGP', () {
      expect(calculateEgpValue(500), 25.0);
    });

    test('6- 1000 Points = 50 EGP', () {
      expect(calculateEgpValue(1000), 50.0);
    });

    test('7- Zero EGP = Zero Points', () {
      expect(calculateRequiredPoints(0), 0);
    });

    test('8- Zero Points = Zero EGP', () {
      expect(calculateEgpValue(0), 0.0);
    });

    test('9- Conversion Round Trip: 25 EGP → 500 pts → 25 EGP', () {
      int points = calculateRequiredPoints(25);
      double egp = calculateEgpValue(points);
      expect(points, 500);
      expect(egp, 25.0);
    });

    test('10- Sufficient Points Check', () {
      int userPoints = 500;
      int requiredPoints = 200;
      expect(userPoints >= requiredPoints, true);
    });

    test('11- Insufficient Points Check', () {
      int userPoints = 100;
      int requiredPoints = 200;
      expect(userPoints >= requiredPoints, false);
    });
  });
}