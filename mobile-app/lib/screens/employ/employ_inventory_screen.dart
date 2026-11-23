import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';
import '../../services/material_service.dart';
import '../../widgets/trash_logo.dart';

class EmployInventoryScreen extends StatefulWidget {
  const EmployInventoryScreen({super.key});

  @override
  State<EmployInventoryScreen> createState() => _EmployInventoryScreenState();
}

class _EmployInventoryScreenState extends State<EmployInventoryScreen> {
  bool _isLoading = true;
  int _totalUsers = 0;
  int _totalOperations = 0;
  double _totalWeight = 0.0;
  Map<String, double> _materialQuantities = {};
  List<Map<String, dynamic>> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _loadInventoryData();
  }

  Future<void> _loadInventoryData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([_loadStatistics(), _loadMaterials(), _loadRecentScans()]);
    } catch (e) {
      print(e);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadStatistics() async {
    final stats = await FirebaseService.getInventoryStats();
    setState(() {
      _totalUsers = stats['totalUsers'] as int? ?? 0;
      _totalOperations = stats['totalOperations'] as int? ?? 0;
      _totalWeight = (stats['totalWeight'] as num?)?.toDouble() ?? 0.0;
    });
  }

  Future<void> _loadMaterials() async {
    final materials = await FirebaseService.getMaterialQuantities();
    setState(() => _materialQuantities = materials);
  }

  Future<void> _loadRecentScans() async {
    final scans = await FirebaseService.getRecentScans(limit: 10);
    setState(() => _recentScans = scans);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double totalMaterial = _materialQuantities.values.fold(0.0, (sum, w) => sum + w);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [TrashLogo(size: 40), const SizedBox(width: 8), const Text('Recycle Inventory')]),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyLarge?.color), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: Icon(Icons.refresh, color: theme.textTheme.bodyLarge?.color), onPressed: _loadInventoryData)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadInventoryData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _buildStatCard(title: 'Total Users', value: '$_totalUsers', icon: Icons.people, color: Colors.blue)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatCard(title: 'Total Scans', value: '$_totalOperations', icon: Icons.qr_code, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatCard(title: 'Total Weight', value: '${_totalWeight.toStringAsFixed(2)} kg', icon: Icons.monitor_weight, color: Colors.orange),
              const SizedBox(height: 24),
              const Text('Materials', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              if (_materialQuantities.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
                  child: Center(child: Text('No materials yet', style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
                )
              else
                ..._materialQuantities.entries.map((entry) {
                  final color = MaterialService.getMaterialColor(entry.key);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildMaterialCard(
                      title: MaterialService.getMaterialName(entry.key),
                      weight: entry.value,
                      color: color,
                      percentage: totalMaterial > 0 ? entry.value / totalMaterial : 0,
                    ),
                  );
                }),
              const SizedBox(height: 24),
              const Text('Recent Scans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _recentScans.isEmpty
                  ? Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
                child: Center(child: Text('No scans yet', style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
              )
                  : Column(children: _recentScans.map((scan) => _buildScanItem(scan)).toList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon, required Color color}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 24, color: color)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
                Text(title, style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCard({required String title, required double weight, required Color color, required double percentage}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                ],
              ),
              Text('${weight.toStringAsFixed(2)} kg', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: percentage, backgroundColor: color.withOpacity(0.1), valueColor: AlwaysStoppedAnimation<Color>(color)),
        ],
      ),
    );
  }

  Widget _buildScanItem(Map<String, dynamic> scan) {
    final theme = Theme.of(context);
    final date = DateFormat('MMM dd, HH:mm').format((scan['scannedAt'] as Timestamp).toDate());
    final materials = scan['materialsWeight'] as Map<String, dynamic>? ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.person, size: 20, color: AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(scan['userName'] ?? 'Unknown', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                        const SizedBox(width: 8),
                        Text(scan['userDisplayId'] ?? '', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Text('${(scan['totalWeightKg'] as double?)?.toStringAsFixed(2)} kg • ${scan['totalPoints']} pts', style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(date, style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(scan['processId'] ?? '', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: materials.entries.map((entry) {
              final weight = (entry.value as num).toDouble();
              if (weight <= 0) return const SizedBox.shrink();
              final color = MaterialService.getMaterialColor(entry.key);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${MaterialService.getMaterialName(entry.key)}: ${weight.toStringAsFixed(2)} kg',
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}