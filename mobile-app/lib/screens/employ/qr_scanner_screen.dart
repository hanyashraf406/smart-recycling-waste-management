import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';
import 'material_input_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool isScanning = true;
  bool isProcessing = false;
  bool _hasShownStatusDialog = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _processQRScan(String qrData) async {
    if (isProcessing) return;

    final currentUser = FirebaseService.currentUser;
    if (currentUser != null) {
      final status = await FirebaseService.getEmployeeStatus(currentUser.uid);
      if (status == 'break' || status == 'absent') {
        if (mounted && !_hasShownStatusDialog) {
          _hasShownStatusDialog = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('لا يمكنك المسح'),
              content: Text('لا يمكنك المسح في هذه الحالة ($status)'),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    _hasShownStatusDialog = false;
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    setState(() {
      isProcessing = true;
      isScanning = false;
    });
    cameraController.stop();
    try {
      final List<String> parts = qrData.split('_');
      if (parts.length < 5 || parts[0] != 'TRASH' || parts[1] != 'TO' || parts[2] != 'CASH' || parts[3] != 'USER') {
        _showErrorDialog('Invalid QR Code format');
        return;
      }
      final String userId = parts[4];
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        _showErrorDialog('User not found');
        return;
      }
      final userData = userDoc.data()!;

      if (userData['isBlocked'] == true) {
        _showErrorDialog('This user account is blocked');
        return;
      }

      _showUserConfirmationDialog(userData, userId);
    } on FirebaseException catch (e) {
      _showErrorDialog('Firebase error: ${e.message}');
    } catch (e) {
      _showErrorDialog('Error processing scan: $e');
    }
  }

  void _showUserConfirmationDialog(Map<String, dynamic> userData, String userId) {
    final String userName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
    final String userEmail = userData['email'] as String? ?? 'Unknown';
    final String userDisplayId = userData['displayId'] ?? userId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('User Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.person, size: 50, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(userName.isEmpty ? 'User' : userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(userEmail, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(userDisplayId, style: TextStyle(fontSize: 12, color: AppColors.primary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('Points: ${userData['points'] ?? 0}', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeScanning();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/material-input', arguments: {'userId': userId, 'userData': userData});
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeScanning();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _resumeScanning() {
    if (!mounted) return;
    setState(() {
      isScanning = true;
      isProcessing = false;
    });
    cameraController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan User QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) async {
              if (!isScanning || isProcessing) return;
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String data = barcodes.first.rawValue ?? '';
                await _processQRScan(data);
              }
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black.withOpacity(0.7),
              child: const Column(
                children: [
                  Text('Scan User QR Code', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('Position the QR code in the frame', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
          ),
          if (isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            ),
        ],
      ),
      floatingActionButton: isScanning
          ? null
          : FloatingActionButton(
        onPressed: _resumeScanning,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}