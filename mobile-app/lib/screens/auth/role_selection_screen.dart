import 'package:flutter/material.dart';
import '../../models/app_colors.dart';
import 'user_login_screen.dart';
import 'employ_login_screen.dart';
import 'onboarding_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.only(top: 50, bottom: 30),
                child: Image.asset(
                  'assets/images/trash.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Icon(Icons.delete, size: 60, color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      'Select User Role',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'You can select user type to continue the sign-up flow',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: theme.textTheme.bodyMedium?.color, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                height: 1,
                color: theme.dividerColor,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildRoleCard(
                        context: context,
                        title: 'User',
                        description: 'Drop-off and earn rewards',
                        imagePath: 'assets/images/user_role.png',
                        route: '/user-login',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildRoleCard(
                        context: context,
                        title: 'Employ',
                        description: 'For managing warehouse operations',
                        imagePath: 'assets/images/employ_role.png',
                        route: '/employ-login',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/onboarding'),
                child: Text('Back to Onboarding', style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String description,
    required String imagePath,
    required String route,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, route),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)],
        ),
        child: Column(
          children: [
            Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                image: DecorationImage(image: AssetImage(imagePath), fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Text(description, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                    child: const Center(
                      child: Text('SELECT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}