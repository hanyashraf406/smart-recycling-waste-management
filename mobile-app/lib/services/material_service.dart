import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/item_weights.dart';

class MaterialService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static List<Map<String, dynamic>> _allMaterials = [];
  static List<Map<String, dynamic>> _allItems = [];
  static bool _isLoaded = false;

  static Future<void> loadMaterials() async {
    try {
      final snapshot = await _firestore
          .collection('materials')
          .where('status', isEqualTo: 'Active')
          .get();

      _allMaterials = snapshot.docs.map((doc) => doc.data()).toList();
      _allItems = [];

      for (var material in _allMaterials) {
        final type = material['type'] as String? ?? '';
        final sizes = material['sizes'] as List<dynamic>? ?? [];

        if (sizes.isNotEmpty) {
          for (var size in sizes) {
            _allItems.add({
              'key': size['sizeId'] ?? '${type}_default',
              'name': size['name'] ?? material['name'],
              'image': 'assets/images/${size['image'] ?? 'placeholder.png'}',
              'weight_grams': size['weightGrams'] ?? 20,
              'points': size['points'] ?? 2,
              'category': type,
            });
          }
        } else {
          final defaultItems = ItemWeights.getItemsByType(type);
          if (defaultItems.isNotEmpty) {
            for (var item in defaultItems) {
              _allItems.add({...item, 'category': type});
            }
          } else {
            _allItems.add({
              'key': '${type}_default',
              'name': material['name'] ?? type,
              'image': 'assets/images/placeholder.png',
              'weight_grams': 20,
              'points': 2,
              'category': type,
            });
          }
        }
      }

      _isLoaded = true;
    } catch (e) {
      _loadDefaultMaterials();
    }
  }

  static void _loadDefaultMaterials() {
    _allItems = [];
    _allItems.addAll([
      {'key': 'plastic_small', 'name': 'Small Plastic', 'image': 'assets/images/plastic_small.png', 'weight_grams': 20, 'points': 2, 'category': 'plastic'},
      {'key': 'plastic_medium', 'name': 'Medium Plastic', 'image': 'assets/images/plastic_medium.png', 'weight_grams': 35, 'points': 3, 'category': 'plastic'},
      {'key': 'plastic_large', 'name': 'Large Plastic', 'image': 'assets/images/plastic_large.png', 'weight_grams': 50, 'points': 5, 'category': 'plastic'},
      {'key': 'cans_small', 'name': 'Small Can', 'image': 'assets/images/can_small.png', 'weight_grams': 15, 'points': 1, 'category': 'cans'},
      {'key': 'cans_medium', 'name': 'Medium Can', 'image': 'assets/images/can_medium.png', 'weight_grams': 18, 'points': 2, 'category': 'cans'},
      {'key': 'cans_large', 'name': 'Large Can', 'image': 'assets/images/can_large.png', 'weight_grams': 22, 'points': 3, 'category': 'cans'},
      {'key': 'glass_small', 'name': 'Small Glass', 'image': 'assets/images/glass_small.png', 'weight_grams': 150, 'points': 15, 'category': 'glass'},
      {'key': 'glass_medium', 'name': 'Medium Glass', 'image': 'assets/images/glass_medium.png', 'weight_grams': 200, 'points': 20, 'category': 'glass'},
      {'key': 'glass_large', 'name': 'Large Glass', 'image': 'assets/images/glass_large.png', 'weight_grams': 300, 'points': 30, 'category': 'glass'},
    ]);
    _isLoaded = true;
  }

  static List<String> getMaterialTypes() {
    final types = <String>{};
    for (var item in _allItems) {
      types.add(item['category'] as String);
    }
    return types.toList();
  }

  static List<Map<String, dynamic>> getAllMaterials() {
    return _allMaterials;
  }

  static String getMaterialName(String type) {
    for (var mat in _allMaterials) {
      if (mat['type'] == type) return mat['name'] ?? type;
    }
    return type;
  }

  static String getMaterialIcon(String type) {
    for (var mat in _allMaterials) {
      if (mat['type'] == type) return mat['icon'] ?? '📦';
    }
    return '📦';
  }

  static Color getMaterialColor(String type) {
    for (var mat in _allMaterials) {
      if (mat['type'] == type && mat['color'] != null) {
        final colorHex = mat['color'] as String;
        return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
      }
    }
    switch (type) {
      case 'plastic': return const Color(0xFF2196F3);
      case 'cans': return const Color(0xFFFF9800);
      case 'glass': return const Color(0xFF4CAF50);
      default: return const Color(0xFF00C76A);
    }
  }

  static List<Map<String, dynamic>> getItemsByType(String type) {
    return _allItems.where((item) => item['category'] == type).toList();
  }

  static Map<String, dynamic>? getItemByKey(String key) {
    try {
      return _allItems.firstWhere((item) => item['key'] == key);
    } catch (e) {
      return null;
    }
  }

  static double calculateWeightInKg(String itemKey, int count) {
    final item = getItemByKey(itemKey);
    if (item == null) return 0.0;
    final weightGrams = (item['weight_grams'] as num).toInt();
    return (weightGrams * count) / 1000.0;
  }

  static int calculatePoints(String itemKey, int count) {
    final item = getItemByKey(itemKey);
    if (item == null) return 0;
    if (item['points'] != null) {
      return (item['points'] as int) * count;
    }
    final weightGrams = (item['weight_grams'] as num).toInt();
    final totalGrams = weightGrams * count;
    return ((totalGrams / 100) * 10).round();
  }
}