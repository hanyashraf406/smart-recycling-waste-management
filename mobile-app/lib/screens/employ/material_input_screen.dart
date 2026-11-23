import 'package:flutter/material.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';
import '../../services/material_service.dart';

class MaterialInputScreen extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> userData;

  const MaterialInputScreen({
    super.key,
    required this.userId,
    required this.userData,
  });

  @override
  State<MaterialInputScreen> createState() => _MaterialInputScreenState();
}

class _MaterialInputScreenState extends State<MaterialInputScreen> {
  String _selectedMainType = '';
  final Map<String, int> _itemCounts = {};
  final List<Map<String, dynamic>> _selectedItems = [];
  bool _isLoading = false;
  bool _materialsLoaded = false;
  List<String> _materialTypes = [];

  @override
  void initState() {
    super.initState();
    _loadMaterialsFromFirestore();
  }

  Future<void> _loadMaterialsFromFirestore() async {
    setState(() => _isLoading = true);
    await MaterialService.loadMaterials();
    if (mounted) {
      setState(() {
        _materialsLoaded = true;
        _isLoading = false;
        _materialTypes = MaterialService.getMaterialTypes();
        if (_materialTypes.isNotEmpty) {
          _selectedMainType = _materialTypes.first;
        }
      });
    }
  }

  double get totalWeight {
    double weight = 0.0;
    for (var item in _selectedItems) {
      weight += MaterialService.calculateWeightInKg(
        item['itemKey'] as String,
        item['count'] as int,
      );
    }
    return weight;
  }

  int get totalPoints {
    int points = 0;
    for (var item in _selectedItems) {
      points += MaterialService.calculatePoints(
        item['itemKey'] as String,
        item['count'] as int,
      );
    }
    return points;
  }

  int get totalItemsCount {
    int count = 0;
    for (var item in _selectedItems) {
      count += item['count'] as int;
    }
    return count;
  }

  void _showQuantityDialog(String itemKey, int currentCount) {
    final TextEditingController controller = TextEditingController(text: currentCount.toString());
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Enter Quantity', style: TextStyle(color: MaterialService.getMaterialColor(_selectedMainType), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter quantity',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: MaterialService.getMaterialColor(_selectedMainType), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              int newQuantity = int.tryParse(controller.text) ?? 0;
              if (newQuantity > 0) {
                setState(() => _itemCounts[itemKey] = newQuantity);
              } else {
                setState(() => _itemCounts.remove(itemKey));
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: MaterialService.getMaterialColor(_selectedMainType)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTransaction() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item'), backgroundColor: AppColors.error),
      );
      return;
    }

