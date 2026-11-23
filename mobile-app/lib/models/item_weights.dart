class ItemWeights {
  static const Map<String, Map<String, dynamic>> plastic = {
    'plastic_small': {
      'name': 'Small Plastic',
      'image': 'assets/images/plastic_small.png',
      'weight_grams': 20,
    },
    'plastic_medium': {
      'name': 'Medium Plastic',
      'image': 'assets/images/plastic_medium.png',
      'weight_grams': 35,
    },
    'plastic_large': {
      'name': 'Large Plastic',
      'image': 'assets/images/plastic_large.png',
      'weight_grams': 50,
    },
  };

  static const Map<String, Map<String, dynamic>> cans = {
    'cans_small': {
      'name': 'Small Can',
      'image': 'assets/images/can_small.png',
      'weight_grams': 15,
    },
    'cans_medium': {
      'name': 'Medium Can',
      'image': 'assets/images/can_medium.png',
      'weight_grams': 18,
    },
    'cans_large': {
      'name': 'Large Can',
      'image': 'assets/images/can_large.png',
      'weight_grams': 22,
    },
  };

  static const Map<String, Map<String, dynamic>> glass = {
    'glass_small': {
      'name': 'Small Glass',
      'image': 'assets/images/glass_small.png',
      'weight_grams': 150,
    },
    'glass_medium': {
      'name': 'Medium Glass',
      'image': 'assets/images/glass_medium.png',
      'weight_grams': 200,
    },
    'glass_large': {
      'name': 'Large Glass',
      'image': 'assets/images/glass_large.png',
      'weight_grams': 300,
    },
  };

  static List<Map<String, dynamic>> getItemsByType(String type) {
    switch (type) {
      case 'plastic':
        return plastic.entries.map((e) => {'key': e.key, ...e.value, 'category': 'plastic'}).toList();
      case 'cans':
        return cans.entries.map((e) => {'key': e.key, ...e.value, 'category': 'cans'}).toList();
      case 'glass':
        return glass.entries.map((e) => {'key': e.key, ...e.value, 'category': 'glass'}).toList();
      default:
        return [];
    }
  }

  static Map<String, dynamic>? getItemByKey(String key) {
    if (plastic.containsKey(key)) return {'key': key, ...plastic[key]!, 'category': 'plastic'};
    if (cans.containsKey(key)) return {'key': key, ...cans[key]!, 'category': 'cans'};
    if (glass.containsKey(key)) return {'key': key, ...glass[key]!, 'category': 'glass'};
    return null;
  }

  static double calculateWeightInKg(String itemKey, int count) {
    final item = getItemByKey(itemKey);
    if (item == null) return 0.0;
    final weightGrams = item['weight_grams'] as int;
    return (weightGrams * count) / 1000.0;
  }

  static int calculatePoints(String itemKey, int count) {
    final item = getItemByKey(itemKey);
    if (item == null) return 0;
    final weightGrams = item['weight_grams'] as int;
    final totalGrams = weightGrams * count;
    return ((totalGrams / 100) * 10).round();
  }
}