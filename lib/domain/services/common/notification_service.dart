import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  // Prevents spam — if same message already showing, skip it
  void show(
      String message, {
        Color? color,
        NotificationType type = NotificationType.info,
        IconData? icon,
        Duration duration = const Duration(seconds: 3),
        VoidCallback? onTap,
        bool dismissible = true,
      }) {
    // Prevent duplicate: if same message is already visible, skip
    if (_notifications.any((n) => n.message == message)) return;

    // Max 2 notifications at a time — dismiss oldest if full
    while (_notifications.length >= 2) {
      _dismiss(_notifications.last.id);
    }

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
    listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));

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
      duration: duration ?? const Duration(milliseconds: 1500),
      onTap: onTap,
    );
  }

  void showError(String message, {Duration? duration, VoidCallback? onTap}) {
    show(
      message,
      type: NotificationType.error,
      duration: duration ?? const Duration(seconds: 3),
      onTap: onTap,
    );
  }

  void showWarning(String message, {Duration? duration, VoidCallback? onTap}) {
    show(
      message,
      type: NotificationType.warning,
      duration: duration ?? const Duration(seconds: 2),
      onTap: onTap,
    );
  }

  void showInfo(String message, {Duration? duration, VoidCallback? onTap}) {
    show(
      message,
      type: NotificationType.info,
      duration: duration ?? const Duration(seconds: 2),
      onTap: onTap,
    );
  }

  // Method to dismiss a notification
  void _dismiss(String id) {
    // Find the index of the notification to remove
    final index = _notifications.indexWhere((n) => n.id == id);

    if (index != -1) {
      // Get the notification to be removed for the animation
      final removedItem = _notifications.removeAt(index);

      // Animate the removal from the list
      listKey.currentState?.removeItem(
        index,
            (context, animation) => buildNotificationItem(removedItem, animation),
        duration: const Duration(milliseconds: 300),
      );
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

// Compact notification banner
class NotificationBanner extends StatelessWidget {
  final AppNotification notification;
  const NotificationBanner({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: notification.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _bgColor(notification.type),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: _bgColor(notification.type).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                notification.icon,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  notification.message,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    height: 1.3,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _bgColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return const Color(0xFF388E3C); // green 700
      case NotificationType.error:
        return const Color(0xFFD32F2F); // red 700
      case NotificationType.warning:
        return const Color(0xFFF57C00); // orange 700
      case NotificationType.info:
        return const Color(0xFF1976D2); // blue 700
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
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Your main screen content
        widget.child,

        // The notification list on top - allows touches to pass through to content below
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: true,
            child: AnimatedList(
              key: widget.service.listKey,
              initialItemCount: widget.service.notifications.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index, animation) {
                if (index >= widget.service.notifications.length) {
                  return const SizedBox.shrink();
                }
                // Get the specific notification
                final notification = widget.service.notifications[index];
                // Build the animated item with its own touch handling
                return IgnorePointer(
                  ignoring: false,
                  child: widget.service.buildNotificationItem(notification, animation),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}