import 'package:flutter/material.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';

class EditNameScreen extends StatefulWidget {
  final String userId;
  final String currentFirstName;
  final String currentLastName;

  const EditNameScreen({
    super.key,
    required this.userId,
    required this.currentFirstName,
    required this.currentLastName,
  });

  @override
  State<EditNameScreen> createState() => _EditNameScreenState();
}

class _EditNameScreenState extends State<EditNameScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.currentFirstName);
    _lastNameController = TextEditingController(text: widget.currentLastName);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _errorMessage = 'Name cannot be empty');
      return;
    }

    if (firstName == widget.currentFirstName && lastName == widget.currentLastName) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseService.updateUserProfile(
        userId: widget.userId,
        firstName: firstName,
        lastName: lastName,
      );
      if (mounted) Navigator.pop(context, true);
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
      appBar: AppBar(
        title: const Text('Edit Name'),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ),
            TextField(
              controller: _firstNameController,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                labelText: 'First Name',
                labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lastNameController,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                labelText: 'Last Name',
                labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Save',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}