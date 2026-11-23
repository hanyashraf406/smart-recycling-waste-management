import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

void main() {
  group('Map & Location Tests', () {
    
    double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
      // Haversine formula simplified
      double R = 6371; // Earth radius in km
      double dLat = (lat2 - lat1) * pi / 180;
      double dLon = (lon2 - lon1) * pi / 180;
      double a = sin(dLat/2) * sin(dLat/2) +
                 cos(lat1 * pi/180) * cos(lat2 * pi/180) *
                 sin(dLon/2) * sin(dLon/2);
      double c = 2 * atan2(sqrt(a), sqrt(1-a));
      return R * c;
    }

    test('1- Distance between Cairo and Giza', () {
      double distance = calculateDistance(30.0444, 31.2357, 30.0131, 31.2089);
      expect(distance, lessThan(10)); // Less than 10 km
    });

    test('2- User location is valid', () {
      double lat = 30.0444;
      double lon = 31.2357;
      expect(lat, inInclusiveRange(-90, 90));
      expect(lon, inInclusiveRange(-180, 180));
    });

    test('3- Employee location is valid', () {
      double lat = 30.0131;
      double lon = 31.2089;
      expect(lat, inInclusiveRange(-90, 90));
      expect(lon, inInclusiveRange(-180, 180));
    });

    test('4- Find closest employee', () {
      double userLat = 30.0444;
      double userLon = 31.2357;
      
      List<Map<String, dynamic>> employees = [
        {'name': 'Sara', 'lat': 30.0131, 'lon': 31.2089},
        {'name': 'Ahmed', 'lat': 30.0500, 'lon': 31.2400},
        {'name': 'Mohamed', 'lat': 30.1000, 'lon': 31.3000},
      ];
      
      String closest = '';
      double shortest = double.infinity;
      
      for (var emp in employees) {
        double dist = calculateDistance(userLat, userLon, emp['lat'], emp['lon']);
        if (dist < shortest) {
          shortest = dist;
          closest = emp['name'];
        }
      }
      
      expect(closest, 'Ahmed');
    });

    test('5- Only show Shift employees on map', () {
      List<Map<String, dynamic>> allEmployees = [
        {'name': 'Sara', 'status': 'shift'},
        {'name': 'Ahmed', 'status': 'break'},
        {'name': 'Mohamed', 'status': 'absent'},
        {'name': 'Nada', 'status': 'shift'},
      ];
      
      var activeEmployees = allEmployees.where((e) => e['status'] == 'shift').toList();
      
      expect(activeEmployees.length, 2);
      expect(activeEmployees[0]['name'], 'Sara');
      expect(activeEmployees[1]['name'], 'Nada');
    });
  });
}