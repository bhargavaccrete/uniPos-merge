
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/intl.dart';
import 'package:unipos/util/color.dart';

import '../../../../data/models/restaurant/db/database/hive_Table.dart';
import '../../../../data/models/restaurant/db/database/hive_order.dart';
import '../../../../data/models/restaurant/db/table_Model_311.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../start order/cart/cart.dart';
import '../start order/startorder.dart';
import '../../../../util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';

class TableScreen extends StatefulWidget {
  final bool? isfromcart;
  const TableScreen({super.key, this.isfromcart= false});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  late Future<List<TableModel>> _tablesFuture;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  void _loadTables() {
    setState(() {
      _tablesFuture = HiveTables.getAllTables();
    });
  }

  void _addTable() {
    final Tcontroller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add New Tablee',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Container(
          width: 300,
          child: TextField(
            controller: Tcontroller,
            autofocus: true,
            style: GoogleFonts.poppins(),
            decoration: InputDecoration(
              hintText: 'Enter Table Name (e.g., T-4)',
              hintStyle: GoogleFonts.poppins(color: AppColors.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (Tcontroller.text.isNotEmpty) {
                final newTable = TableModel(id: Tcontroller.text.trim());
                await HiveTables.addTable(newTable);
                Navigator.pop(context);
                _loadTables();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Add',
              style: GoogleFonts.poppins(color: AppColors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(
        children: [
          // Add Table Button and Legend
          Container(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            color: AppColors.white,
            child: Column(
              children: [
                // Add Table Button
                GestureDetector(
                  onTap: _addTable,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: isTablet ? 18 : 16),
                    decoration: BoxDecoration(
                      color: AppColors.tablesTab,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.tablesTab.withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: AppColors.white, size: isTablet ? 22 : 20),
                        SizedBox(width: isTablet ? 10 : 8),
                        Text(
                          'Add Table',
                          style: GoogleFonts.poppins(
                            color: AppColors.white,
                            fontSize: isTablet ? 17 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: isTablet ? 20 : 16),
                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLegendItem(AppColors.success, 'Available', isTablet),
                    _buildLegendItem(AppColors.warning, 'Reserved', isTablet),
                    _buildLegendItem(AppColors.danger, 'Occupied', isTablet),
                  ],
                ),
              ],
            ),
          ),

          // Tables Grid
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Hive.box<TableModel>('tablesBox').listenable(),
              builder: (context, table, _) {
                if (table.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.table_restaurant_outlined,
                          size: 80,
                          color: AppColors.divider,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No tables found.',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add one to get started.',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                dynamic allTable = table.values.toList();

                // Responsive grid columns
                final size = MediaQuery.of(context).size;
                final isTablet = size.width > 600;
                final crossAxisCount = isTablet ? 4 : 2;

                return GridView.builder(
                  padding: EdgeInsets.all(20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: allTable.length,
                  itemBuilder: (context, index) {
                    final table = allTable[index];
                    return TableCard(
                      table: table,
                      onTap: () async {
                        // SCENARIO 1: Table is OCCUPIED (includes Cooking, Reserved, Running, Served)
                        if (table.status == 'Cooking' || table.status == 'Reserved' || table.status == 'Running'|| table.status == 'Ready'  || table.status == 'Served') {
                          final existingOrder = await HiveOrders.getActiveOrderByTableId(table.id);

                          if (existingOrder != null) {
                            final appStateBox = Hive.box('app_state');
                            await appStateBox.put('is_existing_order', true);
                            await appStateBox.put('table_id', existingOrder.tableNo);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CartScreen(
                                  existingOrder: existingOrder,
                                  selectedTableNo: table.id,
                                ),
                              ),
                            );
                          } else {
                            NotificationService.instance.showError(
                              'Could not find an active order for Table ${table.id}.',
                            );
                          }
                        }
                        // SCENARIO 2: Table is AVAILABLE
                        else {
                          if (widget.isfromcart == true) {
                            print(table.id);
                            Navigator.pop(context, table.id);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Startorder(newOrderForTableId: table.id),
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text, bool isTablet) {
    return Row(
      children: [
        Container(
          width: isTablet ? 14 : 12,
          height: isTablet ? 14 : 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: isTablet ? 10 : 8),
        Text(
          text,
          style: GoogleFonts.poppins(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: isTablet ? 15 : 13,
          ),
        ),
      ],
    );
  }
}

/// A reusable widget to display a single table card.
class TableCard extends StatelessWidget {
  final TableModel table;
  final VoidCallback onTap;

  const TableCard({super.key, required this.table, required this.onTap});

  String _formatOrderTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';

    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return DateFormat('hh:mm a').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    switch (table.status) {
      case 'Cooking':
      case 'Running':
        statusColor = AppColors.danger;
        break;
      case 'Reserved':
        statusColor = AppColors.warning;
        break;
      default: // Available
        statusColor = AppColors.success;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main content of the card
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    table.id,
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (table.status != 'Available') ...[
                    SizedBox(height: 12),
                    Text(
                      '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(table.currentOrderTotal ?? 0.0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person, size: 14, color: AppColors.textSecondary),
                        SizedBox(width: 4),
                        Text(
                          '#Admin',
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (table.timeStamp != null && table.timeStamp!.isNotEmpty) ...[
                      SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                          SizedBox(width: 4),
                          Text(
                            _formatOrderTime(table.timeStamp),
                            style: GoogleFonts.poppins(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ]
                ],
              ),
            ),
            // Status label positioned over the top border
            Positioned(
              top: -12,
              left: 20,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  table.status,
                  style: GoogleFonts.poppins(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
