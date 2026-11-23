import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';

class MyQRScreen extends StatefulWidget {
  const MyQRScreen({super.key});

  @override
  State<MyQRScreen> createState() => _MyQRScreenState();
}

class _MyQRScreenState extends State<MyQRScreen> {
  String qrData = '';

  @override
  void initState() {
    super.initState();
    _generateQRData();
  }

  void _generateQRData() {
    final user = FirebaseService.currentUser;
    if (user != null) {
      setState(() {
        qrData = 'TRASH_TO_CASH_USER_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseService.currentUser;
    final String email = user?.email ?? 'User';
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My QR Code'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyLarge?.color), onPressed: () => Navigator.pop(context)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _generateQRData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 20)],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.qr_code, size: 50, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    const Text('Your QR Code', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Text(email, style: TextStyle(fontSize: 16, color: theme.textTheme.bodyMedium?.color)),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: qrData.isNotEmpty
                          ? QrImageView(data: qrData, version: QrVersions.auto, size: 200)
                          : const CircularProgressIndicator(),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          const Icon(Icons.info, size: 20, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Show this QR code to the employee to earn points', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}