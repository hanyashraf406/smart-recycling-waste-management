import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';
import '../../providers/theme_provider.dart';
import '../dialogs/change_password_dialog.dart';
import '../dialogs/edit_name_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final User? _user = FirebaseService.currentUser;
  bool _isLoading = true;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_user == null) {
      _redirectToOnboarding();
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseService.getUserData(_user!.uid);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture updated successfully!'), backgroundColor: Colors.green, duration: Duration(seconds: 3)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
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
        actions: [IconButton(icon: Icon(Icons.refresh, color: theme.textTheme.bodyLarge?.color), onPressed: () => setState(() {}))],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
        stream: FirebaseService.getUserStream(_user!.uid),
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
          final String fullName = '$firstName $lastName'.trim().isEmpty ? _user!.email?.split('@').first ?? 'User' : '$firstName $lastName';
          final String displayId = data['displayId'] ?? _user!.uid;
          final String profileImageUrl = data['profileImage'] ?? '';
          final int totalPoints = (data['points'] as num?)?.toInt() ?? 0;
          final int totalScans = (data['totalScans'] as num?)?.toInt() ?? 0;
          final int totalItems = (data['totalItems'] as num?)?.toInt() ?? 0;
          final bool isBlocked = data['isBlocked'] ?? false;

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
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
                            child: FadeInImage(
                              placeholder: const AssetImage('assets/images/placeholder.png'),
                              image: NetworkImage(profileImageUrl),
                              fit: BoxFit.cover,
                              width: 120,
                              height: 120,
                              imageErrorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 60),
                            ),
                          )
                              : Center(child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold)))),
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
                      if (isBlocked) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.red, width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [Icon(Icons.block, size: 16, color: Colors.red), SizedBox(width: 4), Text('BLOCKED', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red))],
                          ),
                        ),
                      ],
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
                          _buildStatItem('Points', '$totalPoints', Icons.stars, Colors.amber),
                          _buildStatItem('Scans', '$totalScans', Icons.qr_code, Colors.blue),
                          _buildStatItem('Items', '$totalItems', Icons.recycling, AppColors.primary),
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
            ),
          );
        },
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