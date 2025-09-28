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
    print('GlobalNotificationListener: Checking for new notifications');
    print('GlobalNotificationListener: Current notifications count: ${currentNotifications.length}');
    print('GlobalNotificationListener: Last notifications count: ${_lastNotifications.length}');

    // Find notifications that weren't in the last check
    final newNotifications = currentNotifications.where((notification) {
      return !_lastNotifications.any((lastNotification) =>
        lastNotification.id == notification.id);
    }).toList();

    print('GlobalNotificationListener: Found ${newNotifications.length} new notifications');

    // Show popup for new unread notifications
    for (final notification in newNotifications) {
      print('GlobalNotificationListener: Processing notification: ${notification.title}, isRead: ${notification.isRead}');
      if (!notification.isRead) {
        print('GlobalNotificationListener: Showing popup for notification: ${notification.title}');
        _popupService.showNotificationPopup(context, notification);
        // Only show one popup at a time
        break;
      }
    }

    _lastNotifications = List.from(currentNotifications);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}