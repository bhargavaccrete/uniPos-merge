import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/constants/restaurant/color.dart';
enum NotificationType {
  success,
  error,
  warning,
  info,
}

// A model for our notification
class AppNotification {
  final String id;
  final String message;
  final Color color;
  final NotificationType type;
  final IconData? icon;
  final Duration duration;
  final VoidCallback? onTap;
  final bool dismissible;

  AppNotification({
    required this.message,
    required this.color,
    this.type = NotificationType.info,
    this.icon,
    this.duration = const Duration(seconds: 3),
    this.onTap,
    this.dismissible = true,
  }) : id = UniqueKey().toString();
}

// The service that manages the list of notifications
class NotificationService {


  NotificationService._();

  // 2. The single, static instance of the service.
  static final NotificationService instance = NotificationService._();

  // Use a GlobalKey for the AnimatedList
  final GlobalKey<AnimatedListState> listKey = GlobalKey<AnimatedListState>();

  // The list of notifications
  final List<AppNotification> _notifications = [];

  // Getter for the notifications
  List<AppNotification> get notifications => _notifications;

  // Method to add a new notification
  void show(
      String message, {
        Color? color,
        NotificationType type = NotificationType.info,
        IconData? icon,
        Duration duration = const Duration(seconds: 3),
        VoidCallback? onTap,
        bool dismissible = true,
      }) {
    // Determine color based on type if not provided
    color ??= _getColorForType(type);
    icon ??= _getIconForType(type);

    final notification = AppNotification(
      message: message,
      color: color,
      type: type,
      icon: icon,
      duration: duration,
      onTap: onTap,
      dismissible: dismissible,
    );

    // Add to the list and insert into the AnimatedList
    _notifications.insert(0, notification);
    listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 500));

    // Set a timer to automatically remove the notification
    if (dismissible) {
      Timer(duration, () => _dismiss(notification.id));
    }
  }

  // Convenience methods for different notification types
  void showSuccess(String message, {Duration? duration, VoidCallback? onTap}) {
    show(
      message,
      type: NotificationType.success,
      duration: duration ?? const Duration(seconds: 2),
      onTap: onTap,
    );
  }

  void showError(String message, {Duration? duration, VoidCallback? onTap}) {
    show(
      message,
      type: NotificationType.error,
      duration: duration ?? const Duration(seconds: 4),
      onTap: onTap,
    );
  }

  void showWarning(String message, {Duration? duration, VoidCallback? onTap}) {
    show(
      message,
      type: NotificationType.warning,
      duration: duration ?? const Duration(seconds: 3),
      onTap: onTap,
    );
  }

  void showInfo(String message, {Duration? duration, VoidCallback? onTap}) {
    show(
      message,
      type: NotificationType.info,
      duration: duration ?? const Duration(seconds: 3),
      onTap: onTap,
    );
  }

  // Method to dismiss a notification
  void _dismiss(String id) {
    print('🔥 _dismiss called for id: $id');
    print('🔥 Current notifications count: ${_notifications.length}');

    // Find the index of the notification to remove
    final index = _notifications.indexWhere((n) => n.id == id);
    print('🔥 Found notification at index: $index');

    if (index != -1) {
      // Get the notification to be removed for the animation
      final removedItem = _notifications.removeAt(index);
      print('🔥 Removed notification: ${removedItem.message}');

      // Animate the removal from the list
      listKey.currentState?.removeItem(
        index,
            (context, animation) => buildNotificationItem(removedItem, animation),
        duration: const Duration(milliseconds: 300),
      );
      print('🔥 Animation triggered for removal');
    } else {
      print('🔥 Notification not found with id: $id');
    }
  }

  // Public method to manually dismiss a notification
  void dismiss(String id) {
    _dismiss(id);
  }

  // Method to clear all notifications
  void clearAll() {
    final count = _notifications.length;
    for (int i = count - 1; i >= 0; i--) {
      final removedItem = _notifications.removeAt(i);
      listKey.currentState?.removeItem(
        i,
            (context, animation) => buildNotificationItem(removedItem, animation),
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  // Helper method to get color for notification type
  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Colors.green.shade100;
      case NotificationType.error:
        return Colors.red.shade100;
      case NotificationType.warning:
        return Colors.orange.shade100;
      case NotificationType.info:
        return Colors.blue.shade100;
    }
  }

  // Helper method to get icon for notification type
  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.info:
        return Icons.info;
    }
  }

  // Enhanced animation for notification items
  Widget buildNotificationItem(AppNotification notification, Animation<double> animation) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      )),
      child: FadeTransition(
        opacity: animation,
        child: NotificationBanner(notification: notification),
      ),
    );
  }
}
// A modern widget to display the notification content
class NotificationBanner extends StatelessWidget {
  final AppNotification notification;
  const NotificationBanner({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: notification.onTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: notification.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getBorderColor(notification.type),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              if (notification.icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _getIconBackgroundColor(notification.type),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    notification.icon,
                    size: 18,
                    color: _getIconColor(notification.type),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  notification.message,
                  style: GoogleFonts.poppins(
                    color: _getTextColor(notification.type),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.2,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              if (notification.dismissible)
                GestureDetector(
                  onTap: () {
                    print('🔥 Dismiss button tapped for notification: ${notification.id}');
                    NotificationService.instance.dismiss(notification.id);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: _getTextColor(notification.type).withOpacity(0.8),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBorderColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Colors.green.shade300;
      case NotificationType.error:
        return Colors.red.shade300;
      case NotificationType.warning:
        return Colors.orange.shade300;
      case NotificationType.info:
        return primarycolor;
    }
  }

  Color _getIconBackgroundColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Colors.green.shade50;
      case NotificationType.error:
        return Colors.red.shade50;
      case NotificationType.warning:
        return Colors.orange.shade50;
      case NotificationType.info:
        return primarycolor.withOpacity(0.1);
    }
  }

  Color _getIconColor(NotificationType type) {

    switch (type) {
      case NotificationType.success:
        return Colors.green.shade600;
      case NotificationType.error:
        return Colors.red.shade600;
      case NotificationType.warning:
        return Colors.orange.shade600;
      case NotificationType.info:
        return primarycolor;
    }
  }

  Color _getTextColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Colors.green.shade800;
      case NotificationType.error:
        return Colors.red.shade800;
      case NotificationType.warning:
        return Colors.orange.shade800;
      case NotificationType.info:
        return primarycolor;
    }
  }
}



