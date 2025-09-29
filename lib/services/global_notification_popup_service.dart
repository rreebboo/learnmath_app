import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/notification.dart';
import '../widgets/user_avatar.dart';
import '../screens/quiz_duel_screen.dart';
import '../services/quiz_duel_service.dart';
import '../services/notification_service.dart';


class GlobalNotificationPopupService {
  static final GlobalNotificationPopupService _instance = GlobalNotificationPopupService._internal();
  factory GlobalNotificationPopupService() => _instance;
  GlobalNotificationPopupService._internal();

  OverlayEntry? _overlayEntry;
  Timer? _dismissTimer;
  bool _isShowing = false;
  OverlayState? _overlayState;
  VoidCallback? _onCloseCallback;
  final NotificationService _notificationService = NotificationService();

  // For animated list management
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  // ignore: prefer_final_fields - List contents are modified
  List<AppNotification> _notifications = [];
  final Set<String> _deletingIds = {};

  // For iOS-style grow animation
  Offset? _iconPosition;
  bool _isClosing = false;


  void showNotificationPopup(BuildContext context, AppNotification notification) {
    if (_isShowing) {
      hideNotificationPopup();
    }

    try {
      // Get and store overlay state safely
      _overlayState = Overlay.of(context);
      if (_overlayState == null || !_overlayState!.mounted) {
        return; // Can't show popup if overlay is not available
      }

      _isShowing = true;
      _overlayEntry = OverlayEntry(
        builder: (context) => _buildNotificationPopup(context, notification),
      );

      _overlayState!.insert(_overlayEntry!);

      // Auto-dismiss after 5 seconds
      _dismissTimer = Timer(const Duration(seconds: 5), () {
        if (_isShowing && _overlayEntry != null) {
          hideNotificationPopup();
        }
      });

      // Haptic feedback
      HapticFeedback.lightImpact();
    } catch (e) {
      // Handle error silently and cleanup
      _cleanup();
    }
  }

  void hideNotificationPopup() {
    if (!_isShowing) return;

    try {
      // Trigger closing animation
      _isClosing = true;

      // Mark overlay for rebuild to show closing animation
      if (_overlayEntry != null) {
        _overlayEntry!.markNeedsBuild();
      }

      // Wait for animation to complete before actually removing
      Timer(const Duration(milliseconds: 400), () {
        _actuallyHidePopup();
      });
    } catch (e) {
      // If anything fails, immediately hide
      _actuallyHidePopup();
    }
  }

  void _actuallyHidePopup() {
    try {
      if (_overlayEntry != null && _isShowing) {
        // Check if overlay state is still valid before removing
        if (_overlayState != null && _overlayState!.mounted) {
          _overlayEntry!.remove();
        }
        _overlayEntry = null;
        _isShowing = false;

        // Call the close callback to notify that popup is closed
        if (_onCloseCallback != null) {
          _onCloseCallback!();
          _onCloseCallback = null;
        }
      }
    } catch (e) {
      // Handle error silently
    } finally {
      _cleanup();
    }
  }