    final currentUser = FirebaseService.currentUser;
    if (currentUser != null) {
      final status = await FirebaseService.getEmployeeStatus(currentUser.uid);
      if (status == 'break' || status == 'absent') {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('لا يمكنك حفظ العملية'),
            content: Text('لا يمكنك حفظ العملية في هذه الحالة ($status)'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Done'),
              ),
            ],
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final String qrData = 'TRASH_TO_CASH_USER_${widget.userId}_${DateTime.now().millisecondsSinceEpoch}';

      await FirebaseService.saveRecyclingTransaction(
        userId: widget.userId,
        qrData: qrData,
        items: _selectedItems,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Success!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 64),
              const SizedBox(height: 16),
              const Text('Recycling completed successfully', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Text('$totalPoints points added', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
              const SizedBox(height: 16),
              const Text('Redirecting to home...', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/employ-home');
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Error saving transaction: $e'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_materialsLoaded) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Loading Materials...'), backgroundColor: theme.appBarTheme.backgroundColor, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final items = MaterialService.getItemsByType(_selectedMainType);
    final String userName = '${widget.userData['firstName'] ?? ''} ${widget.userData['lastName'] ?? ''}'.trim();
    final String userDisplayId = widget.userData['displayId'] ?? widget.userId;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Add Recycling Items', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.textTheme.bodyLarge?.color, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primary.withOpacity(0.1),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName.isEmpty ? 'User' : userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      Row(
                        children: [
                          Text(userDisplayId, style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          Text('Points: ${widget.userData['points'] ?? 0}', style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _materialTypes.map((type) {
                        final isSelected = _selectedMainType == type;
                        final color = MaterialService.getMaterialColor(type);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedMainType = type;
                                _itemCounts.clear();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: isSelected ? color : theme.cardColor,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(color: isSelected ? color : theme.dividerColor),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    MaterialService.getMaterialIcon(type),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    MaterialService.getMaterialName(type),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Select Size', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
                  const SizedBox(height: 4),
                  Text('Choose the size and quantity', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                  const SizedBox(height: 16),
                  items.isEmpty
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text('No sizes available for this material', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final itemKey = item['key'] as String;
                      final count = _itemCounts[itemKey] ?? 0;
                      final color = MaterialService.getMaterialColor(_selectedMainType);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
                          border: Border.all(color: count > 0 ? color : theme.dividerColor, width: count > 0 ? 2 : 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(10)),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.asset(
                                        item['image'] ?? 'assets/images/placeholder.png',
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                            child: Center(
                                              child: Text(item['name']?[0] ?? '?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['name'] ?? 'Unknown', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                              child: Text('${item['weight_grams']}g', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                              child: Text('${MaterialService.calculatePoints(itemKey, 1)} pts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber[800])),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          setState(() {
                                            if (_itemCounts.containsKey(itemKey)) {
                                              if (_itemCounts[itemKey]! > 0) {
                                                _itemCounts[itemKey] = _itemCounts[itemKey]! - 1;
                                              }
                                              if (_itemCounts[itemKey] == 0) {
                                                _itemCounts.remove(itemKey);
                                              }
                                            }
                                          });
                                        },
                                        icon: const Icon(Icons.remove_circle_outline),
                                        color: Colors.red,
                                        iconSize: 28,
                                      ),
                                      GestureDetector(
                                        onTap: () => _showQuantityDialog(itemKey, count),
                                        child: Container(
                                          width: 50,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: color.withOpacity(0.3), width: 1),
                                          ),
                                          child: Center(
                                            child: Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => setState(() => _itemCounts[itemKey] = (_itemCounts[itemKey] ?? 0) + 1),
                                        icon: Icon(Icons.add_circle),
                                        color: color,
                                        iconSize: 28,
                                      ),
                                    ],
                                  ),
                                  if (count > 0)
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _selectedItems.add({'itemKey': itemKey, 'count': count});
                                          _itemCounts.remove(itemKey);
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: color,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(60, 36),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      ),
                                      child: const Text('ADD'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_selectedItems.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Selected Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                child: Text('$totalItemsCount items', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._selectedItems.map((item) {
                            final itemData = MaterialService.getItemByKey(item['itemKey'] as String);
                            final count = item['count'] as int;
                            final weight = MaterialService.calculateWeightInKg(item['itemKey'] as String, count);
                            final points = MaterialService.calculatePoints(item['itemKey'] as String, count);
                            final category = itemData?['category'] ?? 'unknown';
                            final color = MaterialService.getMaterialColor(category);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.dark ? Colors.grey[700] : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.dividerColor),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(8)),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        itemData?['image'] ?? 'assets/images/placeholder.png',
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Center(
                                            child: Text(itemData?['name']?[0] ?? '?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${itemData?['name'] ?? 'Unknown'} × $count', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            Text('${(weight * 1000).toStringAsFixed(0)}g', style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                              child: Text('$points pts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => setState(() => _selectedItems.remove(item)),
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const Divider(height: 20),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Weight:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                    Text(
                                      totalWeight >= 1.0 ? '${totalWeight.toStringAsFixed(2)} kg' : '${(totalWeight * 1000).toStringAsFixed(0)} g',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Points:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                    Text('$totalPoints', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_selectedItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveTransaction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('DONE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}