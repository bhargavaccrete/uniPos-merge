import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/services/common/local_notification_service.dart';
import 'package:billberrylite/domain/services/restaurant/notification_sync_service.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/data/models/restaurant/dashboard_alert.dart';
import 'package:billberrylite/data/models/restaurant/db/app_notification_model.dart';
import 'package:billberrylite/data/models/restaurant/notification_presenter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await notificationStore.load();
    await NotificationSyncService.runStartupChecks();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Notifications',
        centerTitle: false,
        actions: [
          // TEMP diagnostic: fires the OS plugin directly, bypassing the store
          // throttle. Remove once notifications are confirmed working.
          IconButton(
            tooltip: 'Diagnose notifications',
            icon: const Icon(Icons.bug_report, color: Colors.white),
            onPressed: () async {
              final report =
                  await LocalNotificationService.instance.debugProbe();
              if (!context.mounted) return;
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Notification Diagnostics'),
                  content: SingleChildScrollView(
                    child: SelectableText(report,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          TextButton(
            onPressed: () => notificationStore.markAllRead(),
            child: const Text(
              'Mark All Read',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Observer(
        builder: (context) {
          final critical = notificationStore.critical;
          final warning = notificationStore.warning;
          final info = notificationStore.info;
          final isEmpty = critical.isEmpty && warning.isEmpty && info.isEmpty;

          if (isEmpty) return _buildEmptyState();

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 36.0 : 16.0,
              vertical: 20.0,
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (critical.isNotEmpty) ...[
                      _buildSectionHeader('Critical Alerts', Colors.red.shade700),
                      const SizedBox(height: 10),
                      ...critical.map(_buildAlertCard),
                      const SizedBox(height: 24),
                    ],
                    if (warning.isNotEmpty) ...[
                      _buildSectionHeader('Warnings', Colors.orange.shade700),
                      const SizedBox(height: 10),
                      ...warning.map(_buildAlertCard),
                      const SizedBox(height: 24),
                    ],
                    if (info.isNotEmpty) ...[
                      _buildSectionHeader('Announcements & Updates', Colors.blue.shade700),
                      const SizedBox(height: 10),
                      ...info.map(_buildAlertCard),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 72,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'All Caught Up! 🎉',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You have no active alerts or notifications.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary.withOpacity(0.8),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertCard(AppNotificationModel n) {
    final view = NotificationPresenter.present(n);
    Color severityColor;
    switch (view.severity) {
      case AlertSeverity.critical:
        severityColor = Colors.red.shade700;
        break;
      case AlertSeverity.warning:
        severityColor = Colors.orange.shade700;
        break;
      case AlertSeverity.info:
        severityColor = Colors.blue.shade700;
        break;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        notificationStore.markRead(n.id);
        if (view.route != null) {
          Navigator.pushNamed(context, view.route!).then((_) => _refresh());
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: n.isRead ? Colors.white : severityColor.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider.withOpacity(0.8), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(view.icon, color: severityColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          view.title,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: severityColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    view.body,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _timeAgo(n.timestamp),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecondary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }
}
