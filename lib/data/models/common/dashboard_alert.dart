import 'package:flutter/widgets.dart';

enum AlertSeverity { critical, warning, info }

enum AlertType {
  dayNotStarted,
  pendingEod,
  licenseExpiring,
  licenseExpired,
  lowStock,
  backupReminder,
  appUpdate,
  announcement,
  releaseNotes,
  promotion,
  generalInfo,
}

class DashboardAlert {
  final String id;
  final String title;
  final String description;
  final AlertSeverity severity;
  final AlertType type;
  final IconData icon;
  final String? actionText;
  final VoidCallback? action;

  DashboardAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.type,
    required this.icon,
    this.actionText,
    this.action,
  });
}