class NotificationOverlay extends StatefulWidget {
  final Widget child;
  final NotificationService service;

  const NotificationOverlay({
    super.key,
    required this.child,
    required this.service,
  });

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay> {
  bool _isIgnoring = true; // Start with ignoring enabled (no notifications)

  @override
  void initState() {
    super.initState();
    // Listen to notification changes
    _updateIgnoringState();
  }

  @override
  void didUpdateWidget(NotificationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateIgnoringState();
  }

  void _updateIgnoringState() {
    // Update the state whenever we rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final hasNotifications = widget.service.notifications.isNotEmpty;
        if (_isIgnoring == hasNotifications) {
          setState(() {
            _isIgnoring = !hasNotifications;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Your main screen content
        widget.child,

        // The notification list on top - wrapped with IgnorePointer
        IgnorePointer(
          ignoring: _isIgnoring,
          child: Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: AnimatedList(
              key: widget.service.listKey,
              initialItemCount: widget.service.notifications.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index, animation) {
                // Update ignoring state when list changes
                _updateIgnoringState();

                if (index >= widget.service.notifications.length) {
                  return const SizedBox.shrink();
                }
                // Get the specific notification
                final notification = widget.service.notifications[index];
                // Build the animated item
                return widget.service.buildNotificationItem(notification, animation);
              },
            ),
          ),
        ),
      ],
    );
  }
}