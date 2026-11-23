import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'counter_service.dart';
import 'material_service.dart';
import 'notifications_service.dart';
import 'recharge_service.dart';

class FirebaseService {
  static late FirebaseAuth _auth;
  static late FirebaseFirestore _firestore;
  static late FirebaseStorage _storage;

  static void initialize({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) {
    _auth = auth ?? FirebaseAuth.instance;
    _firestore = firestore ?? FirebaseFirestore.instance;
    _storage = storage ?? FirebaseStorage.instance;
  }

  static User? get currentUser => _auth.currentUser;

  static String _getCollectionName(String role) {
    return role == 'employ' || role == 'admin' ? 'employees' : 'users';
  }

  static Future<User?> signInWithEmail(String email, String password, String role) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final collectionName = _getCollectionName(role);
      final userDoc = await _firestore.collection(collectionName).doc(result.user!.uid).get();

      if (!userDoc.exists) {
        await _auth.signOut();
        return null;
      }

      final userRole = userDoc.data()?['role'] as String?;
      if (userRole != role) {
        await _auth.signOut();
        return null;
      }

      final isBlocked = userDoc.data()?['isBlocked'] as bool? ?? false;
      if (isBlocked) {
        await _auth.signOut();
        throw Exception('Your account has been blocked.');
      }

      return result.user;
    } catch (e) {
      return null;
    }
  }

  static Future<User?> signUpWithEmail(String email, String password, Map<String, dynamic> userData) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final role = userData['role'] as String;
      final collectionName = _getCollectionName(role);

      String displayId = '';
      if (role == 'user') {
        displayId = await CounterService.getNextId('user');
      } else if (role == 'employ' || role == 'admin') {
        displayId = await CounterService.getNextId('employee');
      }

      final baseData = {
        ...userData,
        'email': email.trim(),
        'userId': result.user!.uid,
        'displayId': displayId,
        'createdAt': FieldValue.serverTimestamp(),
        'isBlocked': false,
      };

      if (role == 'user') {
        baseData.addAll({
          'points': 0,
          'totalScans': 0,
          'totalItems': 0,
          'profileImage': '',
          'lastProfileUpdate': FieldValue.serverTimestamp(),
          'isScanned': false,
          'materialsWeight': <String, double>{},
        });
      } else if (role == 'employ' || role == 'admin') {
        baseData.addAll({
          'profileImage': '',
          'lastProfileUpdate': FieldValue.serverTimestamp(),
          'totalScans': 0,
          'totalWeight': 0.0,
          'status': 'shift',
          'latitude': 0.0,
          'longitude': 0.0,
          'lastLocationUpdate': null,
        });
      }

      await _firestore.collection(collectionName).doc(result.user!.uid).set(baseData);
      return result.user;
    } catch (e) {
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {}
  }

  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {}
  }

  static Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> blockUser(String userId, String role) async {
    try {
      final collectionName = _getCollectionName(role);
      await _firestore.collection(collectionName).doc(userId).update({
        'isBlocked': true,
        'blockedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> unblockUser(String userId, String role) async {
    try {
      final collectionName = _getCollectionName(role);
      await _firestore.collection(collectionName).doc(userId).update({
        'isBlocked': false,
        'unblockedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      var doc = await _firestore.collection('users').doc(userId).get();
      String collectionName = 'users';

      if (!doc.exists) {
        doc = await _firestore.collection('employees').doc(userId).get();
        collectionName = 'employees';
      }

      if (!doc.exists) return null;

      final data = doc.data()!;
      final role = data['role'] as String? ?? 'user';

      final baseData = {
        'firstName': data['firstName'] ?? '',
        'lastName': data['lastName'] ?? '',
        'email': data['email'] ?? '',
        'phone': data['phone'] ?? '',
        'role': role,
        'displayId': data['displayId'] ?? '',
        'createdAt': data['createdAt'],
        'profileImage': data['profileImage'] ?? '',
        'isBlocked': data['isBlocked'] ?? false,
      };

      if (role == 'user') {
        baseData.addAll({
          'points': (data['points'] as num?)?.toInt() ?? 0,
          'totalScans': (data['totalScans'] as num?)?.toInt() ?? 0,
          'totalItems': (data['totalItems'] as num?)?.toInt() ?? 0,
          'lastScan': data['lastScan'],
          'isScanned': data['isScanned'] ?? false,
          'materialsWeight': data['materialsWeight'] as Map<String, dynamic>? ?? {},
        });
      } else {
        baseData.addAll({
          'warehouseId': data['warehouseId'] ?? '',
          'warehouseName': data['warehouseName'] ?? '',
          'totalScans': (data['totalScans'] as num?)?.toInt() ?? 0,
          'totalWeight': (data['totalWeight'] as num?)?.toDouble() ?? 0.0,
          'status': data['status'] ?? 'absent',
        });
      }

      return baseData;
    } catch (e) {
      return null;
    }
  }

  static Stream<DocumentSnapshot> getUserStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  static Future<String?> getUserRole(String userId) async {
    try {
      var doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) return doc.data()?['role'] as String?;

      doc = await _firestore.collection('employees').doc(userId).get();
      if (doc.exists) return doc.data()?['role'] as String?;

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> updateUserProfile({
    required String userId,
    String? firstName,
    String? lastName,
    String? phone,
    String? profileImage,
  }) async {
    try {
      final role = await getUserRole(userId);
      final collectionName = _getCollectionName(role ?? 'user');

      final Map<String, dynamic> updateData = {};
      if (firstName != null && firstName.isNotEmpty) updateData['firstName'] = firstName;
      if (lastName != null && lastName.isNotEmpty) updateData['lastName'] = lastName;
      if (phone != null && phone.isNotEmpty) updateData['phone'] = phone;
      if (profileImage != null && profileImage.isNotEmpty) updateData['profileImage'] = profileImage;

      updateData['lastProfileUpdate'] = FieldValue.serverTimestamp();

      if (updateData.isNotEmpty) {
        await _firestore.collection(collectionName).doc(userId).update(updateData);
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<String?> uploadProfileImage(File imageFile, String userId) async {
    try {
      if (!await imageFile.exists()) return null;
      if (_auth.currentUser == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_${userId}_$timestamp.jpg';
      final ref = _storage.ref().child('profile_images').child(fileName);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'uploadedAt': timestamp.toString(),
          'email': _auth.currentUser?.email ?? 'unknown'
        },
      );

      final uploadTask = ref.putFile(imageFile, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getWarehouses() async {
    try {
      final snapshot = await _firestore
          .collection('warehouses')
          .where('isActive', isEqualTo: true)
          .orderBy('warehouseId')
          .get();

      if (snapshot.docs.isEmpty) {
        await initializeWarehouses();
        final retrySnapshot = await _firestore
            .collection('warehouses')
            .where('isActive', isEqualTo: true)
            .orderBy('warehouseId')
            .get();

        return retrySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'warehouseId': data['warehouseId'] ?? '',
            'name': data['name'] ?? '',
            'city': data['city'] ?? '',
            'address': data['address'] ?? '',
            'isActive': data['isActive'] ?? true,
          };
        }).toList();
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'warehouseId': data['warehouseId'] ?? '',
          'name': data['name'] ?? '',
          'city': data['city'] ?? '',
          'address': data['address'] ?? '',
          'isActive': data['isActive'] ?? true,
        };
      }).toList();
    } catch (e) {
      return _getDefaultWarehouses();
    }
  }

  static List<Map<String, dynamic>> _getDefaultWarehouses() {
    return [
      {'warehouseId': 'WH-001', 'name': 'Madinaty', 'city': 'Cairo', 'address': 'Madinaty City', 'isActive': true},
      {'warehouseId': 'WH-002', 'name': 'Al Shorouk', 'city': 'Cairo', 'address': 'Al Shorouk City', 'isActive': true},
      {'warehouseId': 'WH-003', 'name': 'Al Rehab', 'city': 'Cairo', 'address': 'Al Rehab City', 'isActive': true},
      {'warehouseId': 'WH-004', 'name': 'New Cairo', 'city': 'Cairo', 'address': 'New Cairo City', 'isActive': true},
      {'warehouseId': 'WH-005', 'name': '6th of October', 'city': 'Giza', 'address': '6th of October City', 'isActive': true},
      {'warehouseId': 'WH-006', 'name': 'Sheikh Zayed', 'city': 'Giza', 'address': 'Sheikh Zayed City', 'isActive': true},
      {'warehouseId': 'WH-007', 'name': 'Al Obour', 'city': 'Qalyubia', 'address': 'Al Obour City', 'isActive': true},
    ];
  }

  static Future<void> initializeWarehouses() async {
    try {
      final warehouses = _getDefaultWarehouses();
      final batch = _firestore.batch();

      for (var wh in warehouses) {
        final String docId = wh['warehouseId'] as String;
        final docRef = _firestore.collection('warehouses').doc(docId);
        batch.set(docRef, {
          'warehouseId': wh['warehouseId'],
          'name': wh['name'],
          'city': wh['city'],
          'address': wh['address'],
          'isActive': wh['isActive'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {}
  }

  static Future<List<Map<String, dynamic>>> getMaterials() async {
    try {
      final snapshot = await _firestore
          .collection('materials')
          .where('status', isEqualTo: 'Active')
          .orderBy('materialId')
          .get();

      if (snapshot.docs.isEmpty) {
        await initializeMaterials();
        final retrySnapshot = await _firestore
            .collection('materials')
            .where('status', isEqualTo: 'Active')
            .orderBy('materialId')
            .get();

        return retrySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'materialId': data['materialId'] ?? '',
            'name': data['name'] ?? '',
            'type': data['type'] ?? '',
            'icon': data['icon'] ?? '📦',
            'pointsPerKg': data['pointsPerKg'] ?? 100,
            'status': data['status'] ?? 'Active',
          };
        }).toList();
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'materialId': data['materialId'] ?? '',
          'name': data['name'] ?? '',
          'type': data['type'] ?? '',
          'icon': data['icon'] ?? '📦',
          'pointsPerKg': data['pointsPerKg'] ?? 100,
          'status': data['status'] ?? 'Active',
        };
      }).toList();
    } catch (e) {
      return _getDefaultMaterials();
    }
  }

  static List<Map<String, dynamic>> _getDefaultMaterials() {
    return [
      {'materialId': 'M-001', 'name': 'Plastic', 'type': 'plastic', 'icon': '📦', 'pointsPerKg': 100, 'status': 'Active'},
      {'materialId': 'M-002', 'name': 'Cans', 'type': 'cans', 'icon': '📦', 'pointsPerKg': 100, 'status': 'Active'},
      {'materialId': 'M-003', 'name': 'Glass', 'type': 'glass', 'icon': '📦', 'pointsPerKg': 100, 'status': 'Active'},
    ];
  }

  static Future<void> initializeMaterials() async {
    try {
      final materials = _getDefaultMaterials();
      final batch = _firestore.batch();

      for (var mat in materials) {
        final String docId = mat['materialId'] as String;
        final docRef = _firestore.collection('materials').doc(docId);
        batch.set(docRef, {
          'materialId': mat['materialId'],
          'name': mat['name'],
          'type': mat['type'],
          'icon': mat['icon'],
          'pointsPerKg': mat['pointsPerKg'],
          'status': mat['status'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {}
  }

  static Future<Map<String, dynamic>> saveRecyclingTransaction({
    required String userId,
    required String qrData,
    required List<Map<String, dynamic>> items,
  }) async {
    final employee = _auth.currentUser;
    if (employee == null) throw Exception('Employee not logged in');

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) throw Exception('User not found');

      final userData = userDoc.data()!;
      final String userName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
      final String userDisplayId = userData['displayId'] ?? userId;

      final employeeDoc = await _firestore.collection('employees').doc(employee.uid).get();
      final employeeData = employeeDoc.data()!;
      final String employeeDisplayId = employeeData['displayId'] ?? employee.uid;
      final String warehouseId = employeeData['warehouseId'] ?? '';
      final String warehouseName = employeeData['warehouseName'] ?? '';

      double totalWeightKg = 0.0;
      int totalPoints = 0;
      int totalItems = 0;
      Map<String, double> materialsWeight = {};

      for (var item in items) {
        final itemKey = item['itemKey'] as String;
        final count = item['count'] as int;
        final itemData = MaterialService.getItemByKey(itemKey);

        final itemWeight = MaterialService.calculateWeightInKg(itemKey, count);
        final itemPoints = MaterialService.calculatePoints(itemKey, count);

        totalWeightKg += itemWeight;
        totalPoints += itemPoints;
        totalItems += count;

        if (itemData != null) {
          final category = itemData['category'] as String;
          materialsWeight[category] = (materialsWeight[category] ?? 0) + itemWeight;
        }
      }

      final processId = await CounterService.getNextId('process');

      await _firestore.collection('recycling_processes').doc(processId).set({
        'processId': processId,
        'employeeId': employee.uid,
        'employeeDisplayId': employeeDisplayId,
        'employeeEmail': employee.email,
        'userId': userId,
        'userDisplayId': userDisplayId,
        'userEmail': userData['email'] ?? '',
        'userName': userName.isNotEmpty ? userName : (userData['email'] ?? '').toString().split('@').first,
        'warehouseId': warehouseId,
        'warehouseName': warehouseName,
        'qrData': qrData,
        'scannedAt': FieldValue.serverTimestamp(),
        'items': items,
        'totalWeightKg': totalWeightKg,
        'totalPoints': totalPoints,
        'totalItems': totalItems,
        'materialsWeight': materialsWeight,
        'status': 'Done',
        'reported': false,
      });

      final updateData = <String, dynamic>{
        'points': FieldValue.increment(totalPoints),
        'totalScans': FieldValue.increment(1),
        'totalItems': FieldValue.increment(totalItems),
        'lastScan': FieldValue.serverTimestamp(),
        'isScanned': true,
      };

      final userMaterialsWeight = Map<String, dynamic>.from(userData['materialsWeight'] as Map<String, dynamic>? ?? {});
      for (var entry in materialsWeight.entries) {
        userMaterialsWeight[entry.key] = (userMaterialsWeight[entry.key] ?? 0.0) + entry.value;
      }
      updateData['materialsWeight'] = userMaterialsWeight;

      await _firestore.collection('users').doc(userId).update(updateData);

      await _firestore.collection('employees').doc(employee.uid).update({
        'totalScans': FieldValue.increment(1),
        'totalWeight': FieldValue.increment(totalWeightKg),
        'lastScan': FieldValue.serverTimestamp(),
      });

      await _updateInventory(materialsWeight, employee.uid, warehouseId);

      await _firestore.collection('reviews').add({
        'userId': userId,
        'userDisplayId': userDisplayId,
        'userName': userName.isNotEmpty ? userName : (userData['email'] ?? '').toString().split('@').first,
        'employeeId': employee.uid,
        'employeeDisplayId': employeeDisplayId,
        'processId': processId,
        'pointsEarned': totalPoints,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'rating': 0,
        'comment': '',
      });

      return {
        'totalPoints': totalPoints,
        'totalWeightKg': totalWeightKg,
        'processId': processId,
        'userId': userId,
        'employeeId': employee.uid,
      };
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> _updateInventory(Map<String, double> materials, String employeeId, String warehouseId) async {
    try {
      final batch = _firestore.batch();

      for (var entry in materials.entries) {
        if (entry.value > 0) {
          final inventoryRef = _firestore
              .collection('inventory')
              .doc('${employeeId}_${entry.key}');

          final inventoryDoc = await inventoryRef.get();
          if (inventoryDoc.exists) {
            batch.update(inventoryRef, {
              'weight': FieldValue.increment(entry.value),
              'lastUpdated': FieldValue.serverTimestamp()
            });
          } else {
            batch.set(inventoryRef, {
              'employeeId': employeeId,
              'warehouseId': warehouseId,
              'type': entry.key,
              'weight': entry.value,
              'lastUpdated': FieldValue.serverTimestamp()
            });
          }
        }
      }

      await batch.commit();
    } catch (e) {}
  }

  static Future<void> submitReview({
    required String reviewId,
    required double rating,
    required String comment,
  }) async {
    try {
      await _firestore.collection('reviews').doc(reviewId).update({
        'rating': rating,
        'comment': comment,
        'status': 'completed',
        'submittedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  static Stream<List<Map<String, dynamic>>> getPendingReviewsForUser(String userId) {
    return _firestore
        .collection('reviews')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }

  static Future<Map<String, dynamic>> getInventoryStats() async {
    final employee = _auth.currentUser;
    if (employee == null) {
      return {'totalUsers': 0, 'totalOperations': 0, 'totalWeight': 0.0};
    }

    try {
      final allScans = await _firestore
          .collection('recycling_processes')
          .where('employeeId', isEqualTo: employee.uid)
          .get();

      final inventorySnap = await _firestore
          .collection('inventory')
          .where('employeeId', isEqualTo: employee.uid)
          .get();

      double totalWeight = 0.0;
      final uniqueUsers = <String>{};

      for (var doc in allScans.docs) {
        uniqueUsers.add(doc.data()['userId'] as String);
      }

      for (var doc in inventorySnap.docs) {
        totalWeight += (doc.data()['weight'] as num?)?.toDouble() ?? 0.0;
      }

      return {
        'totalUsers': uniqueUsers.length,
        'totalOperations': allScans.docs.length,
        'totalWeight': totalWeight
      };
    } catch (e) {
      return {'totalUsers': 0, 'totalOperations': 0, 'totalWeight': 0.0};
    }
  }

  static Future<Map<String, double>> getMaterialQuantities() async {
    final employee = _auth.currentUser;
    if (employee == null) return {};

    try {
      final inventorySnapshot = await _firestore
          .collection('inventory')
          .where('employeeId', isEqualTo: employee.uid)
          .get();

      Map<String, double> quantities = {};
      for (var doc in inventorySnapshot.docs) {
        final data = doc.data();
        final type = data['type'] as String?;
        final weight = (data['weight'] as num?)?.toDouble() ?? 0.0;
        if (type != null) {
          quantities[type] = weight;
        }
      }

      final materialTypes = MaterialService.getMaterialTypes();
      for (var type in materialTypes) {
        quantities.putIfAbsent(type, () => 0.0);
      }

      return quantities;
    } catch (e) {
      return {};
    }
  }

  static Future<List<Map<String, dynamic>>> getRecentScans({int limit = 10}) async {
    final employee = _auth.currentUser;
    if (employee == null) return [];

    try {
      final scansSnapshot = await _firestore
          .collection('recycling_processes')
          .where('employeeId', isEqualTo: employee.uid)
          .orderBy('scannedAt', descending: true)
          .limit(limit)
          .get();

      return scansSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'processId': data['processId'] ?? doc.id,
          'userName': data['userName'] as String? ?? 'Unknown User',
          'userEmail': data['userEmail'] as String? ?? 'Unknown Email',
          'userDisplayId': data['userDisplayId'] as String? ?? '',
          'totalWeightKg': (data['totalWeightKg'] as num?)?.toDouble() ?? 0.0,
          'totalPoints': (data['totalPoints'] as num?)?.toInt() ?? 0,
          'totalItems': (data['totalItems'] as num?)?.toInt() ?? 0,
          'materialsWeight': data['materialsWeight'] as Map<String, dynamic>? ?? {},
          'scannedAt': data['scannedAt'] as Timestamp? ?? Timestamp.now(),
          'status': data['status'] as String? ?? 'Done',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<String> createDailyReport({
    required String employeeId,
    required Map<String, double> materials,
    required String notes,
  }) async {
    try {
      final employeeDoc = await _firestore.collection('employees').doc(employeeId).get();
      final employeeData = employeeDoc.data()!;
      final String employeeDisplayId = employeeData['displayId'] ?? employeeId;
      final String warehouseId = employeeData['warehouseId'] ?? '';
      final String warehouseName = employeeData['warehouseName'] ?? '';

      double totalWeight = 0.0;
      int totalPoints = 0;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final startOfDay = Timestamp.fromDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
      final endOfDay = Timestamp.fromDate(DateTime.now());

      final processesSnapshot = await _firestore
          .collection('recycling_processes')
          .where('employeeId', isEqualTo: employeeId)
          .where('scannedAt', isGreaterThanOrEqualTo: startOfDay)
          .where('scannedAt', isLessThanOrEqualTo: endOfDay)
          .get();

      Map<String, double> processMaterials = {};
      for (var doc in processesSnapshot.docs) {
        final data = doc.data();
        totalWeight += (data['totalWeightKg'] as num?)?.toDouble() ?? 0.0;
        totalPoints += (data['totalPoints'] as num?)?.toInt() ?? 0;

        final procMaterials = data['materialsWeight'] as Map<String, dynamic>? ?? {};
        for (var entry in procMaterials.entries) {
          processMaterials[entry.key] = (processMaterials[entry.key] ?? 0.0) + (entry.value as num).toDouble();
        }
      }

      final reportData = {
        'employeeId': employeeId,
        'employeeDisplayId': employeeDisplayId,
        'warehouseId': warehouseId,
        'warehouseName': warehouseName,
        'reportType': 'daily',
        'reportDate': today,
        'totalWeight': totalWeight > 0 ? totalWeight : materials.values.fold(0.0, (sum, w) => sum + w),
        'totalPoints': totalPoints,
        'materials': processMaterials.isNotEmpty ? processMaterials : materials,
        'notes': notes,
        'status': 'pending',
        'processCount': processesSnapshot.docs.length,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('reports').add(reportData);
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  static Future<String> createReport({
    required String employeeId,
    required String reportType,
    required double totalWeight,
    required int totalPoints,
    required Map<String, double> materials,
    required String notes,
  }) async {
    return createDailyReport(
      employeeId: employeeId,
      materials: materials,
      notes: notes,
    );
  }

  static Future<void> approveReport(String reportId, String employeeId) async {
    try {
      final reportDoc = await _firestore.collection('reports').doc(reportId).get();
      if (!reportDoc.exists) throw Exception('Report not found');

      await _firestore.collection('reports').doc(reportId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      final inventorySnapshot = await _firestore
          .collection('inventory')
          .where('employeeId', isEqualTo: employeeId)
          .get();

      if (inventorySnapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in inventorySnapshot.docs) {
          batch.update(doc.reference, {
            'weight': 0.0,
            'lastUpdated': FieldValue.serverTimestamp(),
            'lastReset': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getEmployeeReports(String employeeId) async {
    try {
      final reportsSnapshot = await _firestore
          .collection('reports')
          .where('employeeId', isEqualTo: employeeId)
          .orderBy('createdAt', descending: true)
          .get();

      return reportsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getScannedUsers() async {
    final employee = _auth.currentUser;
    if (employee == null) return [];

    try {
      final transactionsSnapshot = await _firestore
          .collection('recycling_processes')
          .where('employeeId', isEqualTo: employee.uid)
          .orderBy('scannedAt', descending: true)
          .get();

      final Map<String, Map<String, dynamic>> usersMap = {};

      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String;

        if (!usersMap.containsKey(userId)) {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;

            double totalWeight = 0.0;
            Map<String, double> materialsWeight = {};
            int totalUserPoints = 0;

            final userTransactions = transactionsSnapshot.docs
                .where((d) => d.data()['userId'] == userId);

            for (var t in userTransactions) {
              final tData = t.data();
              totalWeight += (tData['totalWeightKg'] as num?)?.toDouble() ?? 0.0;
              totalUserPoints += (tData['totalPoints'] as num?)?.toInt() ?? 0;

              final tMaterials = tData['materialsWeight'] as Map<String, dynamic>? ?? {};
              for (var entry in tMaterials.entries) {
                materialsWeight[entry.key] = (materialsWeight[entry.key] ?? 0.0) + (entry.value as num).toDouble();
              }
            }

            usersMap[userId] = {
              'id': userId,
              'displayId': userData['displayId'] ?? userId,
              'firstName': userData['firstName'] ?? '',
              'lastName': userData['lastName'] ?? '',
              'email': userData['email'] ?? '',
              'points': totalUserPoints,
              'materialsWeight': materialsWeight,
              'totalWeight': totalWeight,
              'totalScans': userTransactions.length,
              'isBlocked': userData['isBlocked'] ?? false,
            };
          }
        }
      }

      return usersMap.values.toList();
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getEmployeeStats(String employeeId) async {
    try {
      final transactionsSnapshot = await _firestore
          .collection('recycling_processes')
          .where('employeeId', isEqualTo: employeeId)
          .orderBy('scannedAt', descending: true)
          .get();

      int totalScans = transactionsSnapshot.docs.length;
      double totalWeight = 0.0;
      Timestamp? lastScan;

      if (transactionsSnapshot.docs.isNotEmpty) {
        lastScan = transactionsSnapshot.docs.first['scannedAt'] as Timestamp?;
        for (var doc in transactionsSnapshot.docs) {
          totalWeight += (doc.data()['totalWeightKg'] as num?)?.toDouble() ?? 0.0;
        }
      }

      return {
        'totalScans': totalScans,
        'totalWeight': totalWeight,
        'lastScan': lastScan,
      };
    } catch (e) {
      return {
        'totalScans': 0,
        'totalWeight': 0.0,
        'lastScan': null,
      };
    }
  }

  static Future<bool> sendOTP(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> verifyOTP(String email, String otp) async {
    try {
      if (otp.length == 6) {
        await Future.delayed(const Duration(seconds: 1));
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<String> getEmployeeStatus(String employeeId) async {
    try {
      final employeeDoc = await _firestore.collection('employees').doc(employeeId).get();
      if (!employeeDoc.exists) return 'absent';

      final data = employeeDoc.data()!;
      return data['status'] as String? ?? 'absent';
    } catch (e) {
      return 'absent';
    }
  }

  static Future<List<Map<String, dynamic>>> getActiveEmployees() async {
    try {
      final snapshot = await _firestore
          .collection('employees')
          .where('status', isEqualTo: 'shift')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
          'displayId': data['displayId'] ?? '',
          'warehouseName': data['warehouseName'] ?? '',
          'warehouseId': data['warehouseId'] ?? '',
          'phone': data['phone'] ?? '',
          'latitude': data['latitude'] ?? 0.0,
          'longitude': data['longitude'] ?? 0.0,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> updateEmployeeLocation(String employeeId, double latitude, double longitude) async {
    try {
      await _firestore.collection('employees').doc(employeeId).update({
        'latitude': latitude,
        'longitude': longitude,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {}
  }

  static Future<Map<String, dynamic>> processStoreTransaction({
    required String userId,
    required String serviceType,
    required String companyName,
    required String cardNumber,
    required double amountEgp,
    required int pointsUsed,
  }) async {
    return RechargeService.processRecharge(
      userId: userId,
      serviceType: serviceType,
      companyName: companyName,
      cardNumber: cardNumber,
      amountEgp: amountEgp,
      pointsUsed: pointsUsed,
    );
  }
}