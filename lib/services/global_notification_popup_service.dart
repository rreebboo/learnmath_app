import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/notification.dart';
import '../widgets/user_avatar.dart';
import '../screens/quiz_duel_screen.dart';
import '../screens/friends_screen.dart';
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
  final Map<String, bool> _deletingNotifications = {};
  final Set<String> _manuallyDeletedIds = {};
  List<AppNotification>? _cachedNotifications;
  ScrollController? _scrollController;

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
      print('Error showing notification popup: $e');
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
      print('Error hiding notification popup: $e');
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
    _iconPosition = null;
    _isClosing = false;
    _cachedNotifications = null;
    _deletingNotifications.clear();
    _manuallyDeletedIds.clear();
    _scrollController?.dispose();
    _scrollController = null;
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
      print('Error showing notification panel: $e');
      _cleanup();
    }
  }

  Widget _buildNotificationIconOrImage(NotificationType type, Map<String, dynamic>? data, bool isSmallScreen) {
    // Check if it's a friend request response and use Flutter icons
    if (type == NotificationType.friendRequestResponse && data != null) {
      final bool? accepted = data['accepted'] as bool?;
      final IconData iconData = accepted == true
          ? Icons.person_add_alt_1
          : Icons.person_remove;
      final Color iconColor = accepted == true
          ? Colors.green.shade600
          : Colors.orange.shade600;

      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          iconData,
          color: iconColor,
          size: isSmallScreen ? 20 : 24,
        ),
      );
    }

    // Default icon-based notification
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getNotificationColor(type).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        _getNotificationIcon(type),
        color: _getNotificationColor(type),
        size: isSmallScreen ? 20 : 24,
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.duelChallenge:
        return Icons.sports_martial_arts;
      case NotificationType.friendRequest:
        return Icons.person_add;
      case NotificationType.friendRequestResponse:
        return Icons.people; // People icon for friend request responses
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
        return Colors.blue.shade600;
      case NotificationType.friendRequestResponse:
        return Colors.blue.shade600; // Blue for friend request responses
      case NotificationType.achievement:
        return Colors.amber.shade600;
      default:
        return Colors.amber.shade600;
    }
  }

  String _cleanTitle(String title) {
    // Remove emojis from title except 🎉
    return title
        .replaceAll('👥✓', '')
        .replaceAll('👤✗', '')
        .replaceAll('👥', '')
        .replaceAll('👤', '')
        .replaceAll('✓', '')
        .replaceAll('✗', '')
        .trim();
  }

  Color _getTitleColor(NotificationType type, Map<String, dynamic>? data) {
    if (type == NotificationType.friendRequestResponse && data != null) {
      final bool? accepted = data['accepted'] as bool?;
      return accepted == true
          ? Colors.green.shade600  // Accepted - Green
          : Colors.orange.shade600; // Declined - Orange
    } else if (type == NotificationType.friendRequest) {
      return Colors.blue.shade600; // Friend request sent - Blue
    }
    return const Color(0xFF2C3E50); // Default color
  }

  Color _getBorderColor(NotificationType type, Map<String, dynamic>? data) {
    if (type == NotificationType.friendRequestResponse && data != null) {
      final bool? accepted = data['accepted'] as bool?;
      return accepted == true
          ? Colors.green.shade600  // Accepted - Green
          : Colors.orange.shade600; // Declined - Orange
    }
    return _getNotificationColor(type); // Use default notification color
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
                        _cleanTitle(notification.title),
                        style: TextStyle(
                          color: _getTitleColor(notification.type, notification.data),
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
        hideNotificationPopup();
        _handleNotificationCardTap(context, notification);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getBorderColor(notification.type, notification.data).withValues(alpha: 0.3),
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
              _buildNotificationIconOrImage(notification.type, notification.data, isSmallScreen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _cleanTitle(notification.title),
                      style: TextStyle(
                        color: _getTitleColor(notification.type, notification.data),
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
    hideNotificationPopup();

    // Mark notification as read
    _notificationService.markAsRead(notification.id);

    // Update the game state so FloatingChallengeWidget can detect the acceptance
    if (notification.data != null && notification.data!['duelId'] != null) {
      await QuizDuelService().acceptChallenge(notification.data!['duelId']);
    }

    // Send notification to challenger that challenge was accepted
    await _sendChallengeResponseNotification(
      toUserId: notification.fromUserId,
      fromUserName: notification.fromUserName ?? 'Unknown User',
      accepted: true,
    );

    // Check if context is still mounted before navigation
    if (!context.mounted) return;

    // Navigate to quiz duel screen if duelId is available
    if (notification.data != null && notification.data!['duelId'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizDuelScreen(
            gameId: notification.data!['duelId'],
            topicName: notification.data!['topicName'] ?? 'Mixed Topics',
            operator: 'mixed', // Default operator for challenges
            difficulty: notification.data!['difficulty'] ?? 'Medium',
          ),
        ),
      );
    }
  }

  Future<void> _declineChallenge(BuildContext context, AppNotification notification) async {
    hideNotificationPopup();

    // Mark notification as read
    _notificationService.markAsRead(notification.id);

    // Send notification to challenger that challenge was declined
    await _sendChallengeResponseNotification(
      toUserId: notification.fromUserId,
      fromUserName: notification.fromUserName ?? 'Unknown User',
      accepted: false,
    );

    // Handle declining the challenge - could update the duel status
    if (notification.data != null && notification.data!['duelId'] != null) {
      QuizDuelService().declineChallenge(notification.data!['duelId']);
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
                scale: 0.8 + (0.2 * value),
                alignment: Alignment.topCenter,
                child: Opacity(
                  opacity: value,
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
          child: Container(
            height: screenHeight * 0.7,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 0),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
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
                  child: StreamBuilder<List<AppNotification>>(
                    stream: _notificationService.streamUserNotifications(),
                    builder: (context, snapshot) {
                      final notifications = snapshot.data ?? [];
                      final hasUnread = notifications.any((n) => !n.isRead);

                      return Row(
                        children: [
                          Text(
                            'Notifications',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: isSmallScreen ? 16 : (hasUnread ? 18 : 20),
                              color: const Color(0xFF2C3E50),
                            ),
                          ),
                          const Spacer(),
                          if (hasUnread)
                            TextButton(
                              onPressed: () {
                                // Check if context is still mounted before performing action
                                if (context.mounted) {
                                  _notificationService.markAllAsRead();
                                }
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 8 : 12,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Mark all',
                                style: TextStyle(
                                  color: Colors.amber.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: isSmallScreen ? 12 : 14,
                                ),
                              ),
                            ),
                          IconButton(
                            onPressed: () async {
                              if (context.mounted) {
                                // Temporarily hide the panel to show dialog on top
                                final shouldClear = await _showClearAllDialogOnTop(context);
                                if (shouldClear == true) {
                                  _notificationService.clearAllNotifications();
                                  // Panel will rebuild automatically when notifications are cleared
                                }
                              }
                            },
                            icon: Icon(
                              Icons.delete_sweep,
                              color: Colors.orange.shade600,
                              size: isSmallScreen ? 20 : 24,
                            ),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            tooltip: 'Clear All',
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: hideNotificationPopup,
                            icon: Icon(
                              Icons.close,
                              color: const Color(0xFF2C3E50),
                              size: isSmallScreen ? 20 : 24,
                            ),
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                            tooltip: 'Close',
                          ),
                        ],
                      );
                    },
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

                      final notifications = snapshot.data ?? [];

                      // Filter out manually deleted notifications
                      final filteredNotifications = notifications
                          .where((n) => !_manuallyDeletedIds.contains(n.id))
                          .toList();

                      // Only update cache if there are actual changes (not during deletion animation)
                      if (_cachedNotifications == null || _deletingNotifications.isEmpty) {
                        _cachedNotifications = filteredNotifications;
                      } else {
                        // During deletion, preserve the cache but add any new notifications
                        final newNotifications = filteredNotifications
                            .where((n) => !_cachedNotifications!.any((cached) => cached.id == n.id))
                            .toList();

                        if (newNotifications.isNotEmpty) {
                          _cachedNotifications = [..._cachedNotifications!, ...newNotifications];
                        }
                      }

                      // Check if truly empty (no notifications and nothing being deleted)
                      if (_cachedNotifications!.isEmpty && _deletingNotifications.isEmpty) {
                        return _buildEmptyNotificationState(isSmallScreen);
                      }

                      // Initialize scroll controller if not exists
                      _scrollController ??= ScrollController();

                      return ListView.builder(
                        controller: _scrollController,
                        key: const ValueKey('notification_list'),
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16,
                          vertical: 8,
                        ),
                        itemCount: _cachedNotifications!.length,
                        addAutomaticKeepAlives: true,
                        cacheExtent: 1000,
                        itemBuilder: (context, index) {
                          // Bounds check to prevent RangeError
                          if (index >= _cachedNotifications!.length) {
                            return const SizedBox.shrink();
                          }

                          final notification = _cachedNotifications![index];
                          final isDeleting = _deletingNotifications[notification.id] ?? false;

                          return AnimatedSize(
                            key: ValueKey('size_${notification.id}'),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 250),
                              opacity: isDeleting ? 0.0 : 1.0,
                              child: AnimatedSlide(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                                offset: isDeleting ? const Offset(1, 0) : Offset.zero,
                                child: isDeleting
                                    ? SizedBox(
                                        height: 0,
                                        key: ValueKey('deleting_${notification.id}'),
                                      )
                                    : _buildNotificationCard(context, notification, isSmallScreen),
                              ),
                            ),
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
    return TweenAnimationBuilder<double>(
      key: ValueKey(notification.id),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuart,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.center,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
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
              _buildCardNotificationIcon(notification.type, isSmallScreen, data: notification.data),
              SizedBox(width: isSmallScreen ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _cleanTitle(notification.title),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                              color: _getTitleColor(notification.type, notification.data),
                            ),
                            softWrap: true,
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4, left: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade600,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
                    ),
                    if (notification.fromUserName != null) ...[
                      SizedBox(height: isSmallScreen ? 6 : 8),
                      Row(
                        children: [
                          UserAvatar(
                            avatar: notification.fromUserAvatar ?? '👤',
                            size: isSmallScreen ? 20 : 24,
                          ),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Expanded(
                            child: Text(
                              'From ${notification.fromUserName}',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10 : 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    Text(
                      _formatTimeAgo(notification.createdAt),
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isSmallScreen ? 4 : 8),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: isSmallScreen ? 18 : 20,
                  color: Colors.orange.shade600,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  // Add to manually deleted set to prevent re-appearance from stream
                  _manuallyDeletedIds.add(notification.id);

                  // Mark as deleting to trigger animation
                  _deletingNotifications[notification.id] = true;

                  // Rebuild to show animation (cache is preserved)
                  _overlayEntry?.markNeedsBuild();

                  // Wait for animation to complete
                  await Future.delayed(const Duration(milliseconds: 350));

                  // Delete from Firestore
                  _notificationService.deleteNotification(notification.id);

                  // Remove from cache now that animation is done
                  _cachedNotifications?.removeWhere((n) => n.id == notification.id);

                  // Clean up deleting state
                  _deletingNotifications.remove(notification.id);

                  // Rebuild to show updated list without the deleted item
                  _overlayEntry?.markNeedsBuild();
                },
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    ),
      ),
    );
  }

  Widget _buildCardNotificationIcon(NotificationType type, bool isSmallScreen, {Map<String, dynamic>? data}) {
    // Check if it's a friend request response and use Flutter icons
    if (type == NotificationType.friendRequestResponse && data != null) {
      final bool? accepted = data['accepted'] as bool?;
      final IconData iconData = accepted == true
          ? Icons.person_add_alt_1
          : Icons.person_remove;
      final Color iconColor = accepted == true
          ? Colors.green.shade600
          : Colors.orange.shade600;

      return Container(
        padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          iconData,
          color: iconColor,
          size: isSmallScreen ? 18 : 20,
        ),
      );
    }

    // Default icon-based notification
    final icon = _getNotificationIcon(type);
    final color = _getNotificationColor(type);

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
    // Check if context is still mounted before proceeding
    if (!context.mounted) return;

    // Mark as read if not already read
    if (!notification.isRead) {
      NotificationService().markAsRead(notification.id);
    }

    // Handle specific notification types
    switch (notification.type) {
      case NotificationType.duelChallenge:
        if (context.mounted) {
          _handleDuelChallenge(context, notification);
        }
        break;
      case NotificationType.friendRequest:
        if (context.mounted) {
          _handleFriendRequest(context, notification);
        }
        break;
      default:
        // For general notifications, open the notification panel
        if (!_isShowing || _overlayEntry == null) {
          // Only show panel if it's not already showing
          showNotificationPanel(context);
        }
        break;
    }
  }

  void _handleDuelChallenge(BuildContext context, AppNotification notification) {
    // Check if context is still mounted before proceeding
    if (!context.mounted) return;

    final duelId = notification.data?['duelId'] as String?;

    if (duelId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid challenge data')),
        );
      }
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              if (context.mounted) {
                Navigator.pop(context);
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
              if (context.mounted) {
                Navigator.pop(context);
                await _acceptDialogChallenge(context, duelId, notification);
              }
            },
            child: const Text('Accept Challenge'),
          ),
        ],
      ),
    );
  }

  void _handleFriendRequest(BuildContext context, AppNotification notification) {
    // Check if context is still mounted before proceeding
    if (!context.mounted) return;

    // Hide the notification popup/panel
    hideNotificationPopup();

    // Navigate to Friends screen with Requests tab (index 1)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FriendsScreen(initialTabIndex: 1),
      ),
    );
  }

  Future<void> _acceptDialogChallenge(BuildContext context, String duelId, AppNotification notification) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Accepting challenge...'),
            ],
          ),
        ),
      );

      final success = await QuizDuelService().acceptChallenge(duelId);

      // Check if context is still mounted before UI operations
      if (!context.mounted) return;

      // Always close loading dialog first
      Navigator.pop(context);

      if (success) {
        // Send notification to challenger
        await _sendChallengeResponseNotification(
          toUserId: notification.fromUserId,
          fromUserName: notification.fromUserName ?? 'Unknown User',
          accepted: true,
        );

        // Check context again after async operation
        if (!context.mounted) return;

        final topicName = notification.data?['topicName'] as String? ?? 'Math Duel';
        final difficulty = notification.data?['difficulty'] as String? ?? 'medium';

        // Navigate to duel screen with gameId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizDuelScreen(
              topicName: topicName,
              operator: 'mixed',
              difficulty: difficulty,
              gameId: duelId,
            ),
          ),
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge accepted! Good luck!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to accept challenge. It may have expired.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error accepting challenge: $e');

      // Make sure loading dialog is closed
      if (context.mounted) {
        try {
          Navigator.pop(context);
        } catch (popError) {
          // Loading dialog might already be closed
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to accept challenge. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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

  Future<bool?> _showClearAllDialogOnTop(BuildContext context) async {
    // Double-check context is still mounted before showing dialog
    if (!context.mounted) return null;

    // Create a completer to handle the async result
    final completer = Completer<bool?>();

    // Create an overlay entry for the dialog that appears on top of the notification panel
    final dialogOverlay = OverlayEntry(
      builder: (context) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 200),
        tween: Tween<double>(begin: 0, end: 1),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Material(
              color: Colors.black.withValues(alpha: 0.6 * value),
              child: Center(
                child: Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: child,
                ),
              ),
            ),
          );
        },
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.delete_sweep,
                color: Colors.orange.shade600,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Clear All Notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to clear all notifications? This action cannot be undone.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!completer.isCompleted) {
                  completer.complete(false);
                }
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (!completer.isCompleted) {
                  completer.complete(true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Clear All',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Insert dialog overlay on top of notification panel
    final overlayState = Overlay.of(context);
    overlayState.insert(dialogOverlay);

    // Wait for user response
    final result = await completer.future;

    // Remove the dialog overlay with a smooth fade out
    try {
      await Future.delayed(const Duration(milliseconds: 150));
      if (overlayState.mounted) {
        dialogOverlay.remove();
      }
    } catch (e) {
      dialogOverlay.remove();
    }

    return result;
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

      print('Challenge response notification sent successfully');
    } catch (e) {
      print('Error sending challenge response notification: $e');
    }
  }

  void dispose() {
    try {
      hideNotificationPopup();
    } catch (e) {
      print('Error during disposal: $e');
    } finally {
      _cleanup();
    }
  }
}