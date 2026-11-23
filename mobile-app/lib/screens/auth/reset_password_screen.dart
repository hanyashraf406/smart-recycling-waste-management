import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../models/app_colors.dart';
import '../../widgets/trash_logo.dart';
import 'role_selection_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _handleResetPassword() async {
    if (_newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill all fields');
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }
    if (_newPasswordController.text.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = ''; });

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('resetPasswordV2');

      final result = await callable.call(<String, dynamic>{
        'email': widget.email.trim(),
        'newPassword': _newPasswordController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed! Please sign in.'), backgroundColor: Colors.green),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
        Navigator.pushReplacementNamed(context, '/role-selection');
      }
    } catch (e) {
      if (mounted) {
        String msg = '$e';
        if (msg.length > 100) msg = msg.substring(0, 100) + '...';
        setState(() => _errorMessage = msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.textTheme.bodyLarge?.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Center(child: TrashLogo(size: 100)),
              const SizedBox(height: 24),
              const Icon(Icons.lock_reset, size: 48, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Create New Password',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.email,
                style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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
                controller: _newPasswordController,
                obscureText: true,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.lock_outline, color: theme.textTheme.bodyMedium?.color),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.lock_outline, color: theme.textTheme.bodyMedium?.color),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleResetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('RESET PASSWORD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}