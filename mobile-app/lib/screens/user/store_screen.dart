import 'package:flutter/material.dart';
import '../../models/app_colors.dart';
import 'water_bills_screen.dart';
import 'electricity_bills_screen.dart';
import 'gas_bills_screen.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Store'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyLarge?.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              'Pay Your Bills',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color),
            ),
            const SizedBox(height: 8),
            Text(
              'Use your points to pay for utility bills',
              style: TextStyle(fontSize: 16, color: theme.textTheme.bodyMedium?.color),
            ),
            const SizedBox(height: 30),
            _buildBillCard(
              context: context,
              title: 'Water Bills',
              subtitle: 'Pay your water consumption bills',
              icon: Icons.water_drop,
              color: AppColors.water,
              route: '/water-bills',
            ),
            const SizedBox(height: 16),
            _buildBillCard(
              context: context,
              title: 'Electricity Bills',
              subtitle: 'Pay your electricity consumption bills',
              icon: Icons.bolt,
              color: AppColors.electricity,
              route: '/electricity-bills',
            ),
            const SizedBox(height: 16),
            _buildBillCard(
              context: context,
              title: 'Gas Bills',
              subtitle: 'Pay your gas consumption bills',
              icon: Icons.local_fire_department,
              color: AppColors.gas,
              route: '/gas-bills',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white),
          ],
        ),
      ),
    );
  }
}