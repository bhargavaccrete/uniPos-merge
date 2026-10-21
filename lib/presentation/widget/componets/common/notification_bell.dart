import 'package:flutter/material.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/core/routes/notification_routes.dart';

/// AppBar bell with an unread badge, wired to the shared notification store.
///
/// Lifted verbatim out of the restaurant dashboard so retail can show the same
/// control instead of growing a third copy. The count is a MobX `@computed`, so
/// the `Observer` repaints whenever a notification is raised, read or resolved.
///
/// [tint] is the icon colour: white over the primary AppBar, `AppColors.primary`
/// on retail's desktop header, which has a light background and no AppBar.
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    this.tint = Colors.white,
    this.iconSize,
    this.route,
  });

  final Color tint;

  /// Null resolves to [AppResponsive.iconSize] (20/22/24). A default parameter
  /// cannot read `context`, so the old `= 22` was fixed at every breakpoint;
  /// resolving in build() is the only way to make the fallback responsive.
  final double? iconSize;

  /// Defaults to whichever notifications route belongs to the current mode.
  final String? route;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final count = notificationStore.unreadCount;
        final resolvedIconSize = iconSize ?? AppResponsive.iconSize(context);
        return Padding(
          padding: EdgeInsets.only(right: AppResponsive.mediumSpacing(context)),
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(
                    count > 0
                        ? Icons.notifications_rounded
                        : Icons.notifications_none_rounded,
                    color: tint,
                    size: resolvedIconSize,
                  ),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    route ?? NotificationRoutes.self,
                  ),
                ),
                if (count > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        // Three digits overflow the 16px pill, and "how many
                        // exactly" stops mattering long before then.
                        count > 99 ? '99+' : '$count',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
