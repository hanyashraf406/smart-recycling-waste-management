class StoreData {
  static const double pointsToEgpRate = 0.05;
  static const double egpToPointsRate = 20.0;

  static int calculateRequiredPoints(double amountEgp) {
    return (amountEgp * egpToPointsRate).ceil();
  }

  static double calculateEgpValue(int points) {
    return points * pointsToEgpRate;
  }

  static const Map<String, List<String>> waterCompanies = {
    'Cairo': ['شركة مياه الشرب بالقاهرة الكبرى'],
    'Giza': ['شركة مياه الشرب والصرف الصحي بالجيزة'],
    'Alexandria': ['شركة مياه الشرب بالإسكندرية'],
    'Qalyubia': ['شركة مياه الشرب والصرف الصحي بالقليوبية'],
    'Daqahlia': ['شركة مياه الشرب والصرف الصحي بالدقهلية'],
    'Gharbia': ['شركة مياه الشرب والصرف الصحي بالغربية'],
    'Monufia': ['شركة مياه الشرب والصرف الصحي بالمنوفية'],
    'Sharqia': ['شركة مياه الشرب والصرف الصحي بالشرقية'],
    'Beheira': ['شركة مياه الشرب والصرف الصحي بالبحيرة'],
    'Kafr El Sheikh': ['شركة مياه الشرب والصرف الصحي بكفر الشيخ'],
    'Damietta': ['شركة مياه الشرب والصرف الصحي بدمياط'],
    'Port Said': ['شركة مياه الشرب والصرف الصحي بمحافظات القناة - بورسعيد'],
    'Ismailia': ['شركة مياه الشرب والصرف الصحي بمحافظات القناة - الإسماعيلية'],
    'Suez': ['شركة مياه الشرب والصرف الصحي بمحافظات القناة - السويس'],
    'North Sinai': ['شركة مياه الشرب والصرف الصحي بشمال سيناء'],
    'South Sinai': ['شركة مياه الشرب والصرف الصحي بجنوب سيناء'],
    'Matrouh': ['شركة مياه الشرب والصرف الصحي بمطروح'],
    'Fayoum': ['شركة مياه الشرب والصرف الصحي بالفيوم'],
    'Beni Suef': ['شركة مياه الشرب والصرف الصحي ببني سويف'],
    'Minya': ['شركة مياه الشرب والصرف الصحي بالمنيا'],
    'Asyut': ['شركة مياه الشرب والصرف الصحي بأسيوط'],
    'New Valley': ['شركة مياه الشرب والصرف الصحي بالوادي الجديد'],
    'Sohag': ['شركة مياه الشرب والصرف الصحي بسوهاج'],
    'Qena': ['شركة مياه الشرب والصرف الصحي بقنا'],
    'Luxor': ['شركة مياه الشرب والصرف الصحي بالأقصر'],
    'Aswan': ['شركة مياه الشرب والصرف الصحي بأسوان'],
    'Red Sea': ['شركة مياه الشرب والصرف الصحي بالبحر الأحمر'],
  };

  static const Map<String, List<String>> electricityCompanies = {
    'Cairo': [
      'شركة شمال القاهرة لتوزيع الكهرباء',
      'شركة جنوب القاهرة لتوزيع الكهرباء',
    ],
    'Alexandria': [
      'شركة الإسكندرية لتوزيع الكهرباء',
    ],
    'Delta': [
      'شركة شمال الدلتا لتوزيع الكهرباء',
      'شركة جنوب الدلتا لتوزيع الكهرباء',
    ],
    'Middle Delta': [
      'شركة وسط الدلتا لتوزيع الكهرباء',
    ],
    'Canal': [
      'شركة القناة لتوزيع الكهرباء',
    ],
    'Beheira': [
      'شركة البحيرة لتوزيع الكهرباء',
    ],
    'Upper Egypt': [
      'شركة مصر الوسطى لتوزيع الكهرباء',
      'شركة مصر العليا لتوزيع الكهرباء',
    ],
  };

  static const Map<String, List<String>> gasCompanies = {
    'Cairo & Giza': [
      'غاز مصر - القاهرة والجيزة',
      'سيتي غاز',
      'غازتك - القاهرة',
      'بتروجيت للغاز - القاهرة',
    ],
    'Alexandria': [
      'غاز مصر - الإسكندرية',
      'غازتك - الإسكندرية',
    ],
    'Delta': [
      'غاز مصر - الدلتا',
      'نات غاز',
      'غازتك - الدلتا',
    ],
    'Canal & Sinai': [
      'غاز مصر - القناة وسيناء',
      'سيتي غاز - القناة',
    ],
    'Upper Egypt': [
      'غاز مصر - الصعيد',
      'غازتك - الصعيد',
    ],
    'Red Sea': [
      'غاز مصر - البحر الأحمر',
    ],
  };

  static List<String> getAllCompanies(String type) {
    switch (type) {
      case 'water':
        return waterCompanies.values.expand((list) => list).toList();
      case 'electricity':
        return electricityCompanies.values.expand((list) => list).toList();
      case 'gas':
        return gasCompanies.values.expand((list) => list).toList();
      default:
        return [];
    }
  }

  static List<String> getCompaniesByRegion(String type, String region) {
    switch (type) {
      case 'water':
        return waterCompanies[region] ?? [];
      case 'electricity':
        return electricityCompanies[region] ?? [];
      case 'gas':
        return gasCompanies[region] ?? [];
      default:
        return [];
    }
  }
}