  void _cleanup() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _overlayEntry = null;
    _overlayState = null;
    _isShowing = false;
    _onCloseCallback = null;
    _notifications.clear();
    _deletingIds.clear();
    _iconPosition = null;
    _isClosing = false;
  }

  void _updateNotificationsList(List<AppNotification> newNotifications) {
    // Handle new notifications (additions)
    // Process in reverse order since we insert at index 0, so newest will end up at top
    final notificationsToAdd = <AppNotification>[];

    for (final newNotification in newNotifications) {
      if (!_notifications.any((n) => n.id == newNotification.id)) {
        notificationsToAdd.add(newNotification);
      }
    }

    // Add in reverse order so that when we insert at index 0,
    // the final order matches the original stream order (newest first)
    for (int i = notificationsToAdd.length - 1; i >= 0; i--) {
      _notifications.insert(0, notificationsToAdd[i]);
      _listKey.currentState?.insertItem(0);
    }

    // Handle removed notifications (deletions)
    final List<AppNotification> toRemove = [];
    for (int i = _notifications.length - 1; i >= 0; i--) {
      final notification = _notifications[i];
      if (!newNotifications.any((n) => n.id == notification.id) &&
          !_deletingIds.contains(notification.id)) {
        toRemove.add(notification);
      }
    }

    for (final notification in toRemove) {
      final index = _notifications.indexOf(notification);
      if (index != -1) {
        _notifications.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
          (context, animation) => _buildAnimatedNotificationItem(
            context,
            notification,
            animation,
            MediaQuery.of(context).size.width < 360,
          ),
        );
      }
    }
  }

  void _animateDeleteNotification(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;

    // Mark as deleting to prevent premature removal
    _deletingIds.add(notificationId);

    final notification = _notifications[index];
    _notifications.removeAt(index);

    // Animate removal
    _listKey.currentState?.removeItem(
      index,
      (context, animation) {
        return SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(1.0, 0.0),
            ).chain(CurveTween(curve: Curves.easeInBack)),
          ),
          child: FadeTransition(
            opacity: Tween<double>(begin: 1.0, end: 0.0).animate(animation),
            child: _buildNotificationCard(
              context,
              notification,
              MediaQuery.of(context).size.width < 360,
            ),
          ),
        );
      },
      duration: const Duration(milliseconds: 400),
    );

    // Actually delete from Firestore after animation
    Timer(const Duration(milliseconds: 450), () {
      _deletingIds.remove(notificationId);
      _notificationService.deleteNotification(notificationId);
    });
  }

  void _animateClearAllNotifications() {
    // Get all current notifications that are visible in the list
    final currentNotifications = List<AppNotification>.from(_notifications);

    if (currentNotifications.isEmpty) {
      // If no notifications to clear, just call the service
      _notificationService.clearAllNotifications();
      return;
    }

    // Mark all as deleting to prevent premature removal
    for (final notification in currentNotifications) {
      _deletingIds.add(notification.id);
    }

    // Animate removal from top to bottom (normal order) with clean slide animation
    for (int i = 0; i < currentNotifications.length; i++) {
      final notification = currentNotifications[i];

      // Add staggered delay
      Timer(Duration(milliseconds: i * 100), () {
        // Find current index in the actual list
        final currentIndex = _notifications.indexWhere((n) => n.id == notification.id);
        if (currentIndex == -1) return;

        // Remove from local list
        final removedNotification = _notifications.removeAt(currentIndex);

        // Clean slide animation
        _listKey.currentState?.removeItem(
          currentIndex,
          (context, animation) {
            return SlideTransition(
              position: animation.drive(
                Tween<Offset>(
                  begin: Offset.zero,
                  end: const Offset(1.0, 0.0),
                ).chain(CurveTween(curve: Curves.easeInBack)),
              ),
              child: FadeTransition(
                opacity: Tween<double>(begin: 1.0, end: 0.0).animate(animation),
                child: _buildNotificationCard(
                  context,
                  removedNotification,
                  MediaQuery.of(context).size.width < 360,
                ),
              ),
            );
          },
          duration: const Duration(milliseconds: 400),
        );
      });
    }

    // Clear from Firestore after all animations complete
    final totalAnimationTime = (currentNotifications.length * 100) + 450;
    Timer(Duration(milliseconds: totalAnimationTime), () {
      for (final notification in currentNotifications) {
        _deletingIds.remove(notification.id);
      }
      _notificationService.clearAllNotifications();
    });
  }

  void _animateMarkAsRead(String notificationId) {
    // Find the notification in local list
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;

    // Mark as read in Firestore first
    _notificationService.markAsRead(notificationId);

    // Update local notification state
    final updatedNotification = _notifications[index].copyWith(isRead: true);
    _notifications[index] = updatedNotification;

    // Force a simple rebuild by removing and inserting the item
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => const SizedBox.shrink(),
      duration: const Duration(milliseconds: 1),
    );

    // Insert the updated notification immediately
    Timer(const Duration(milliseconds: 2), () {
      _listKey.currentState?.insertItem(
        index,
        duration: const Duration(milliseconds: 300),
      );
    });
  }

  Widget _buildAnimatedNotificationItem(
    BuildContext context,
    AppNotification notification,
    Animation<double> animation,
    bool isSmallScreen,
  ) {
    return SlideTransition(
      position: animation.drive(
        Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOut)),
      ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(animation),
        child: _buildNotificationCard(context, notification, isSmallScreen),
      ),
    );
  }

  Widget _buildNotificationPopup(BuildContext context, AppNotification notification) {
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isSmallScreen = screenWidth < 360;

    return Positioned(
      top: statusBarHeight + 8,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 400),
          tween: Tween<double>(begin: -100, end: 0),
          curve: Curves.easeOutQuart,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, value),
              child: child!,
            );
          },
          child: notification.type == NotificationType.duelChallenge
              ? _buildDuelChallengePopup(context, notification, isSmallScreen)
              : _buildGenericNotificationPopup(context, notification, isSmallScreen),
        ),
      ),
    );
  }

  void showNotificationPanel(BuildContext context, {Offset? originPosition, VoidCallback? onClose}) {
    hideNotificationPopup(); // Hide any existing notification popup

    try {
      _onCloseCallback = onClose;
      _iconPosition = originPosition; // Store icon position for animation
      _isClosing = false;

      // Get and store overlay state safely
      _overlayState = Overlay.of(context);
      if (_overlayState == null || !_overlayState!.mounted) {
        return; // Can't show popup if overlay is not available
      }

      _isShowing = true;
      _overlayEntry = OverlayEntry(
        builder: (context) => _buildNotificationPanel(context, originPosition: originPosition),
      );

      _overlayState!.insert(_overlayEntry!);

      // Haptic feedback
      HapticFeedback.lightImpact();
    } catch (e) {
      // Handle error silently and cleanup
      _cleanup();
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.duelChallenge:
        return Icons.sports_martial_arts;
      case NotificationType.friendRequest:
        return Icons.person_add;
      case NotificationType.achievement:
        return Icons.emoji_events;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.duelChallenge:
        return Colors.orange.shade600;
      case NotificationType.friendRequest:
        return Colors.green.shade600;
      case NotificationType.achievement:
        return Colors.amber.shade600;
      default:
        return Colors.amber.shade600;
    }
  }

  Widget _buildDuelChallengePopup(BuildContext context, AppNotification notification, bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with challenge icon and close button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2196F3).withValues(alpha: 0.2),
                        const Color(0xFF2196F3).withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.sports_martial_arts,
                    color: const Color(0xFF2196F3),
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          color: const Color(0xFF2C3E50),
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.message,
                        style: TextStyle(
                          color: const Color(0xFF2C3E50).withValues(alpha: 0.8),
                          fontSize: isSmallScreen ? 12 : 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: hideNotificationPopup,
                  icon: Icon(
                    Icons.close,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Challenge details
            if (notification.data != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      avatar: notification.fromUserAvatar ?? '👤',
                      size: isSmallScreen ? 32 : 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.fromUserName ?? 'Unknown User',
                            style: TextStyle(
                              color: const Color(0xFF2C3E50),
                              fontSize: isSmallScreen ? 13 : 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (notification.data!['difficulty'] != null ||
                              notification.data!['topicName'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${notification.data!['difficulty'] ?? 'Mixed'} • ${notification.data!['topicName'] ?? 'All Topics'}',
                              style: TextStyle(
                                color: const Color(0xFF2C3E50).withValues(alpha: 0.6),
                                fontSize: isSmallScreen ? 11 : 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _declineChallenge(context, notification);
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(
                      'Decline',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 10 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _acceptChallenge(context, notification);
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(
                      'Accept',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 10 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericNotificationPopup(BuildContext context, AppNotification notification, bool isSmallScreen) {
    return GestureDetector(
      onTap: () {
        showNotificationPanel(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getNotificationColor(notification.type).withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getNotificationColor(notification.type).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: _getNotificationColor(notification.type),
                  size: isSmallScreen ? 20 : 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        color: const Color(0xFF2C3E50),
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: const Color(0xFF2C3E50).withValues(alpha: 0.7),
                        fontSize: isSmallScreen ? 12 : 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: hideNotificationPopup,
                icon: const Icon(
                  Icons.close,
                  color: Color(0xFF2C3E50),
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _acceptChallenge(BuildContext context, AppNotification notification) async {
    OverlayEntry? loadingOverlay;

    try {
      print('_acceptChallenge: Starting challenge acceptance');
      print('Notification data: ${notification.data}');

      // Validate notification data
      if (notification.data == null || notification.data!['duelId'] == null) {
        throw Exception('Invalid notification data: missing duelId');
      }

      // Mark notification as read first
      _notificationService.markAsRead(notification.id);

      // Show loading indicator using overlay to ensure it's always visible and closeable
      final overlayState = Overlay.of(context);
      loadingOverlay = OverlayEntry(
        builder: (context) => Material(
          type: MaterialType.transparency,
          child: Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Accepting challenge...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      overlayState.insert(loadingOverlay);

      // Accept the challenge
      final duelId = notification.data!['duelId'] as String;
      print('_acceptChallenge: Attempting to accept duel: $duelId');

      final success = await QuizDuelService().acceptChallenge(duelId);
      print('_acceptChallenge: Accept result: $success');

      // Close loading overlay
      loadingOverlay.remove();
      loadingOverlay = null;

      if (success) {
        print('_acceptChallenge: Success - proceeding with navigation');

        // Send notification to challenger that challenge was accepted
        await _sendChallengeResponseNotification(
          toUserId: notification.fromUserId,
          fromUserName: notification.fromUserName ?? 'Unknown User',
          accepted: true,
        );

        // Check if context is still mounted before navigation
        if (!context.mounted) {
          print('_acceptChallenge: Context no longer mounted - cannot navigate');
          return;
        }

        print('_acceptChallenge: Navigating to QuizDuelScreen with gameId: $duelId');

        // Hide the notification popup BEFORE navigation to prevent issues
        hideNotificationPopup();

        // Navigate to quiz duel screen
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizDuelScreen(
              gameId: duelId,
              topicName: notification.data!['topicName'] ?? 'Mixed Topics',
              operator: 'mixed',
              difficulty: notification.data!['difficulty'] ?? 'Medium',
            ),
          ),
        );

        print('_acceptChallenge: Navigation completed');

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Challenge accepted! Get ready to duel!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('_acceptChallenge: Challenge acceptance failed (success = false)');
        // Hide the notification popup even if failed
        hideNotificationPopup();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to accept challenge. It may have expired.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('_acceptChallenge: Error occurred: $e');

      // Close loading overlay if still open
      if (loadingOverlay != null) {
        try {
          loadingOverlay.remove();
        } catch (_) {}
        loadingOverlay = null;
      }

      // Hide the notification popup
      hideNotificationPopup();

      if (context.mounted) {
        String errorMessage = 'Error accepting challenge. Please try again.';

        // Provide specific error messages
        if (e.toString().contains('missing duelId')) {
          errorMessage = 'Challenge data is invalid. Please try refreshing.';
        } else if (e.toString().contains('no longer exists')) {
          errorMessage = 'This challenge has expired or been cancelled.';
        } else if (e.toString().contains('not pending')) {
          errorMessage = 'This challenge has already been accepted or declined.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineChallenge(BuildContext context, AppNotification notification) async {
    try {
      // Hide the notification popup first
      hideNotificationPopup();

      // Mark notification as read
      _notificationService.markAsRead(notification.id);

      // Decline the challenge
      if (notification.data != null && notification.data!['duelId'] != null) {
        await QuizDuelService().declineChallenge(notification.data!['duelId']);
      }

      // Send notification to challenger that challenge was declined
      await _sendChallengeResponseNotification(
        toUserId: notification.fromUserId,
        fromUserName: notification.fromUserName ?? 'Unknown User',
        accepted: false,
      );

      // Show feedback message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Declined challenge from ${notification.fromUserName ?? 'Unknown User'}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Hide popup anyway
      hideNotificationPopup();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error declining challenge'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Widget _buildNotificationPanel(BuildContext context, {Offset? originPosition}) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isSmallScreen = screenWidth < 360;

    return Positioned(
      top: statusBarHeight + 8,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 400), // iOS-style timing
          tween: Tween<double>(begin: 0, end: _isClosing ? 0 : 1),
          curve: _isClosing ? Curves.easeInQuart : Curves.easeOutBack, // iOS-style curves
          builder: (context, value, child) {
            if (_iconPosition == null) {
              // Fallback to center animation if no icon position
              return Transform.scale(
                scale: value.clamp(0.0, 1.0),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child!,
                ),
              );
            }

            // Calculate the final panel position and size
            final panelWidth = screenWidth - 32; // Account for 16px margins
            final panelHeight = screenHeight * 0.7;
            final panelLeft = 16.0;
            final panelTop = statusBarHeight + 8;

            // Calculate icon size (assume notification icon is about 24px)
            const iconSize = 24.0;

            // Calculate scale: from icon size to panel size
            final scaleX = iconSize / panelWidth;
            final scaleY = iconSize / panelHeight;
            final minScale = math.min(scaleX, scaleY);

            // Calculate current scale
            final currentScale = minScale + ((1.0 - minScale) * value);

            // Calculate position: from icon position to panel center
            final panelCenterX = panelLeft + (panelWidth / 2);
            final panelCenterY = panelTop + (panelHeight / 2);

            final currentX = _iconPosition!.dx + (panelCenterX - _iconPosition!.dx) * value;
            final currentY = _iconPosition!.dy + (panelCenterY - _iconPosition!.dy) * value;

            // Calculate offset for transform
            final offsetX = currentX - panelCenterX;
            final offsetY = currentY - panelCenterY;

            return Transform.translate(
              offset: Offset(offsetX, offsetY),
              child: Transform.scale(
                scale: currentScale.clamp(0.0, 1.0),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child!,
                ),
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            height: screenHeight * 0.7,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      StreamBuilder<List<AppNotification>>(
                        stream: _notificationService.streamUserNotifications(),
                        builder: (context, snapshot) {
                          final notifications = snapshot.data ?? [];
                          final hasUnread = notifications.any((n) => !n.isRead);

                          // Adjust title size based on whether Mark all button is present
                          final titleFontSize = hasUnread
                              ? (isSmallScreen ? 16.0 : 18.0)  // Smaller when Mark all is present
                              : (isSmallScreen ? 18.0 : 20.0); // Normal size when Mark all is not present

                          return Expanded(
                            child: Text(
                              'Notifications',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: titleFontSize,
                                color: const Color(0xFF2C3E50),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                      StreamBuilder<List<AppNotification>>(
                        stream: _notificationService.streamUserNotifications(),
                        builder: (context, snapshot) {
                          final notifications = snapshot.data ?? [];
                          final hasUnread = notifications.any((n) => !n.isRead);

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasUnread)
                                TextButton(
                                  onPressed: () {
                                    // Check if context is still mounted before performing action
                                    if (context.mounted) {
                                      _notificationService.markAllAsRead();
                                    }
                                  },
                                  child: Text(
                                    'Mark all',
                                    style: TextStyle(
                                      color: Colors.amber.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              TextButton(
                                onPressed: () {
                                  // Show dialog while keeping the notification panel open
                                  if (context.mounted) {
                                    _showClearAllDialog(context);
                                  }
                                },
                                child: const Text(
                                  'Clear All',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: hideNotificationPopup,
                                icon: const Icon(
                                  Icons.close,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Notification List
                Expanded(
                  child: StreamBuilder<List<AppNotification>>(
                    stream: _notificationService.streamUserNotifications(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB74D)),
                          ),
                        );
                      }

                      final newNotifications = snapshot.data ?? [];
                      _updateNotificationsList(newNotifications);

                      if (_notifications.isEmpty) {
                        return _buildEmptyNotificationState(isSmallScreen);
                      }

                      return AnimatedList(
                        key: _listKey,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16,
                          vertical: 8,
                        ),
                        initialItemCount: _notifications.length,
                        itemBuilder: (context, index, animation) {
                          if (index >= _notifications.length) {
                            return const SizedBox.shrink();
                          }

                          final notification = _notifications[index];
                          return _buildAnimatedNotificationItem(
                            context,
                            notification,
                            animation,
                            isSmallScreen,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyNotificationState(bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none,
              size: isSmallScreen ? 48 : 64,
              color: Colors.amber.shade400,
            ),
          ),
          SizedBox(height: isSmallScreen ? 16 : 24),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Friend requests, math challenges, achievements,\nand other important updates will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 14,
              color: Colors.grey[500],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, AppNotification notification, bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        color: notification.isRead ? Colors.white : Colors.amber.shade50,
        elevation: notification.isRead ? 1 : 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleNotificationCardTap(context, notification),
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardNotificationIcon(notification.type, isSmallScreen),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13 : 15,
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                                color: const Color(0xFF2C3E50),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: isSmallScreen ? 1 : 2,
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 4, left: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade600,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 13,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: isSmallScreen ? 2 : 3,
                      ),
                      if (notification.fromUserName != null) ...[
                        SizedBox(height: isSmallScreen ? 4 : 6),
                        Row(
                          children: [
                            UserAvatar(
                              avatar: notification.fromUserAvatar ?? '👤',
                              size: isSmallScreen ? 16 : 20,
                            ),
                            SizedBox(width: isSmallScreen ? 4 : 6),
                            Flexible(
                              child: Text(
                                'From ${notification.fromUserName}',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 9 : 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: isSmallScreen ? 4 : 6),
                      Text(
                        _formatTimeAgo(notification.createdAt),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 9 : 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!notification.isRead)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _animateMarkAsRead(notification.id);
                        },
                        child: Container(
                          padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.blue.withValues(alpha: 0.1),
                          ),
                          child: Icon(
                            Icons.mark_email_read,
                            size: isSmallScreen ? 12 : 14,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    SizedBox(height: isSmallScreen ? 4 : 6),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _animateDeleteNotification(notification.id);
                      },
                      child: Container(
                        padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.orange.withValues(alpha: 0.1),
                        ),
                        child: Icon(
                          Icons.delete,
                          size: isSmallScreen ? 12 : 14,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardNotificationIcon(NotificationType type, bool isSmallScreen) {
    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.duelChallenge:
        icon = Icons.sports_martial_arts;
        color = Colors.orange.shade600;
        break;
      case NotificationType.friendRequest:
        icon = Icons.person_add;
        color = Colors.green.shade600;
        break;
      case NotificationType.achievement:
        icon = Icons.emoji_events;
        color = Colors.amber.shade600;
        break;
      default:
        icon = Icons.info;
        color = Colors.amber.shade600;
    }

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: isSmallScreen ? 18 : 20,
        color: color,
      ),
    );
  }

  void _handleNotificationCardTap(BuildContext context, AppNotification notification) {
    print('_handleNotificationCardTap: Card tapped!');
    print('_handleNotificationCardTap: Notification ID: ${notification.id}');
    print('_handleNotificationCardTap: Notification type: ${notification.type}');
    print('_handleNotificationCardTap: Notification data: ${notification.data}');

    // Check if context is still mounted before proceeding
    if (!context.mounted) {
      print('_handleNotificationCardTap: Context not mounted, returning');
      return;
    }

    // Mark as read if not already read
    if (!notification.isRead) {
      print('_handleNotificationCardTap: Marking notification as read');
      NotificationService().markAsRead(notification.id);
    }

    // Handle specific notification types
    switch (notification.type) {
      case NotificationType.duelChallenge:
        print('_handleNotificationCardTap: Handling duel challenge from panel');
        // For notification panel, show confirmation dialog
        _handleDuelChallenge(context, notification);
        break;
      case NotificationType.friendRequest:
        print('_handleNotificationCardTap: Handling friend request');
        hideNotificationPopup();
        if (context.mounted) {
          _handleFriendRequest(context, notification);
        }
        break;
      default:
        print('_handleNotificationCardTap: Unknown notification type: ${notification.type}');
        break;
    }
  }

  void _handleDuelChallenge(BuildContext context, AppNotification notification) {
    // Check if context is still mounted before proceeding
    if (!context.mounted) return;

    print('_handleDuelChallenge: Starting dialog for notification');
    print('_handleDuelChallenge: Notification type: ${notification.type}');
    print('_handleDuelChallenge: Notification data: ${notification.data}');

    final duelId = notification.data?['duelId'] as String?;
    print('_handleDuelChallenge: Extracted duelId: $duelId');

    if (duelId == null || duelId.isEmpty) {
      print('_handleDuelChallenge: ERROR - Invalid duelId');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid challenge data - missing duel ID')),
        );
      }
      return;
    }

    // Create a high z-index overlay for the dialog to appear above notification panel
    final overlayState = Overlay.of(context);
    if (!overlayState.mounted) return;

    late OverlayEntry dialogOverlay;

    dialogOverlay = OverlayEntry(
      builder: (overlayContext) => Material(
        type: MaterialType.transparency,
        child: Container(
          color: Colors.black.withValues(alpha: 0.5), // Semi-transparent background
          child: Center(
            child: AlertDialog(
              elevation: 50, // Very high elevation to appear above notification panel
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Row(
                children: [
                  UserAvatar(
                    avatar: notification.fromUserAvatar ?? '🦊',
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🔢 Math Duel Challenge!',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'from ${notification.fromUserName ?? 'Unknown'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${notification.fromUserName ?? 'Someone'} wants to challenge you to a math duel!',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Are you ready to show your math skills?',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    dialogOverlay.remove();
                    if (context.mounted) {
                      await _declineDialogChallenge(context, duelId, notification);
                    }
                  },
                  child: const Text(
                    'Decline',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    dialogOverlay.remove();
                    if (context.mounted) {
                      await _acceptDialogChallenge(context, duelId, notification);
                    }
                  },
                  child: const Text('Accept Challenge'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlayState.insert(dialogOverlay);
  }

  void _handleFriendRequest(BuildContext context, AppNotification notification) {
    // Check if context is still mounted before proceeding
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🤝 Friend Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${notification.fromUserName} wants to be your friend!'),
            const SizedBox(height: 16),
            const Text('Do you want to accept this friend request?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Friend request functionality will be implemented soon!'),
                  ),
                );
              }
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  // Dialog-based challenge acceptance (alternative approach)
  Future<void> _acceptDialogChallenge(BuildContext context, String duelId, AppNotification notification) async {
    OverlayEntry? loadingOverlay;

    try {
      print('_acceptDialogChallenge: Starting dialog-based challenge acceptance');
      print('_acceptDialogChallenge: DuelId: $duelId');
      print('_acceptDialogChallenge: Notification data: ${notification.data}');
      print('_acceptDialogChallenge: Context mounted: ${context.mounted}');

      // Validate duelId
      if (duelId.isEmpty) {
        print('_acceptDialogChallenge: ERROR - DuelId is empty');
        throw Exception('Invalid duelId: empty string');
      }

      // Show loading indicator using overlay to ensure it's always visible and closeable
      final overlayState = Overlay.of(context);
      loadingOverlay = OverlayEntry(
        builder: (context) => Material(
          type: MaterialType.transparency,
          child: Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Accepting challenge...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      overlayState.insert(loadingOverlay);

      print('_acceptDialogChallenge: About to call QuizDuelService().acceptChallenge()');
      final success = await QuizDuelService().acceptChallenge(duelId);
      print('_acceptDialogChallenge: Accept result: $success');
      print('_acceptDialogChallenge: Context still mounted after service call: ${context.mounted}');

      // Close loading overlay
      loadingOverlay.remove();
      loadingOverlay = null;

      // Check if context is still mounted before UI operations
      if (!context.mounted) return;

      if (success) {
        print('_acceptDialogChallenge: Success - proceeding with navigation');

        try {
          // Send notification to challenger
          print('_acceptDialogChallenge: Sending response notification...');
          await _sendChallengeResponseNotification(
            toUserId: notification.fromUserId,
            fromUserName: notification.fromUserName ?? 'Unknown User',
            accepted: true,
          );
          print('_acceptDialogChallenge: Response notification sent successfully');
        } catch (e) {
          print('_acceptDialogChallenge: Error sending response notification: $e');
          // Continue anyway - navigation is more important
        }

        // Check context again after async operation
        if (!context.mounted) {
          print('_acceptDialogChallenge: Context no longer mounted - cannot navigate');
          return;
        }

        final topicName = notification.data?['topicName'] as String? ?? 'Math Duel';
        final difficulty = notification.data?['difficulty'] as String? ?? 'medium';

        print('_acceptDialogChallenge: Navigating to QuizDuelScreen with gameId: $duelId');
        print('_acceptDialogChallenge: topicName: $topicName, difficulty: $difficulty');

        // Hide the notification panel BEFORE navigation to prevent conflicts
        hideNotificationPopup();

        print('_acceptDialogChallenge: Starting navigation...');
        print('_acceptDialogChallenge: Creating QuizDuelScreen with gameId: $duelId');

        // Navigate to duel screen with gameId
        final duelScreen = QuizDuelScreen(
          topicName: topicName,
          operator: 'mixed',
          difficulty: difficulty,
          gameId: duelId,
        );

        print('_acceptDialogChallenge: QuizDuelScreen created, about to navigate');

        try {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => duelScreen,
            ),
          );
          print('_acceptDialogChallenge: Navigation completed successfully');
        } catch (e) {
          print('_acceptDialogChallenge: Error during navigation: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Navigation error: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge accepted! Good luck!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        print('_acceptDialogChallenge: Challenge acceptance failed (success = false)');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to accept challenge. It may have expired.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('_acceptDialogChallenge: Error occurred: $e');

      // Close loading overlay if still open
      if (loadingOverlay != null) {
        try {
          loadingOverlay.remove();
        } catch (_) {}
        loadingOverlay = null;
      }

      if (context.mounted) {
        String errorMessage = 'Failed to accept challenge. Please try again.';

        // Provide specific error messages
        if (e.toString().contains('Invalid duelId')) {
          errorMessage = 'Challenge data is invalid. Please try refreshing.';
        } else if (e.toString().contains('no longer exists')) {
          errorMessage = 'This challenge has expired or been cancelled.';
        } else if (e.toString().contains('not pending')) {
          errorMessage = 'This challenge has already been accepted or declined.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Dialog-based challenge decline (alternative approach)
  Future<void> _declineDialogChallenge(BuildContext context, String duelId, AppNotification notification) async {
    try {
      final success = await QuizDuelService().declineChallenge(duelId);

      if (success) {
        // Send notification to challenger that challenge was declined
        await _sendChallengeResponseNotification(
          toUserId: notification.fromUserId,
          fromUserName: notification.fromUserName ?? 'Unknown User',
          accepted: false,
        );

        // Check if context is still mounted after async operation
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Declined challenge from ${notification.fromUserName ?? 'Unknown User'}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to decline challenge'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining challenge: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showClearAllDialog(BuildContext context) {
    // Double-check context is still mounted before showing dialog
    if (!context.mounted) return;

    // Create a separate overlay entry for the dialog with higher z-index
    final overlayState = Overlay.of(context);
    if (!overlayState.mounted) return;

    late OverlayEntry dialogOverlay;

    dialogOverlay = OverlayEntry(
      builder: (overlayContext) => Material(
        type: MaterialType.transparency,
        child: Container(
          color: Colors.black.withValues(alpha: 0.7), // Dark background
          child: Center(
            child: AlertDialog(
              elevation: 30, // Very high elevation
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Clear All Notifications',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: const Text(
                'Are you sure you want to clear all notifications? This action cannot be undone.',
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    dialogOverlay.remove();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    dialogOverlay.remove();
                    _animateClearAllNotifications();
                    // Keep the notification panel open after clearing
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlayState.insert(dialogOverlay);
  }


  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Future<void> _sendChallengeResponseNotification({
    required String toUserId,
    required String fromUserName,
    required bool accepted,
  }) async {
    try {
      // Get current user data for the response notification
      final currentUser = _notificationService.currentUserId;
      if (currentUser == null) return;

      // Get current user's profile for the notification
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser)
          .get();

      String currentUserName = 'Unknown User';

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        currentUserName = userData['name'] ?? 'Unknown User';
      }

      final title = accepted
          ? 'Challenge Accepted! 🎉'
          : 'Challenge Declined 😔';

      final message = accepted
          ? '$currentUserName accepted your math duel challenge! Get ready to battle!'
          : '$currentUserName declined your math duel challenge.';

      await _notificationService.sendGeneralNotification(
        toUserId: toUserId,
        title: title,
        message: message,
        data: {
          'type': 'challenge_response',
          'accepted': accepted,
          'responderName': currentUserName,
          'originalChallenger': fromUserName,
        },
      );

      // Challenge response notification sent successfully
    } catch (e) {
      // Handle error silently
    }
  }

  void dispose() {
    try {
      hideNotificationPopup();
    } catch (e) {
      // Handle error silently during disposal
    } finally {
      _cleanup();
    }
  }
}