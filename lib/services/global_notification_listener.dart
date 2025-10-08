import 'package:flutter/material.dart';
import 'dart:async';
import '../models/notification.dart';
import 'notification_service.dart';
import 'global_notification_popup_service.dart';

class GlobalNotificationListener extends StatefulWidget {
  final Widget child;

  const GlobalNotificationListener({
    super.key,
    required this.child,
  });

  @override
  State<GlobalNotificationListener> createState() => _GlobalNotificationListenerState();
}

class _GlobalNotificationListenerState extends State<GlobalNotificationListener> {
  final NotificationService _notificationService = NotificationService();
  final GlobalNotificationPopupService _popupService = GlobalNotificationPopupService();
  StreamSubscription<List<AppNotification>>? _notificationSubscription;
  List<AppNotification> _lastNotifications = [];

  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _popupService.dispose();
    super.dispose();
  }

  void _setupNotificationListener() {
    print('GlobalNotificationListener: Setting up notification listener');
    // Listen for new notifications
    final notificationStream = _notificationService.streamUserNotifications();
    if (notificationStream != null) {
      print('GlobalNotificationListener: Notification stream is available, subscribing...');
      _notificationSubscription = notificationStream.listen(
        (notifications) {
          print('GlobalNotificationListener: Received ${notifications.length} notifications');
          if (mounted && notifications.isNotEmpty) {
            _checkForNewNotifications(notifications);
          }
        },
        onError: (error) {
          print('GlobalNotificationListener: Error listening for notifications: $error');
          debugPrint('Error listening for notifications: $error');
        },
      );
    } else {
      print('GlobalNotificationListener: Notification stream is null - user not authenticated or Firebase not initialized');
    }
  }

  void _checkForNewNotifications(List<AppNotification> currentNotifications) {
    // Find notifications that weren't in the last check
    final newNotifications = currentNotifications.where((notification) {
      return !_lastNotifications.any((lastNotification) =>
        lastNotification.id == notification.id);
    }).toList();

    // Filter only unread notifications
    final unreadNewNotifications = newNotifications.where((n) => !n.isRead).toList();

    // Only log if there are actually new unread notifications
    if (unreadNewNotifications.isNotEmpty) {
      print('GlobalNotificationListener: Found ${unreadNewNotifications.length} new unread notifications');
    }

    // Show popup for new unread notifications
    for (final notification in unreadNewNotifications) {
      print('GlobalNotificationListener: Showing popup for: ${notification.title}');
      try {
        if (mounted) {
          _popupService.showNotificationPopup(context, notification);
        }
      } catch (e) {
        print('GlobalNotificationListener: Error showing notification popup: $e');
      }
      // Only show one popup at a time
      break;
    }

    _lastNotifications = List.from(currentNotifications);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}