import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';

import '../../../../util/restaurant/order_settings.dart';

class Ordersettings extends StatefulWidget {
  @override
  _orderSettingsState createState() => _orderSettingsState();
}

class _orderSettingsState extends State<Ordersettings>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    OrderSettings.load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.white,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'Order Settings',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 22 : 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12, vertical: 8),
            child: Container(
              padding: EdgeInsets.all(isTablet ? 10 : 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person_rounded,
                  size: isTablet ? 22 : 20, color: AppColors.primary),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: isTablet ? 14 : 13),
          unselectedLabelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500, fontSize: isTablet ? 14 : 13),
          tabs: const [
            Tab(icon: Icon(Icons.takeout_dining_rounded, size: 20), text: 'Take Away'),
            Tab(icon: Icon(Icons.restaurant_rounded, size: 20), text: 'Dine In'),
            Tab(icon: Icon(Icons.delivery_dining_rounded, size: 20), text: 'Delivery'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _takeAwayTab(),
          _dineInTab(),
          _homeDeliveryTab(),
        ],
      ),
    );
  }

  // ── Reusable setting row ─────────────────────────────────────────────────

  Widget _settingRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required ValueNotifier<bool> notifier,
    required Future<void> Function(bool) onSave,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (ctx, val, _) => SwitchListTile(
        value: val,
        onChanged: onSave,
        activeColor: AppColors.primary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(
          title,
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: children),
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, indent: 56, color: AppColors.divider);

  // ── Tab bodies ───────────────────────────────────────────────────────────

  Widget _takeAwayTab() {
    return SingleChildScrollView(
      child: _sectionCard([
        _settingRow(
          icon: Icons.takeout_dining_rounded,
          iconColor: Colors.blue,
          title: 'Enable Take Away',
          subtitle: 'Allow customers to place take-away orders',
          notifier: OrderSettings.enableTakeAwayNotifier,
          onSave: OrderSettings.setEnableTakeAway,
        ),
        _divider(),
        _settingRow(
          icon: Icons.receipt_long_rounded,
          iconColor: Colors.green,
          title: 'Place Order Dialog',
          subtitle: 'Show confirmation dialog before placing order',
          notifier: OrderSettings.showTakeAwayDialogNotifier,
          onSave: OrderSettings.setShowTakeAwayDialog,
        ),
      ]),
    );
  }

  Widget _dineInTab() {
    return SingleChildScrollView(
      child: _sectionCard([
        _settingRow(
          icon: Icons.restaurant_rounded,
          iconColor: Colors.orange,
          title: 'Enable Dine In',
          subtitle: 'Allow customers to dine in at the restaurant',
          notifier: OrderSettings.enableDineInNotifier,
          onSave: OrderSettings.setEnableDineIn,
        ),
        _divider(),
        _settingRow(
          icon: Icons.receipt_long_rounded,
          iconColor: Colors.green,
          title: 'Place Order Dialog',
          subtitle: 'Show confirmation dialog before placing order',
          notifier: OrderSettings.showDineInDialogNotifier,
          onSave: OrderSettings.setShowDineInDialog,
        ),
      ]),
    );
  }

  Widget _homeDeliveryTab() {
    return SingleChildScrollView(
      child: _sectionCard([
        _settingRow(
          icon: Icons.delivery_dining_rounded,
          iconColor: Colors.purple,
          title: 'Enable Home Delivery',
          subtitle: 'Allow customers to place home delivery orders',
          notifier: OrderSettings.enableDeliveryNotifier,
          onSave: OrderSettings.setEnableDelivery,
        ),
      ]),
    );
  }
}
