import 'package:flutter/material.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';
import 'loading_screen.dart';
import 'onboarding_screen.dart';
import 'role_selection_screen.dart';
import '../user/user_home_screen.dart';
import '../employ/employ_home_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    final user = FirebaseService.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/onboarding');
    } else {
      try {
        final role = await FirebaseService.getUserRole(user.uid);
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        if (role == 'employ' || role == 'admin') {
          Navigator.pushReplacementNamed(context, '/employ-home');
        } else {
          Navigator.pushReplacementNamed(context, '/user-home');
        }
      } catch (e) {
        Navigator.pushReplacementNamed(context, '/role-selection');
      }
    }
    if (mounted) setState(() => _isCheckingAuth = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) return const LoadingScreen();
    return const Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }
}