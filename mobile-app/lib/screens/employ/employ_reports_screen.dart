import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';
import '../../services/material_service.dart';
import '../../widgets/trash_logo.dart';

class EmployReportsScreen extends StatefulWidget {
  const EmployReportsScreen({super.key});

  @override
  State<EmployReportsScreen> createState() => _EmployReportsScreenState();
}

class _EmployReportsScreenState extends State<EmployReportsScreen> {
  bool _isLoading = true;
  String _selectedPeriod = 'day';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  int _totalScans = 0;
  double _totalWeight = 0.0;
  int _totalPoints = 0;
  int _totalUsers = 0;
  Map<String, double> _materialWeights = {};
  List<Map<String, dynamic>> _topUsers = [];
  List<Map<String, dynamic>> _myReports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      switch (_selectedPeriod) {
        case 'day':
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = now;
          break;
        case 'week':
          _startDate = now.subtract(Duration(days: now.weekday - 1));
          _endDate = now;
          break;
        case 'month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = now;
          break;
      }
      await Future.wait([_loadStatistics(), _loadTopUsers(), _loadMyReports()]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStatistics() async {
    final user = FirebaseService.currentUser;
    if (user == null) return;

    final scansSnapshot = await FirebaseFirestore.instance
        .collection('recycling_processes')
        .where('employeeId', isEqualTo: user.uid)
        .where('scannedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
        .where('scannedAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate))
        .get();

    int totalScans = 0;
    double totalWeight = 0.0;
    int totalPoints = 0;
    Map<String, double> materialsWeight = {};
    final uniqueUsers = <String>{};

    for (var doc in scansSnapshot.docs) {
      final data = doc.data();

      if (_selectedPeriod == 'day') {
        final bool isReported = data['reported'] == true;
        if (isReported) continue;
      }

      totalScans++;
      totalWeight += (data['totalWeightKg'] as num?)?.toDouble() ?? 0.0;
      totalPoints += (data['totalPoints'] as num?)?.toInt() ?? 0;
      uniqueUsers.add(data['userId'] as String);

      final matWeight = data['materialsWeight'] as Map<String, dynamic>? ?? {};
      for (var entry in matWeight.entries) {
        materialsWeight[entry.key] = (materialsWeight[entry.key] ?? 0.0) + (entry.value as num).toDouble();
      }
    }

    if (mounted) {
      setState(() {
        _totalScans = totalScans;
        _totalWeight = totalWeight;
        _totalPoints = totalPoints;
        _totalUsers = uniqueUsers.length;
        _materialWeights = materialsWeight;
      });
    }
  }

  Future<void> _loadTopUsers() async {
    final users = await FirebaseService.getScannedUsers();
    users.sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));
    if (mounted) {
      setState(() => _topUsers = users.take(5).toList());
    }
  }

  Future<void> _loadMyReports() async {
    final user = FirebaseService.currentUser;
    if (user != null) {
      final reports = await FirebaseService.getEmployeeReports(user.uid);
      if (mounted) {
        setState(() => _myReports = reports);
      }
    }
  }

  Future<void> _submitDailyReport() async {
    final user = FirebaseService.currentUser;
    if (user == null) return;

    final materials = await FirebaseService.getMaterialQuantities();
    final totalMaterial = materials.values.fold(0.0, (sum, w) => sum + w);

    if (totalMaterial <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No materials to report'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final TextEditingController notesController = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Daily Report'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Total Points Today: $_totalPoints', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const Text('Materials:', style: TextStyle(fontWeight: FontWeight.w600)),
              ...materials.entries.map((e) => Text('${MaterialService.getMaterialName(e.key)}: ${e.value.toStringAsFixed(2)} kg')),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 100),
                child: SingleChildScrollView(
                  child: TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (mounted) setState(() => _isLoading = true);
              try {
                await FirebaseService.createDailyReport(
                  employeeId: user.uid,
                  materials: materials,
                  notes: notesController.text.trim(),
                );
                await _loadMyReports();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted successfully'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double totalMaterial = _materialWeights.values.fold(0.0, (sum, w) => sum + w);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [const TrashLogo(size: 40), const SizedBox(width: 8), const Text('Reports')]),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyLarge?.color), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: Icon(Icons.refresh, color: theme.textTheme.bodyLarge?.color), onPressed: _loadReports),
          IconButton(icon: Icon(Icons.send, color: theme.textTheme.bodyLarge?.color), onPressed: _submitDailyReport),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadReports,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Period', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPeriodChip('Today', 'day'),
                          const SizedBox(width: 8),
                          _buildPeriodChip('This Week', 'week'),
                          const SizedBox(width: 8),
                          _buildPeriodChip('This Month', 'month'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('From: ${DateFormat('dd MMM yyyy').format(_startDate)}', style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                        Text('To: ${DateFormat('dd MMM yyyy').format(_endDate)}', style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildStatBox('Total Scans', '$_totalScans', Icons.qr_code, Colors.blue),
                  _buildStatBox('Total Weight', '${_totalWeight.toStringAsFixed(2)} kg', Icons.monitor_weight, Colors.orange),
                  _buildStatBox('Total Points', '$_totalPoints', Icons.stars, AppColors.primary),
                  _buildStatBox('Total Users', '$_totalUsers', Icons.people, Colors.purple),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Material Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    if (_materialWeights.isEmpty)
                      Text('No data for this period', style: TextStyle(color: theme.textTheme.bodyMedium?.color))
                    else
                      ...(_materialWeights.entries.map((entry) {
                        final color = MaterialService.getMaterialColor(entry.key);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(MaterialService.getMaterialName(entry.key), style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color))),
                              Text('${entry.value.toStringAsFixed(2)} kg', style: TextStyle(fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                            ],
                          ),
                        );
                      })),
                    const SizedBox(height: 16),
                    if (totalMaterial > 0)
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _materialWeights.entries.map((entry) {
                          final percentage = totalMaterial > 0 ? (entry.value / totalMaterial) * 100 : 0;
                          return Column(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: MaterialService.getMaterialColor(entry.key), width: 8),
                                ),
                                child: Center(
                                  child: Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: MaterialService.getMaterialColor(entry.key))),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(entry.key, style: TextStyle(fontSize: 12, color: theme.textTheme.bodyLarge?.color)),
                            ],
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Top Users', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
                child: _topUsers.isEmpty
                    ? Center(child: Text('No users yet', style: TextStyle(color: theme.textTheme.bodyMedium?.color)))
                    : Column(
                  children: List.generate(_topUsers.length, (index) {
                    final user = _topUsers[index];
                    final String fullName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
                    final Map<String, dynamic> userMaterials = user['materialsWeight'] as Map<String, dynamic>? ?? {};
                    final double userWeight = userMaterials.entries.fold(0.0, (sum, e) => sum + (e.value as num).toDouble());

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                            child: Center(child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(fullName.isEmpty ? 'User' : fullName, style: TextStyle(fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                                    const SizedBox(width: 8),
                                    Text(user['displayId'] ?? '', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                Text(user['email'], style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${user['points']} pts', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${userWeight.toStringAsFixed(2)} kg', style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),
              if (_myReports.isNotEmpty) ...[
                const Text('My Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _myReports.length,
                    itemBuilder: (context, index) {
                      final report = _myReports[index];
                      final status = report['status'] as String? ?? 'pending';
                      final createdAt = report['createdAt'] as Timestamp?;

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: status == 'approved' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(status == 'approved' ? Icons.check_circle : Icons.pending, color: status == 'approved' ? Colors.green : Colors.orange),
                        ),
                        title: Text('${report['reportType'] ?? 'Daily'} Report', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${(report['totalWeight'] as double?)?.toStringAsFixed(2) ?? '0.00'} kg • ${report['totalPoints'] ?? 0} pts'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: status == 'approved' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: status == 'approved' ? Colors.green : Colors.orange)),
                            ),
                            if (createdAt != null)
                              Text(DateFormat('dd/MM/yy').format(createdAt.toDate()), style: TextStyle(fontSize: 10, color: theme.textTheme.bodySmall?.color)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final theme = Theme.of(context);
    final isSelected = _selectedPeriod == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPeriod = value;
          _loadReports();
        });
      },
      backgroundColor: theme.brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[100],
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(color: isSelected ? AppColors.primary : theme.textTheme.bodyLarge?.color),
    );
  }

  Widget _buildStatBox(String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
          Text(title, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
        ],
      ),
    );
  }
}