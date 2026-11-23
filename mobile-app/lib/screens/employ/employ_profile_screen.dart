import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';
import '../../providers/theme_provider.dart';
import '../dialogs/change_password_dialog.dart';
import '../dialogs/edit_name_screen.dart';

class EmployProfileScreen extends StatefulWidget {
  const EmployProfileScreen({super.key});

  @override
  State<EmployProfileScreen> createState() => _EmployProfileScreenState();
}

class _EmployProfileScreenState extends State<EmployProfileScreen> {
  final User? _user = FirebaseService.currentUser;
  bool _isLoading = true;
  int _totalScans = 0;
  double _totalWeight = 0.0;
  Timestamp? _lastScan;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadEmployeeData();
  }

  Future<void> _loadEmployeeData() async {
    if (_user == null) {
      _redirectToOnboarding();
      return;
    }
    setState(() => _isLoading = true);
    try {
      final stats = await FirebaseService.getEmployeeStats(_user!.uid);
      setState(() {
        _totalScans = stats['totalScans'] as int;
        _totalWeight = stats['totalWeight'] as double;
        _lastScan = stats['lastScan'] as Timestamp?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _redirectToOnboarding() {
    Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
      _uploadImage(File(pickedFile.path));
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    if (_user == null) return;
    setState(() => _isLoading = true);
    try {
      final imageUrl = await FirebaseService.uploadProfileImage(imageFile, _user!.uid);
      if (imageUrl != null && imageUrl.isNotEmpty) {
        await FirebaseService.updateUserProfile(userId: _user!.uid, profileImage: imageUrl);
        setState(() => _imageFile = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!'), backgroundColor: Colors.green, duration: Duration(seconds: 3)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary), child: const Text('Logout')),
        ],
      ),
    );
    if (shouldLogout == true) {
      await FirebaseService.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
      }
    }
  }

  void _changePassword() {
    showDialog(context: context, builder: (context) => const ChangePasswordDialog());
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
        title: const Text('Profile'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyLarge?.color), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: Icon(Icons.refresh, color: theme.textTheme.bodyLarge?.color), onPressed: _loadEmployeeData)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadEmployeeData,
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('employees').doc(_user!.uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return _buildErrorWidget();
            }
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final String firstName = data['firstName'] ?? '';
            final String lastName = data['lastName'] ?? '';
            final String fullName = '$firstName $lastName'.trim().isEmpty ? _user!.email?.split('@').first ?? 'Employee' : '$firstName $lastName';
            final String displayId = data['displayId'] ?? '';
            final String warehouseName = data['warehouseName'] ?? 'N/A';
            final String warehouseId = data['warehouseId'] ?? '';
            final String profileImageUrl = data['profileImage'] ?? '';
            final String employeeStatus = data['status'] ?? 'absent';

            Color statusColor;
            String statusText;
            switch (employeeStatus.toLowerCase()) {
              case 'shift':
                statusColor = Colors.green;
                statusText = 'SHIFT';
                break;
              case 'break':
                statusColor = Colors.orange;
                statusText = 'BREAK';
                break;
              default:
                statusColor = Colors.red;
                statusText = 'ABSENT';
                break;
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.grey, blurRadius: 10, offset: Offset(0, 4))],
                          ),
                          child: _imageFile != null
                              ? ClipOval(child: Image.file(_imageFile!, width: 120, height: 120, fit: BoxFit.cover))
                              : (profileImageUrl.isNotEmpty
                              ? ClipOval(
                            child: Image.network(
                              profileImageUrl,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: Center(child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'E', style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold))),
                                );
                              },
                            ),
                          )
                              : Center(child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'E', style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold)))),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 4)]),
                            child: const Icon(Icons.camera_alt, size: 20, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(fullName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                  const SizedBox(height: 4),
                  Text(_user!.email ?? '', style: TextStyle(fontSize: 16, color: theme.textTheme.bodyMedium?.color)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [Icon(Icons.badge, size: 16, color: AppColors.primary), const SizedBox(width: 4), Text(displayId, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary))],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [Icon(Icons.warehouse, size: 16, color: statusColor), const SizedBox(width: 4), Text(statusText, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: statusColor))],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: theme.cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Scans', '$_totalScans', Icons.qr_code, Colors.blue),
                          _buildStatItem('Weight', '${_totalWeight.toStringAsFixed(1)} kg', Icons.monitor_weight, Colors.orange),
                          _buildStatItem('Last', _lastScan != null ? DateFormat('dd/MM').format(_lastScan!.toDate()) : 'Never', Icons.history, Colors.green),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)]),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit, color: AppColors.primary),
                          title: const Text('Edit Name'),
                          subtitle: Text('$firstName $lastName', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                          trailing: IconButton(
                            icon: Icon(Icons.arrow_forward_ios, size: 16, color: theme.textTheme.bodySmall?.color),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => EditNameScreen(userId: _user!.uid, currentFirstName: firstName, currentLastName: lastName)),
                              );
                              if (result == true) setState(() {});
                            },
                          ),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: const Icon(Icons.lock, color: AppColors.primary),
                          title: const Text('Change Password'),
                          trailing: IconButton(icon: Icon(Icons.arrow_forward_ios, size: 16, color: theme.textTheme.bodySmall?.color), onPressed: _changePassword),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        Consumer<ThemeProvider>(
                          builder: (context, themeProvider, child) {
                            return SwitchListTile(
                              secondary: const Icon(Icons.dark_mode, color: AppColors.primary),
                              title: const Text('Dark Mode'),
                              value: themeProvider.isDarkMode,
                              onChanged: (_) => themeProvider.toggleTheme(),
                              activeColor: AppColors.primary,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('App Version 1.0.0', style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
        Text(label, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Failed to load user data', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: () => Navigator.pushReplacementNamed(context, '/onboarding'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary), child: const Text('Go to Login')),
        ],
      ),
    );
  }
}