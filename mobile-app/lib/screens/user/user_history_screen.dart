import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';
import '../../services/material_service.dart';
import '../../widgets/trash_logo.dart';

class UserHistoryScreen extends StatefulWidget {
  const UserHistoryScreen({super.key});

  @override
  State<UserHistoryScreen> createState() => _UserHistoryScreenState();
}

class _UserHistoryScreenState extends State<UserHistoryScreen> {
  final User? _user = FirebaseService.currentUser;
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (_user == null) {
      _redirectToOnboarding();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('recycling_processes')
          .where('userId', isEqualTo: _user!.uid)
          .orderBy('scannedAt', descending: true)
          .get();

      final transactions = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'processId': data['processId'] ?? doc.id,
          'employeeEmail': data['employeeEmail'] ?? 'Unknown Employee',
          'employeeDisplayId': data['employeeDisplayId'] ?? '',
          'totalPoints': data['totalPoints'] ?? 0,
          'totalWeightKg': (data['totalWeightKg'] as num?)?.toDouble() ?? 0.0,
          'materialsWeight': data['materialsWeight'] as Map<String, dynamic>? ?? {},
          'scannedAt': data['scannedAt'] as Timestamp? ?? Timestamp.now(),
          'status': data['status'] as String? ?? 'Done',
        };
      }).toList();

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading history: $e';
        _isLoading = false;
      });
    }
  }

  void _redirectToOnboarding() {
    Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _redirectToOnboarding());
      return const SizedBox();
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My History'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyLarge?.color), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory)],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildErrorView()
            : _transactions.isEmpty
            ? _buildEmptyView()
            : _buildTransactionsList(),
      ),
    );
  }

  Widget _buildErrorView() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                const SizedBox(height: 8),
                Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadHistory, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary), child: const Text('Try Again')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const TrashLogo(size: 80),
                const SizedBox(height: 24),
                Text('No transactions yet', style: TextStyle(fontSize: 18, color: theme.textTheme.bodyMedium?.color)),
                const SizedBox(height: 8),
                Text('Your recycling history will appear here', style: TextStyle(fontSize: 14, color: theme.textTheme.bodySmall?.color)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadHistory, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary), child: const Text('Refresh')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    final theme = Theme.of(context);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final materials = tx['materialsWeight'] as Map<String, dynamic>;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(_formatDate(tx['scannedAt']), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text(tx['processId'] ?? '', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Employee: ${tx['employeeEmail']}', style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text('${tx['totalPoints']} pts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Weight:', style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
                    Text('${(tx['totalWeightKg'] as double).toStringAsFixed(2)} kg', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Materials:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: materials.entries.map((entry) {
                    final type = entry.key;
                    final weight = (entry.value as num).toDouble();
                    if (weight <= 0) return const SizedBox.shrink();
                    final color = MaterialService.getMaterialColor(type);
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text('${MaterialService.getMaterialName(type)}: ${weight.toStringAsFixed(2)} kg', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}