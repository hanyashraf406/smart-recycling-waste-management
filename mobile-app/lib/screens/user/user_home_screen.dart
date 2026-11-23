import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';
import '../../services/notifications_service.dart';
import '../../services/material_service.dart';
import '../../widgets/trash_logo.dart';
import '../dialogs/review_dialog.dart';
import 'my_qr_screen.dart';
import 'user_history_screen.dart';
import 'user_profile_screen.dart';
import 'store_screen.dart';
import '../shared/map_screen.dart';
import '../shared/notifications_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _selectedIndex = 0;
  final User? _user = FirebaseService.currentUser;

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary), child: const Text('Logout')),
        ],
      ),
    );
    if (shouldLogout == true) {
      await FirebaseService.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
      }
    }
  }

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
        stream: FirebaseService.getUserStream(_user!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildErrorWidget();
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String firstName = data['firstName'] ?? '';
          final String lastName = data['lastName'] ?? '';
          final String fullName = '$firstName $lastName'.trim().isEmpty
              ? _user!.email?.split('@').first ?? 'User'
              : '$firstName $lastName';
          final String displayId = data['displayId'] ?? _user!.uid;
          final int totalPoints = data['points'] ?? 0;
          final int totalScans = data['totalScans'] ?? 0;
          final int totalItems = data['totalItems'] ?? 0;
          final String profileImageUrl = data['profileImage'] ?? '';
          final Map<String, dynamic> materialsWeight = data['materialsWeight'] as Map<String, dynamic>? ?? {};

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const TrashLogo(size: 80),
                          Row(
                            children: [
                              StreamBuilder<int>(
                                stream: NotificationsService.getUnreadCount(_user!.uid),
                                builder: (context, notificationSnapshot) {
                                  final unreadCount = notificationSnapshot.data ?? 0;
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.notifications_outlined, size: 28),
                                        color: AppColors.primary,
                                        onPressed: () => Navigator.pushNamed(context, '/notifications'),
                                      ),
                                      if (unreadCount > 0)
                                        Positioned(
                                          right: 4,
                                          top: 4,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 18,
                                              minHeight: 18,
                                            ),
                                            child: Text(
                                              '$unreadCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.stars, size: 20, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Text('$totalPoints', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, '/user-profile'),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary, width: 2),
                                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 8)],
                                  ),
                                  child: profileImageUrl.isNotEmpty
                                      ? ClipOval(
                                    child: Image.network(
                                      profileImageUrl,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                : null,
                                            strokeWidth: 2,
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, __, ___) => Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.person, color: Colors.white, size: 24),
                                      ),
                                    ),
                                  )
                                      : Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.person, color: Colors.white, size: 24),
                                  ),
                                ),
                              ),
                            ],
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
                                  Text(fullName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color)),
                                  const SizedBox(height: 4),
                                  Text(_user!.email ?? '', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                                  const SizedBox(height: 4),
                                  Text(displayId, style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                        child: Text('$totalScans scans', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                        child: Text('$totalItems items', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Points', style: TextStyle(color: Colors.white, fontSize: 16)),
                                const SizedBox(height: 8),
                                Text('$totalPoints', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.emoji_events, color: Colors.white, size: 30),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Your Recycling Stats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      if (materialsWeight.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20)),
                          child: Center(
                            child: Text('No materials yet', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                          ),
                        )
                      else
                        _buildRecyclingStatsCircles(materialsWeight),
                      const SizedBox(height: 30),
                      const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(title: 'My QR', icon: Icons.qr_code_2, color: AppColors.primary, onTap: _onMyQR),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(title: 'History', icon: Icons.history, color: Colors.blue, onTap: _onHistory),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(title: 'Store', icon: Icons.card_giftcard, color: Colors.orange, onTap: () {
                              Navigator.pushNamed(context, '/store');
                            }),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(title: 'Map', icon: Icons.map, color: Colors.green, onTap: () {
                              Navigator.pushNamed(context, '/map');
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: FirebaseService.getPendingReviewsForUser(_user!.uid),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      final pendingReviews = snapshot.data!;
                      if (pendingReviews.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => ReviewDialog(
                              reviewId: pendingReviews.first['id'] as String,
                              pointsEarned: pendingReviews.first['pointsEarned'] as int,
                            ),
                          );
                        });
                      }
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildUserBottomNav(theme),
    );
  }

  Widget _buildUserBottomNav(ThemeData theme) {
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
                _buildNavItem(
                  svgPath: 'assets/icons/categories.svg',
                  label: 'Store',
                  isSelected: _selectedIndex == 1,
                  theme: theme,
                  onTap: () {
                    setState(() => _selectedIndex = 1);
                    Navigator.pushNamed(context, '/store');
                  },
                ),
                const SizedBox(width: 64),
                _buildNavItem(
                  svgPath: 'assets/icons/map.svg',
                  label: 'Map',
                  isSelected: _selectedIndex == 3,
                  theme: theme,
                  onTap: () {
                    setState(() => _selectedIndex = 3);
                    Navigator.pushNamed(context, '/map');
                  },
                ),
                _buildNavItem(
                  svgPath: 'assets/icons/profile.svg',
                  label: 'Profile',
                  isSelected: _selectedIndex == 4,
                  theme: theme,
                  onTap: () {
                    setState(() => _selectedIndex = 4);
                    Navigator.pushNamed(context, '/user-profile');
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
                Navigator.pushNamed(context, '/my-qr');
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

  Widget _buildRecyclingStatsCircles(Map<String, dynamic> materialsWeight) {
    final theme = Theme.of(context);
    double totalWeight = 0;
    for (var entry in materialsWeight.entries) {
      totalWeight += (entry.value as num).toDouble();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: materialsWeight.entries.map((entry) {
                final type = entry.key;
                final weight = (entry.value as num).toDouble();
                final percentage = totalWeight > 0 ? (weight / totalWeight * 100) : 0.0;
                final color = MaterialService.getMaterialColor(type);
                final name = MaterialService.getMaterialName(type);

                String weightText;
                if (weight >= 1.0) {
                  weightText = '${weight.toStringAsFixed(1)} kg';
                } else {
                  weightText = '${(weight * 1000).toStringAsFixed(0)} g';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 6),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                weightText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
          ],
        ),
      ),
    );
  }

  void _onMyQR() => Navigator.pushNamed(context, '/my-qr');
  void _onHistory() => Navigator.pushNamed(context, '/user-history');

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Failed to load user data', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/onboarding'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }
}