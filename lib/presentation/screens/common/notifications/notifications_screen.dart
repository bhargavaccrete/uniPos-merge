import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/plan/mode_keys.dart';
import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/routes/notification_routes.dart';
import 'package:billberrylite/domain/services/common/local_notification_service.dart';
import 'package:billberrylite/domain/services/common/notification_sync.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/data/models/common/dashboard_alert.dart';
import 'package:billberrylite/data/models/common/app_notification_model.dart';
import 'package:billberrylite/data/models/common/notification_presenter.dart';

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
    await NotificationSync.runStartupChecks();
  }

  /// Entitlement key a notification's target route requires, or null when the
  /// route is intentionally ungated (EndDay, Licensing stay reachable). Keeps
  /// notification taps from landing on AccessDenied for an ungranted module.
  ///
  /// Compared against the resolved route rather than a literal, because the
  /// same event lands on a different screen per vertical — restaurant's
  /// Inventory, retail's Stock Alerts / Expiry Alerts. `ModeKeys.inventory`
  /// picks the matching entitlement namespace.
  String? _routeEntitlement(String route) {
    if (route == NotificationRoutes.lowStock ||
        route == NotificationRoutes.expiry) {
      return ModeKeys.inventory;
    }
    return null;
  }

  Future<void> _confirmClearAll() async {
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Clear All Notifications',
      message: 'Remove all notifications? This cannot be undone.',
      confirmLabel: 'Clear All',
      accent: AppColors.danger,
      icon: Icons.delete_sweep_rounded,
    );
    if (!ok) return;
    await notificationStore.clearAll();
    NotificationService.instance.showSuccess('Notifications cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Notifications',
        centerTitle: false,
        actions: _buildActions(context),
      ),
      body: Observer(
        builder: (context) {
          final critical = notificationStore.critical;
          final warning = notificationStore.warning;
          final info = notificationStore.info;

          if (critical.isEmpty && warning.isEmpty && info.isEmpty) {
            return const AppEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'All Caught Up! 🎉',
              message: 'You have no active alerts or notifications.',
            );
          }

          final headerGap = AppResponsive.smallSpacing(context);
          final sectionGap = AppResponsive.extraLargeSpacing(context);

          return SingleChildScrollView(
            padding: AppResponsive.padding(context),
            // A notification feed is prose, not scannable tiles, so it stays a
            // single reading column at every width — going multi-column at
            // 1920 would make it harder to read. maxFormWidth IS that ladder
            // (600 tablet / 800 desktop); its infinity on mobile is correct
            // here, because a phone should render the feed edge to edge.
            child: AppResponsive.constrainedContent(
              context: context,
              maxWidth: AppResponsive.maxContentWidth(context),
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (critical.isNotEmpty) ...[
                    _buildSectionHeader('Critical Alerts', Colors.red.shade700),
                    SizedBox(height: headerGap),
                    ...critical.map(_buildAlertCard),
                    SizedBox(height: sectionGap),
                  ],
                  if (warning.isNotEmpty) ...[
                    _buildSectionHeader('Warnings', Colors.orange.shade700),
                    SizedBox(height: headerGap),
                    ...warning.map(_buildAlertCard),
                    SizedBox(height: sectionGap),
                  ],
                  if (info.isNotEmpty) ...[
                    _buildSectionHeader(
                      'Announcements & Updates',
                      Colors.blue.shade700,
                    ),
                    SizedBox(height: headerGap),
                    ...info.map(_buildAlertCard),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// AppBar actions.
  ///
  /// On a phone the two text buttons ate ~205px of a 360px AppBar, leaving the
  /// title ~99px — and ~51px in a debug build, where the probe icon is present
  /// too. Secondary actions collapse to icons on mobile (the project
  /// convention) and keep their labels once there is room.
  List<Widget> _buildActions(BuildContext context) {
    final compact = AppResponsive.isMobile(context);
    return [
      // Diagnostic: fires the OS plugin directly, bypassing the store
      // throttle. Debug builds only — it is a developer tool, and the screen
      // is shared with retail.
      if (kDebugMode)
        IconButton(
          tooltip: 'Diagnose notifications',
          icon: Icon(
            Icons.bug_report,
            color: Colors.white,
            size: AppResponsive.iconSize(context),
          ),
          onPressed: () => _showDiagnostics(context),
        ),
      _appBarAction(
        context,
        compact: compact,
        icon: Icons.done_all_rounded,
        label: 'Mark All Read',
        onPressed: () => notificationStore.markAllRead(),
      ),
      // Clear All — removes every notification (hidden when there is none).
      Observer(
        builder: (_) {
          final hasAny =
              notificationStore.critical.isNotEmpty ||
              notificationStore.warning.isNotEmpty ||
              notificationStore.info.isNotEmpty;
          if (!hasAny) return const SizedBox.shrink();
          return _appBarAction(
            context,
            compact: compact,
            icon: Icons.delete_sweep_rounded,
            label: 'Clear All',
            onPressed: _confirmClearAll,
          );
        },
      ),
    ];
  }

  Widget _appBarAction(
    BuildContext context, {
    required bool compact,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    if (compact) {
      return IconButton(
        tooltip: label,
        icon: Icon(
          icon,
          color: Colors.white,
          size: AppResponsive.iconSize(context),
        ),
        onPressed: onPressed,
      );
    }
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: AppResponsive.bodyFontSize(context),
        ),
      ),
    );
  }

  /// Developer-only probe dialog. Monospace is kept from the original: the
  /// payload is raw `key: value` output including exception text, not UI copy.
  Future<void> _showDiagnostics(BuildContext context) async {
    final report = await LocalNotificationService.instance.debugProbe();
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialogShell(
        title: 'Notification Diagnostics',
        accent: AppColors.primary,
        icon: Icons.bug_report_rounded,
        // The shell already wraps `body` in a scrolling Flexible.
        body: SelectableText(
          report,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: AppResponsive.smallFontSize(context),
          ),
        ),
        actions: [
          appDialogPrimaryButton(
            label: 'Close',
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          // Hairline accent: width and corner stay static (they are decorative,
          // not layout), but the height tracks the label beside it.
          width: 4,
          height: AppResponsive.smallIconSize(context),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: AppResponsive.smallSpacing(context)),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary.withValues(alpha: 0.8),
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
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      onTap: () {
        notificationStore.markRead(n.id);
        final route = view.route;
        if (route == null) return;
        // A notification can fire for a module the plan doesn't include (e.g.
        // low-stock when `inventory` is off). Don't dump the user on an
        // AccessDenied screen — tell them and stay put.
        final entKey = _routeEntitlement(route);
        if (entKey != null && !PlanGuard.allowedOr(context, entKey)) {
          return;
        }
        Navigator.pushNamed(context, route).then((_) => _refresh());
      },
      child: Container(
        margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
        padding: AppResponsive.cardPadding(context),
        decoration: BoxDecoration(
          color: n.isRead
              ? Colors.white
              : severityColor.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          border: Border.all(
            color: AppColors.divider.withValues(alpha: 0.8),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: AppResponsive.shadowBlurRadius(context),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
              decoration: BoxDecoration(
                color: severityColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                view.icon,
                color: severityColor,
                size: AppResponsive.iconSize(context),
              ),
            ),
            SizedBox(width: AppResponsive.mediumSpacing(context)),
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
                            fontSize: AppResponsive.bodyFontSize(context),
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!n.isRead)
                        Container(
                          width: AppResponsive.smallSpacing(context),
                          height: AppResponsive.smallSpacing(context),
                          decoration: BoxDecoration(
                            color: severityColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  // 4 and 6 stay static: the smallest spacing helper is 8, and
                  // snapping these typographic gaps would break the
                  // title/body/timestamp grouping inside the card.
                  const SizedBox(height: 4),
                  Text(
                    view.body,
                    // The message itself — read first, so it snaps UP.
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _timeAgo(n.timestamp),
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
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
