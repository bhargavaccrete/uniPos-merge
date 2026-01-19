import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/presentation/screens/retail/ex/posscreen.dart';
import 'package:unipos/util/color.dart';
import 'package:unipos/util/responsive.dart';
import 'package:unipos/util/color.dart';

import 'package:unipos/presentation/screens/retail/pos_screen.dart';
import 'package:unipos/presentation/screens/retail/inventory_screen.dart';
import 'package:unipos/presentation/screens/retail/customer_list_screen.dart';
import 'package:unipos/presentation/screens/retail/reports_screen.dart';
import 'package:unipos/presentation/screens/retail/stock_alerts_screen.dart';
import 'package:unipos/presentation/screens/retail/supplier_list_screen.dart';
import 'package:unipos/presentation/screens/retail/purchase_history_screen.dart';
import 'package:unipos/presentation/screens/retail/purchase_order_list_screen.dart';
import 'package:unipos/presentation/screens/retail/sales_history_screen.dart';
import 'package:unipos/presentation/screens/retail/settings_screen.dart';
import 'package:unipos/presentation/screens/retail/category_management_screen.dart';
import 'package:unipos/presentation/screens/retail/login_screen.dart';
import 'package:unipos/presentation/screens/retail/change_password_screen.dart';

import 'package:unipos/data/models/retail/hive_model/sale_model_203.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Responsive(
          mobile: _buildMobileLayout(context),
          tablet: _buildTabletLayout(context),
          desktop: _buildDesktopLayout(context),
        ),
      ),
    );
  }

  // ==================== MOBILE LAYOUT ====================
  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        _buildMobileHeader(context),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                  children: _buildAllMenuCards(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== TABLET LAYOUT ====================
  Widget _buildTabletLayout(BuildContext context) {
    return Column(
      children: [
        _buildTabletHeader(context),
        Expanded(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 900),
              padding: const EdgeInsets.all(24),
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.1,
                children: _buildAllMenuCards(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== DESKTOP LAYOUT ====================
  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        _buildDesktopSidebar(context),
        Expanded(
          child: Column(
            children: [
              _buildDesktopHeader(context),
              Expanded(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    padding: const EdgeInsets.all(32),
                    child: GridView.count(
                      crossAxisCount: 4,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: 0.95,
                      children: _buildAllMenuCards(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== HEADERS ====================
  Widget _buildMobileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'UniPOS Dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          _buildUserMenuButton(context, Colors.white),
        ],
      ),
    );
  }

  Widget _buildTabletHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.store, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'UniPOS Dashboard',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          _buildUserMenuButton(context, Colors.white),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkNeutral,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your business operations',
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          _buildUserMenuButton(context, AppColors.primary),
        ],
      ),
    );
  }

  // ==================== DESKTOP SIDEBAR ====================
  Widget _buildDesktopSidebar(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo/Brand section
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.store, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'UniPOS',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),

          // Quick Stats
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Stats',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Observer(
                  builder: (context) {
                    final now = DateTime.now();
                    final todayStart = DateTime(now.year, now.month, now.day);
                    final todaySales = saleStore.sales.where((sale) {
                      try {
                        final saleDate = DateTime.parse(sale.createdAt);
                        return saleDate.isAfter(todayStart) || saleDate.isAtSameMomentAs(todayStart);
                      } catch (_) {
                        return false;
                      }
                    });
                    final total = todaySales.fold(0.0, (sum, sale) => sum + (sale.grandTotal ?? sale.totalAmount));
                    return _buildStatItem(Icons.receipt_long, 'Today\'s Sales', '₹${total.toStringAsFixed(2)}', Colors.white);
                  },
                ),
                const SizedBox(height: 12),
                Observer(
                  builder: (context) => _buildStatItem(Icons.inventory, 'Products', '${productStore.products.length}', Colors.white),
                ),
                const SizedBox(height: 12),
                Observer(
                  builder: (context) => _buildStatItem(Icons.people, 'Customers', '${customerStore.customers.length}', Colors.white),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Footer
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),
                Text(
                  '© 2025 UniPOS',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== USER MENU ====================
  Widget _buildUserMenuButton(BuildContext context, Color iconColor) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.account_circle, color: iconColor, size: 28),
      offset: const Offset(0, 50),
      onSelected: (value) async {
        switch (value) {
          case 'change_password':
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
            );
            break;
          case 'logout':
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Are you sure you want to logout?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Logout'),
                  ),
                ],
              ),
            );
            if (confirmed == true && context.mounted) {
              await authService.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            }
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'change_password',
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 20, color: const Color(0xFF6B6B6B)),
              const SizedBox(width: 12),
              const Text('Change Password'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: Colors.red),
              const SizedBox(width: 12),
              Text('Logout', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== MENU CARDS ====================
  List<Widget> _buildAllMenuCards(BuildContext context) {
    return [
      _buildMenuCard(
        context,
        icon: Icons.point_of_sale,
        title: 'Billing',
        // onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PosScreen())),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RetailPosScreen())),
      ),
      _buildMenuCard(
        context,
        icon: Icons.inventory,
        title: 'Inventory',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryScreen())),
      ),
      _buildMenuCard(
        context,
        icon: Icons.category,
        title: 'Categories',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CategoryManagementScreen())),
      ),
      _buildMenuCard(
        context,
        icon: Icons.people,
        title: 'Customers',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomerListScreen())),
      ),
      _buildMenuCard(
        context,
        icon: Icons.storefront,
        title: 'Suppliers',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SupplierListScreen())),
      ),
      _buildMenuCard(
        context,
        icon: Icons.assignment,
        title: 'Purchase Orders',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PurchaseOrderListScreen())),
      ),
      _buildMenuCard(
        context,
        icon: Icons.shopping_cart,
        title: 'Purchases',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PurchaseHistoryScreen())),
      ),
      _buildMenuCard(
        context,
        icon: Icons.receipt_long,
        title: 'Sales',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesHistoryScreen())),
      ),
      _buildMenuCard(
        context,
        icon: Icons.bar_chart,
        title: 'Reports',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsScreen())),
      ),
      _buildStockAlertCard(context),
      _buildMenuCard(
        context,
        icon: Icons.settings,
        title: 'Settings',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
      ),

      // _buildMenuCard(
      //   context,
      //   icon: Icons.settings,
      //   title: 'ex pos',
      //   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RetailPosScreen())),
      // ),
    ];
  }

  Widget _buildMenuCard(BuildContext context,
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockAlertCard(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const StockAlertsScreen()),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Observer(
              builder: (_) {
                final alertCount = stockAlertStore.totalAlerts;
                final hasCritical = stockAlertStore.hasCriticalAlerts;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.notifications_active,
                      size: 40,
                      color: hasCritical ? Colors.red : AppColors.primary,
                    ),
                    if (alertCount > 0)
                      Positioned(
                        right: -8,
                        top: -8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: hasCritical ? Colors.red : const Color(0xFFFF9800),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Text(
                            alertCount > 99 ? '99+' : '$alertCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Stock Alerts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}