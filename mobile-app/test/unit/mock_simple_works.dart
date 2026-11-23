import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:trash_to_cash/main.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    // حقن Firestore الوهمي في الـ Service بتاعك
    FirebaseService.setMocks(firestore: fakeFirestore);
  });

  test('getUserData بتجيب البيانات من Firestore الوهمي', () async {
    // حط بيانات وهمية
    await fakeFirestore.collection('users').doc('user123').set({
      'firstName': 'Hany',
      'lastName': 'Ashraf',
      'points': 50,
    });

    final data = await FirebaseService.getUserData('user123');
    expect(data, isNotNull);
    expect(data!['firstName'], 'Hany');
    expect(data['points'], 50);
  });

  test('getUserRole بتجيب الدور الصحيح', () async {
    await fakeFirestore.collection('users').doc('emp123').set({
      'role': 'employ',
    });
    final role = await FirebaseService.getUserRole('emp123');
    expect(role, 'employ');
  });

  test('blockUser بتغير isBlocked لـ true', () async {
    await fakeFirestore.collection('users').doc('user456').set({
      'isBlocked': false,
    });
    await FirebaseService.blockUser('user456', 'user');
    final doc = await fakeFirestore.collection('users').doc('user456').get();
    expect(doc.data()?['isBlocked'], true);
  });
}