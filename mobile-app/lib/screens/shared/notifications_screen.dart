import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/app_colors.dart';
import '../../services/firebase_service.dart';
import '../../services/notifications_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final User? _user = FirebaseService.currentUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.pop(context));
      return const SizedBox();
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyLarge?.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: NotificationsService.getNotifications(_user!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No notifications', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                ],
              ),
            );
          }

          final notifications = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final isRead = notification['isRead'] as bool? ?? false;
              final title = notification['title'] as String? ?? '';
              final body = notification['body'] as String? ?? '';
              final createdAt = notification['createdAt'] as Timestamp?;
              final type = notification['type'] as String? ?? 'general';

              IconData iconData;
              Color iconColor;
              switch (type) {
                case 'withdrawal':
                  iconData = Icons.money;
                  iconColor = Colors.green;
                  break;
                case 'review':
                  iconData = Icons.star;
                  iconColor = Colors.amber;
                  break;
                default:
                  iconData = Icons.notifications;
                  iconColor = AppColors.primary;
              }

              return GestureDetector(
                onTap: () {
                  if (!isRead) {
                    NotificationsService.markAsRead(notification['id'] as String);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isRead ? theme.cardColor : AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRead ? theme.dividerColor : AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(iconData, color: iconColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              body,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                            if (createdAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd/MM/yyyy HH:mm').format(createdAt.toDate()),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}