import 'package:flutter/material.dart';
import '../../models/app_colors.dart';
import '../../services/otp_service.dart';
import '../../widgets/trash_logo.dart';
import 'otp_verification_screen.dart';

class EmployForgotPasswordScreen extends StatefulWidget {
  const EmployForgotPasswordScreen({super.key});

  @override
  State<EmployForgotPasswordScreen> createState() => _EmployForgotPasswordScreenState();
}

class _EmployForgotPasswordScreenState extends State<EmployForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String _message = '';

  Future<void> _handleReset() async {
    if (_emailController.text.isEmpty) {
      setState(() => _message = 'Please enter your email');
      return;
    }
    setState(() {
      _isLoading = true;
      _message = '';
    });

    final success = await OTPService.sendOTP(_emailController.text.trim());

    if (mounted) {
      if (success) {
        Navigator.pushNamed(context, '/otp-verification', arguments: {
          'email': _emailController.text.trim(),
        });
      } else {
        setState(() => _message = 'Failed to send OTP. Please try again.');
      }
      setState(() => _isLoading = false);
    }
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
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: theme.textTheme.bodyLarge?.color), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Center(child: TrashLogo(size: 120)),
                const SizedBox(height: 32),
                Text('Employee Password Reset', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Enter your employee email to receive an OTP code', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                if (_message.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _message.contains('sent') ? Colors.green.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _message.contains('sent') ? Colors.green : AppColors.error),
                    ),
                    child: Text(_message, style: TextStyle(color: _message.contains('sent') ? Colors.green : AppColors.error), textAlign: TextAlign.center),
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
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                TextButton(onPressed: () => Navigator.pop(context), child: Text('← Back to Login', style: TextStyle(color: Colors.blue))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}