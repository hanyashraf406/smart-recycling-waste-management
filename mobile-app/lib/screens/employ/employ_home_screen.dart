import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';
import '../../services/material_service.dart';
import '../../widgets/trash_logo.dart';
import 'employ_profile_screen.dart';
import 'employ_inventory_screen.dart';
import 'employ_users_screen.dart';
import 'employ_reports_screen.dart';
import 'qr_scanner_screen.dart';

class EmployHomeScreen extends StatefulWidget {
  const EmployHomeScreen({super.key});

  @override
  State<EmployHomeScreen> createState() => _EmployHomeScreenState();
}

class _EmployHomeScreenState extends State<EmployHomeScreen> {
  int _selectedIndex = 0;
  final User? _user = FirebaseService.currentUser;
  bool _hasCheckedStatus = false;

  @override
  void initState() {
    super.initState();
    _checkEmployeeStatus();
  }

  Future<void> _checkEmployeeStatus() async {
    if (_user == null || _hasCheckedStatus) return;
    _hasCheckedStatus = true;

    final status = await FirebaseService.getEmployeeStatus(_user!.uid);
    if (status == 'absent' && mounted) {
      await FirebaseService.signOut();
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('حساب غير نشط'),
            content: const Text('تم تسجيل خروجك لأن حسابك غير نشط. يرجى التواصل مع المسؤول.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamedAndRemoveUntil(context, '/employ-login', (route) => false);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _startQRScanner() {
    if (_user != null) {
      FirebaseService.getEmployeeStatus(_user!.uid).then((status) {
        if (status == 'absent' && mounted) {
          FirebaseService.signOut().then((_) {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(context, '/employ-login', (route) => false);
            }
          });
          return;
        }
        Navigator.pushNamed(context, '/qr-scanner');
      });
    }
  }

  void _openInventory() => Navigator.pushNamed(context, '/employ-inventory');
  void _openUsers() => Navigator.pushNamed(context, '/employ-users');
  void _openReports() => Navigator.pushNamed(context, '/employ-reports');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pushReplacementNamed(context, '/onboarding'));
      return const SizedBox();
    }
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('employees').doc(_user!.uid).snapshots(),
        builder: (context, snapshot) {
          String displayName = _user!.email?.split('@').first ?? 'Employee';
          String displayId = '';
          String profileImageUrl = '';
          String warehouseId = '';
          String warehouseName = '';
          String employeeStatus = 'absent';

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final firstName = data['firstName'] ?? '';
            final lastName = data['lastName'] ?? '';
            displayName = '$firstName $lastName'.trim().isNotEmpty ? '$firstName $lastName' : displayName;
            displayId = data['displayId'] ?? '';
            profileImageUrl = data['profileImage'] ?? '';
            warehouseId = data['warehouseId'] ?? '';
            warehouseName = data['warehouseName'] ?? '';
            employeeStatus = data['status'] ?? 'absent';
          }

          Color statusColor;
          String statusText;
          switch (employeeStatus.toLowerCase()) {
            case 'shift':
              statusColor = Colors.green;
              statusText = 'SHIFT';
              break;
            case 'break':
              statusColor = Colors.orange;
              statusText = 'BREAK';
              break;
            case 'absent':
            default:
              statusColor = Colors.red;
              statusText = 'ABSENT';
              break;
          }

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const TrashLogo(size: 80),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/employ-profile'),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 2),
                          ),
                          child: profileImageUrl.isNotEmpty
                              ? ClipOval(
                            child: FadeInImage(
                              placeholder: const AssetImage('assets/images/placeholder.png'),
                              image: NetworkImage(profileImageUrl),
                              fit: BoxFit.cover,
                              width: 48,
                              height: 48,
                              imageErrorBuilder: (_, __, ___) => Icon(Icons.person, color: AppColors.primary, size: 28),
                            ),
                          )
                              : const Icon(Icons.person, color: AppColors.primary, size: 28),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20)],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                            shape: BoxShape.circle,
                          ),
                          child: profileImageUrl.isNotEmpty
                              ? ClipOval(
                            child: FadeInImage(
                              placeholder: const AssetImage('assets/images/placeholder.png'),
                              image: NetworkImage(profileImageUrl),
                              fit: BoxFit.cover,
                              width: 70,
                              height: 70,
                              imageErrorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 40),
                            ),
                          )
                              : const Icon(Icons.person, color: Colors.white, size: 40),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
                              const SizedBox(height: 4),
                              Text(_user!.email ?? '', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(displayId, style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: statusColor, width: 1),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.warehouse, size: 16, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$warehouseId - $warehouseName',
                                    style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildActionCard(title: 'Scan QR', icon: Icons.qr_code_scanner, color: AppColors.primary, onTap: _startQRScanner)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildActionCard(title: 'Inventory', icon: Icons.inventory, color: Colors.blue, onTap: _openInventory)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildActionCard(title: 'Reports', icon: Icons.bar_chart, color: Colors.orange, onTap: _openReports)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildActionCard(title: 'Users', icon: Icons.people, color: Colors.purple, onTap: _openUsers)),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        FutureBuilder(
                          future: Future.wait([FirebaseService.getInventoryStats(), FirebaseService.getMaterialQuantities()]),
                          builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final stats = snapshot.data![0] as Map<String, dynamic>;
                            final materials = snapshot.data![1] as Map<String, double>;

                            return Column(
                              children: [
                                ...materials.entries.map((entry) {
                                  final color = MaterialService.getMaterialColor(entry.key);
                                  return _buildStatRow(
                                    MaterialService.getMaterialName(entry.key),
                                    '${entry.value.toStringAsFixed(2)} kg',
                                    Icons.recycling,
                                    color: color,
                                  );
                                }),
                                const Divider(),
                                _buildStatRow('Total Operations', stats['totalOperations'].toString(), Icons.history),
                                _buildStatRow('Total Users', stats['totalUsers'].toString(), Icons.people),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildEmployBottomNav(theme),
    );
  }

  Widget _buildEmployBottomNav(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(
                  svgPath: 'assets/icons/home.svg',
                  label: 'Home',
                  isSelected: _selectedIndex == 0,
                  theme: theme,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _buildMaterialNavItem(
                  icon: Icons.bar_chart,
                  label: 'Reports',
                  isSelected: _selectedIndex == 1,
                  theme: theme,
                  onTap: () {
                    setState(() => _selectedIndex = 1);
                    Navigator.pushNamed(context, '/employ-reports');
                  },
                ),
                const SizedBox(width: 64),
                _buildMaterialNavItem(
                  icon: Icons.inventory,
                  label: 'Inventory',
                  isSelected: _selectedIndex == 3,
                  theme: theme,
                  onTap: () {
                    setState(() => _selectedIndex = 3);
                    Navigator.pushNamed(context, '/employ-inventory');
                  },
                ),
                _buildNavItem(
                  svgPath: 'assets/icons/profile.svg',
                  label: 'Profile',
                  isSelected: _selectedIndex == 4,
                  theme: theme,
                  onTap: () {
                    setState(() => _selectedIndex = 4);
                    Navigator.pushNamed(context, '/employ-profile');
                  },
                ),
              ],
            ),
          ),
          Positioned(
            top: -20,
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedIndex = 2);
                _startQRScanner();
              },
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/qr.svg',
                    width: 28,
                    height: 28,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required String svgPath,
    required String label,
    required bool isSelected,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              svgPath,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(
                isSelected ? AppColors.primary : (theme.brightness == Brightness.dark ? Colors.grey[400]! : Colors.grey[500]!),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : (theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppColors.primary : (theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[500]),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : (theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, {Color color = AppColors.primary}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color))),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}