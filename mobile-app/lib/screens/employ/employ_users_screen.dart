import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';
import '../../services/material_service.dart';
import '../../widgets/trash_logo.dart';

class EmployUsersScreen extends StatefulWidget {
  const EmployUsersScreen({super.key});

  @override
  State<EmployUsersScreen> createState() => _EmployUsersScreenState();
}

class _EmployUsersScreenState extends State<EmployUsersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await FirebaseService.getScannedUsers();
      setState(() {
        _users = users;
        _filteredUsers = users;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading users: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredUsers = List.from(_users);
      } else {
        _filteredUsers = _users.where((user) {
          final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.toLowerCase();
          final email = (user['email'] ?? '').toLowerCase();
          final displayId = (user['displayId'] ?? '').toLowerCase();
          final q = query.toLowerCase();
          return name.contains(q) || email.contains(q) || displayId.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _toggleBlockUser(String userId, String userName, bool isCurrentlyBlocked) async {
    final action = isCurrentlyBlocked ? 'unblock' : 'block';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${action == 'block' ? 'Block' : 'Unblock'} User'),
        content: Text('Are you sure you want to $action $userName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: action == 'block' ? Colors.red : Colors.green),
            child: Text(action == 'block' ? 'Block' : 'Unblock'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isLoading = true);

    try {
      if (isCurrentlyBlocked) {
        await FirebaseService.unblockUser(userId, 'user');
      } else {
        await FirebaseService.blockUser(userId, 'user');
      }
      await _loadUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User ${isCurrentlyBlocked ? 'unblocked' : 'blocked'} successfully'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    final String fullName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final String email = user['email'] ?? 'N/A';
    final String displayId = user['displayId'] ?? '';
    final int points = user['points'] ?? 0;
    final Map<String, dynamic> materialsWeight = user['materialsWeight'] as Map<String, dynamic>? ?? {};
    final int scans = user['totalScans'] ?? 0;
    final bool isBlocked = user['isBlocked'] ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final theme = Theme.of(context);
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]), shape: BoxShape.circle),
                        child: Center(child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fullName.isEmpty ? 'User' : fullName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                            Text(email, style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                            Text(displayId, style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        if (isBlocked)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red)),
                            child: const Text('This user is blocked', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          ),
                        const Divider(height: 32),
                        const Text('Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildStatRow('Points', points.toString(), Icons.stars, AppColors.primary),
                        _buildStatRow('Total scans', scans.toString(), Icons.qr_code, Colors.blue),
                        const SizedBox(height: 16),
                        const Text('Materials Recycled', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        if (materialsWeight.isEmpty)
                          Text('No materials', style: TextStyle(color: theme.textTheme.bodyMedium?.color))
                        else
                          ...materialsWeight.entries.map((entry) {
                            final weight = (entry.value as num).toDouble();
                            final color = MaterialService.getMaterialColor(entry.key);
                            return _buildMaterialProgress(MaterialService.getMaterialName(entry.key), weight, color);
                          }),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _toggleBlockUser(user['id'], fullName, isBlocked);
                                },
                                icon: Icon(isBlocked ? Icons.lock_open : Icons.block, color: isBlocked ? Colors.green : Colors.red),
                                label: Text(isBlocked ? 'Unblock User' : 'Block User', style: TextStyle(color: isBlocked ? Colors.green : Colors.red)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: isBlocked ? Colors.green : Colors.red),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildMaterialProgress(String label, double weight, Color color) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color)),
              Text('${weight.toStringAsFixed(2)} kg', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: weight / 10, backgroundColor: color.withOpacity(0.1), valueColor: AlwaysStoppedAnimation<Color>(color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [TrashLogo(size: 40), const SizedBox(width: 8), const Text('Users')]),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyLarge?.color), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: Icon(Icons.refresh, color: theme.textTheme.bodyLarge?.color), onPressed: _loadUsers)],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.cardColor,
              child: TextField(
                controller: _searchController,
                onChanged: _filterUsers,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: 'Search by name, email or ID...',
                  hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
                  prefixIcon: Icon(Icons.search, color: theme.textTheme.bodyMedium?.color),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: theme.brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            Expanded(
              child: _filteredUsers.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('No users found', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = _filteredUsers[index];
                  final String fullName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
                  final String email = user['email'] ?? '';
                  final String displayId = user['displayId'] ?? '';
                  final int points = user['points'] ?? 0;
                  final bool isBlocked = user['isBlocked'] ?? false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: theme.cardColor,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]), shape: BoxShape.circle),
                        child: Center(child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold))),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              fullName.isEmpty ? 'User' : fullName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isBlocked ? Colors.grey : theme.textTheme.bodyLarge?.color,
                                decoration: isBlocked ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          Text(displayId, style: TextStyle(fontSize: 11, color: isBlocked ? Colors.grey : AppColors.primary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(email, style: TextStyle(fontSize: 12, color: isBlocked ? Colors.grey : theme.textTheme.bodyMedium?.color)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.stars, size: 14, color: isBlocked ? Colors.grey : AppColors.primary),
                              const SizedBox(width: 4),
                              Text('$points pts', style: TextStyle(fontSize: 12, color: isBlocked ? Colors.grey : null)),
                            ],
                          ),
                        ],
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: isBlocked ? Colors.grey : theme.textTheme.bodySmall?.color),
                      onTap: () => _showUserDetails(user),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}