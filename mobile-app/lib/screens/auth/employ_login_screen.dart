import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';
import '../../widgets/trash_logo.dart';
import 'employ_signup_screen.dart';
import 'employ_forgot_password_screen.dart';
import 'role_selection_screen.dart';

class EmployLoginScreen extends StatefulWidget {
  const EmployLoginScreen({super.key});

  @override
  State<EmployLoginScreen> createState() => _EmployLoginScreenState();
}

class _EmployLoginScreenState extends State<EmployLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _errorMessage = '';
  Timer? _locationTimer;

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill all fields');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final user = await FirebaseService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        'employ',
      );
      if (user != null) {
        if (!mounted) return;

        final status = await FirebaseService.getEmployeeStatus(user.uid);
        if (status == 'absent') {
          await FirebaseService.signOut();
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('حساب غير نشط'),
                content: const Text('حسابك غير نشط حالياً. يرجى التواصل مع المسؤول.'),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _isLoading = false;
                      });
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

        _requestLocationPermission(user.uid);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!'), backgroundColor: Colors.green),
        );
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/employ-home');
      } else {
        setState(() => _errorMessage = 'Invalid email or password');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Login failed. Please try again.');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _requestLocationPermission(String employeeId) async {
    try {
      var status = await Permission.location.request();
      if (status.isGranted) {
        _startLocationTracking(employeeId);
      }
    } catch (e) {}
  }

  void _startLocationTracking(String employeeId) {
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await FirebaseService.updateEmployeeLocation(
          employeeId,
          position.latitude,
          position.longitude,
        );
      } catch (e) {}
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const Center(child: TrashLogo(size: 120)),
                const SizedBox(height: 32),
                Text('Employee Login', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Access employee dashboard', style: TextStyle(fontSize: 16, color: theme.textTheme.bodyMedium?.color), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Text(_errorMessage, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
                  ),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    labelText: 'Employee Email',
                    labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                    prefixIcon: Icon(Icons.email_outlined, color: theme.textTheme.bodyMedium?.color),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                    prefixIcon: Icon(Icons.lock_outline, color: theme.textTheme.bodyMedium?.color),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: theme.textTheme.bodyMedium?.color),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/employ-forgot'),
                    child: Text('Forgot Password?', style: TextStyle(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Don\'t have an account? ', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/employ-signup'),
                      child: Text('Sign Up', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/role-selection'),
                  child: Text('← Choose different role', style: TextStyle(color: Colors.blue)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}