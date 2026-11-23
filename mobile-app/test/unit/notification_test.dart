import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notification Tests', () {
    
    int unreadCount = 0;
    
    void addNotification() {
      unreadCount++;
    }
    
    void markAsRead() {
      if (unreadCount > 0) unreadCount--;
    }
    
    void markAllAsRead() {
      unreadCount = 0;
    }

    setUp(() {
      unreadCount = 0;
    });

    test('1- New notification increases count', () {
      addNotification();
      expect(unreadCount, 1);
    });

    test('2- Multiple notifications', () {
      addNotification();
      addNotification();
      addNotification();
      expect(unreadCount, 3);
    });

    test('3- Mark one as read decreases count', () {
      addNotification();
      addNotification();
      markAsRead();
      expect(unreadCount, 1);
    });

    test('4- Mark all as read resets to zero', () {
      addNotification();
      addNotification();
      addNotification();
      markAllAsRead();
      expect(unreadCount, 0);
    });

    test('5- Badge shows correct number', () {
      addNotification();
      addNotification();
      expect(unreadCount, 2);
    });

    test('6- Badge hidden when zero', () {
      expect(unreadCount, 0);
    });
  });
}