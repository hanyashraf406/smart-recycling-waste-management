import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/app_colors.dart';
import '../../services/otp_service.dart';
import '../../widgets/trash_logo.dart';
import 'reset_password_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  String _errorMessage = '';
  int _secondsRemaining = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _otpControllers) c.dispose();
    for (var n in _focusNodes) n.dispose();
    super.dispose();
  }

  Future<void> _verifyOTP() async {
    String otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter complete OTP');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final isValid = await OTPService.verifyOTP(widget.email, otp);

    if (mounted) {
      if (isValid) {
        Navigator.pushReplacementNamed(context, '/reset-password', arguments: {
          'email': widget.email,
        });
      } else {
        setState(() => _errorMessage = 'Invalid or expired OTP. Please try again.');
      }
      setState(() => _isLoading = false);
    }
  }

  void _resendOTP() async {
    setState(() {
      _secondsRemaining = 60;
      _errorMessage = '';
      _isLoading = true;
    });
    await OTPService.sendOTP(widget.email);
    setState(() => _isLoading = false);
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Verify OTP'),
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
                Text('Verification Code', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('We have sent a 6-digit code to', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color), textAlign: TextAlign.center),
                Text(widget.email, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary), textAlign: TextAlign.center),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 48,
                      height: 56,
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: theme.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
                          } else if (value.isEmpty && index > 0) {
                            FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
                          }
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    _secondsRemaining > 0 ? 'Resend code in $_secondsRemaining seconds' : 'Didn\'t receive code?',
                    style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color),
                  ),
                ),
                if (_secondsRemaining == 0)
                  TextButton(
                    onPressed: _isLoading ? null : _resendOTP,
                    child: Text('Resend Code', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('VERIFY OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}