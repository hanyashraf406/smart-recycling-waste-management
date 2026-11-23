import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/app_colors.dart';
import '../../models/store_data.dart';
import '../../services/firebase_service.dart';
import '../../services/recharge_service.dart';

class WaterBillsScreen extends StatefulWidget {
  const WaterBillsScreen({super.key});

  @override
  State<WaterBillsScreen> createState() => _WaterBillsScreenState();
}

class _WaterBillsScreenState extends State<WaterBillsScreen> {
  String? _selectedCompany;
  final _cardNumberController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;
  final User? _user = FirebaseService.currentUser;

  Future<void> _processPayment() async {
    if (_selectedCompany == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a company'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_cardNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter card number'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter amount'), backgroundColor: Colors.red),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid amount'), backgroundColor: Colors.red),
      );
      return;
    }

    final requiredPoints = StoreData.calculateRequiredPoints(amount);
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.uid).get();
    final currentPoints = (userDoc.data()?['points'] as num?)?.toInt() ?? 0;

    if (currentPoints < requiredPoints) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('نقاط غير كافية'),
            content: Text('لديك $currentPoints نقطة. تحتاج $requiredPoints نقطة لدفع ${amount.toStringAsFixed(2)} جنيه.'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('موافق'),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await RechargeService.processRecharge(
        userId: _user!.uid,
        serviceType: 'water',
        companyName: _selectedCompany!,
        cardNumber: _cardNumberController.text.trim(),
        amountEgp: amount,
        pointsUsed: requiredPoints,
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('تم الدفع بنجاح'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 64),
                const SizedBox(height: 16),
                Text('تم خصم $requiredPoints نقطة', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('المتبقي: ${result['remainingPoints']} نقطة'),
                Text('رقم العملية: ${result['transactionId']}'),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('تم'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final companies = StoreData.getAllCompanies('water');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Water Bills'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyLarge?.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.water, Color(0xFF1565C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.water_drop, color: Colors.white, size: 40),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Water Bills', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                      Text('1 Point = 0.05 EGP', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Select Company', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCompany,
                  isExpanded: true,
                  hint: const Text('Select water company'),
                  items: companies.map((company) {
                    return DropdownMenuItem<String>(
                      value: company,
                      child: Text(company, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedCompany = value),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cardNumberController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                labelText: 'Card Number / Subscriber Number',
                labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.credit_card, color: AppColors.water),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                labelText: 'Amount (EGP)',
                labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: Icon(Icons.money, color: AppColors.water),
                suffixText: 'EGP',
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 8),
            if (_amountController.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.water.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.water, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Points required: ${StoreData.calculateRequiredPoints(double.tryParse(_amountController.text) ?? 0)}',
                      style: TextStyle(color: AppColors.water, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.water,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Pay Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}