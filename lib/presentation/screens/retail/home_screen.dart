import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:unipos/core/di/service_locator.dart';

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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('POS',style: TextStyle(color: Colors.white),),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle,color:Colors.white,),
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
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildMenuCard(
              context,
              icon: Icons.point_of_sale,
              title: 'Billing',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PosScreen()),
                );
              },
            ),
            _buildMenuCard(
              context,
              icon: Icons.inventory,
              title: 'Inventory',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InventoryScreen()),
                );
              },
            ),
            _buildMenuCard(
              context,
              icon: Icons.category,
              title: 'Categories',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CategoryManagementScreen()),
                );
              },
            ),
            _buildMenuCard(
              context,
              icon: Icons.people,
              title: 'Customers',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CustomerListScreen()),
                );
              },
            ),
            _buildMenuCard(
              context,
              icon: Icons.storefront,
              title: 'Suppliers',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SupplierListScreen()),
                );
              },
            ),
            _buildMenuCard(
              context,
              icon: Icons.assignment,
              title: 'Purchase Orders',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PurchaseOrderListScreen()),
                );
              },
            ),
            _buildMenuCard(
              context,
              icon: Icons.shopping_cart,
              title: 'Purchases',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PurchaseHistoryScreen()),
                );
              },
            ),
            _buildMenuCard(
              context,
              icon: Icons.receipt_long,
              title: 'Sales',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SalesHistoryScreen()),
                );
              },
            ),
            _buildMenuCard(
              context,
              icon: Icons.bar_chart,
              title: 'Reports',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReportsScreen()),
                );
              },
            ),
            _buildStockAlertCard(context),
            _buildMenuCard(
              context,
              icon: Icons.settings,
              title: 'Settings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
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
            Icon(icon, size: 40, color: Theme.of(context).primaryColor),
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
                      color: hasCritical ? Colors.red : Theme.of(context).primaryColor,
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