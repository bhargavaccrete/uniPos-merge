import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/core/plan/plan_guard.dart';
import 'package:billberrylite/core/plan/retail_entitlement_keys.dart';
import 'package:billberrylite/domain/services/retail/stock_adjustment_service.dart';
import 'package:billberrylite/presentation/screens/retail/assemble_kit_screen.dart';
import 'package:billberrylite/presentation/screens/retail/bundles_screen.dart';
import 'package:billberrylite/presentation/screens/retail/expiry_alerts_screen.dart';
import 'package:billberrylite/presentation/screens/retail/product_management_screen.dart';
import 'package:billberrylite/presentation/screens/retail/stock_alerts_screen.dart';
import 'package:billberrylite/presentation/screens/retail/stock_take_list_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';

/// One entrance for every stock task. Each tile opens an existing screen —
/// the hub owns no logic, only navigation and the per-tile gates.
///
/// The home card already applied the `inventory` role and plan key; tiles that
/// write stock additionally need `inventoryAdjust`, and Stock Levels needs
/// `catalog` because it opens the Products hub.
class InventoryHubScreen extends StatelessWidget {
  const InventoryHubScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final canAdjust = StockAdjustmentService.canAdjust;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Inventory'),
      body: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        child: ListView(
          padding: AppResponsive.padding(context),
          children: [
            _sectionHeader(context, 'STOCK'),
            if (RestaurantSession.canAccess('catalog'))
              _tile(
                context,
                icon: Icons.inventory_2_rounded,
                title: 'Stock Levels',
                subtitle: 'View stock, adjust counts, see stock history',
                color: Colors.amber.shade700,
                onTap: () => _push(context, const ProductManagementScreen()),
              ),
            if (canAdjust)
              _tile(
                context,
                icon: Icons.fact_check_outlined,
                title: 'Stock Takes',
                subtitle: 'Count shelves and apply the variance',
                color: Colors.blue,
                onTap: () {
                  if (!PlanGuard.allowedOr(
                    context,
                    RetailEntKeys.inventoryStockTake,
                    featureName: 'Stock Take',
                  )) {
                    return;
                  }
                  _push(context, const StockTakeListScreen());
                },
              ),
            if (canAdjust) ...[
              _sectionHeader(context, 'BUNDLES & KITS'),
              _tile(
                context,
                icon: Icons.inventory_rounded,
                title: 'Assemble Kit',
                subtitle: 'Build repack/kit units from their components',
                color: Colors.teal,
                onTap: () => _push(context, const AssembleKitScreen()),
              ),
              _tile(
                context,
                icon: Icons.widgets_outlined,
                title: 'Bundles',
                subtitle: 'Bundles and kits with available-to-sell',
                color: Colors.indigo,
                onTap: () => _push(context, const BundlesScreen()),
              ),
            ],
            _sectionHeader(context, 'ALERTS'),
            _tile(
              context,
              icon: Icons.notifications_active_rounded,
              title: 'Stock Alerts',
              subtitle: 'Items at or below their reorder point',
              color: Colors.deepOrange,
              onTap: () => _push(context, const StockAlertsScreen()),
            ),
            _tile(
              context,
              icon: Icons.event_busy_rounded,
              title: 'Expiry Alerts',
              subtitle: 'Expired and soon-to-expire items',
              color: AppColors.danger,
              onTap: () => _push(context, const ExpiryAlertsScreen()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 4,
        vertical: AppResponsive.smallSpacing(context),
      ),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.captionFontSize(context),
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(
              AppResponsive.smallBorderRadius(context),
            ),
          ),
          child: Icon(icon, color: color, size: AppResponsive.iconSize(context)),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.captionFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
