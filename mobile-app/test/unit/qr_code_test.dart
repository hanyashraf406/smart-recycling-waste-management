import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QR Code Tests', () {
    
    test('1- QR Data Format - User QR', () {
      String qrData = 'TRASH_TO_CASH_USER_user123_1699999999999';
      
      List<String> parts = qrData.split('_');
      
      expect(parts.length, greaterThanOrEqualTo(5));
      expect(parts[0], 'TRASH');
      expect(parts[1], 'TO');
      expect(parts[2], 'CASH');
      expect(parts[3], 'USER');
    });

    test('2- QR Data Format - Invalid', () {
      String qrData = 'INVALID_QR_CODE';
      
      List<String> parts = qrData.split('_');
      bool isValid = parts.length >= 5 && parts[0] == 'TRASH';
      
      expect(isValid, false);
    });

    test('3- Extract User ID from QR', () {
      String qrData = 'TRASH_TO_CASH_USER_user123_1699999999999';
      
      List<String> parts = qrData.split('_');
      String userId = parts[4];
      
      expect(userId, 'user123');
    });

    test('4- QR Data with Timestamp', () {
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String qrData = 'TRASH_TO_CASH_USER_user456_$timestamp';
      
      expect(qrData.contains('USER'), true);
      expect(qrData.contains('user456'), true);
      expect(qrData.contains(timestamp), true);
    });

    test('5- Empty QR Data', () {
      String qrData = '';
      
      bool isValid = qrData.isNotEmpty;
      
      expect(isValid, false);
    });
  });
}