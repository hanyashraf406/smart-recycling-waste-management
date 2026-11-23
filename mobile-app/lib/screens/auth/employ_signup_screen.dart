import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';
import '../../widgets/trash_logo.dart';
import 'employ_login_screen.dart';
import 'role_selection_screen.dart';

class EmploySignupScreen extends StatefulWidget {
  const EmploySignupScreen({super.key});

  @override
  State<EmploySignupScreen> createState() => _EmploySignupScreenState();
}

class _EmploySignupScreenState extends State<EmploySignupScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _secretCodeController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureSecretCode = true;
  bool _isLoading = false;
  String _errorMessage = '';

  List<Map<String, dynamic>> _warehouses = [];
  Map<String, dynamic>? _selectedWarehouse;
  bool _loadingWarehouses = true;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _secretCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    setState(() => _loadingWarehouses = true);
    try {
      final warehouses = await FirebaseService.getWarehouses();
      setState(() {
        _warehouses = warehouses;
        if (_warehouses.isNotEmpty) _selectedWarehouse = _warehouses.first;
        _loadingWarehouses = false;
      });
    } catch (e) {
      setState(() => _loadingWarehouses = false);
    }
  }

  Future<void> _handleSignup() async {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill all fields');
      return;
    }

    if (_selectedWarehouse == null) {
      setState(() => _errorMessage = 'Please select a warehouse');
      return;
    }

    if (_secretCodeController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter the warehouse secret code');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final warehouseDoc = await FirebaseFirestore.instance
          .collection('warehouses')
          .doc(_selectedWarehouse!['warehouseId'])
          .get();

      if (warehouseDoc.exists) {
        final warehouseData = warehouseDoc.data()!;
        final storedCode = warehouseData['secretCode'] ?? '123456';

        if (_secretCodeController.text.trim() != storedCode) {
          setState(() {
            _errorMessage = 'Invalid warehouse secret code. Please contact your admin for the correct code.';
            _isLoading = false;
          });
          return;
        }
      } else {
        setState(() {
          _errorMessage = 'Warehouse not found. Please select a valid warehouse.';
          _isLoading = false;
        });
        return;
      }

      final userData = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': 'employ',
        'warehouseId': _selectedWarehouse!['warehouseId'],
        'warehouseName': _selectedWarehouse!['name'],
        'status': 'shift',
      };

      final user = await FirebaseService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        userData,
      );

      if (user != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/employ-home');
      } else {
        setState(() => _errorMessage = 'Registration failed. Please try again.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: TrashLogo(size: 80)),
                const SizedBox(height: 16),
                Text(
                  'Join as Employee',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
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
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _firstNameController,
                        style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _lastNameController,
                        style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _loadingWarehouses
                      ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                      : DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      value: _selectedWarehouse,
                      isExpanded: true,
                      hint: const Text('Select Warehouse'),
                      items: _warehouses.map((warehouse) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: warehouse,
                          child: Text(
                            '${warehouse['name']} (${warehouse['warehouseId']})',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedWarehouse = value),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _secretCodeController,
                  obscureText: _obscureSecretCode,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    labelText: 'Warehouse Secret Code',
                    labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                    hintText: 'Enter the code provided by your admin',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.lock_outline, color: AppColors.primary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureSecretCode ? Icons.visibility_off : Icons.visibility,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      onPressed: () => setState(() => _obscureSecretCode = !_obscureSecretCode),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
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
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.work, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Employee Account',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              'You are creating an employee account. You need the secret code from your warehouse admin.',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text(
                    'Sign Up',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, '/employ-login'),
                      child: Text(
                        'Sign In',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/role-selection'),
                  child: Text(
                    '← Choose different role',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}