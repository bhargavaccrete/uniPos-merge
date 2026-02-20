
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import 'package:unipos/util/color.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../data/models/restaurant/db/table_Model_311.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../start order/cart/cart.dart';
import '../start order/startorder.dart';
import '../../../../util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';

class TableScreen extends StatefulWidget {
  final bool? isfromcart;
  const TableScreen({super.key, this.isfromcart = false});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  @override
  void initState() {
    super.initState();
    tableStore.loadTables();
  }

  // ── Add ────────────────────────────────────────────────────────────────────

  void _addTable() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add New Table',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 300,
          child: TextField(
            controller: controller,
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
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await tableStore.addTable(TableModel(id: name));
              Navigator.pop(ctx);
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

  // ── Long-press action sheet ─────────────────────────────────────────────────

  void _showTableActions(TableModel table) {
    final isOccupied = table.status != 'Available' && table.status != 'Reserved';

    // Resolve status color for the chip in the header
    Color statusColor;
    if (isOccupied) {
      statusColor = AppColors.danger;
    } else if (table.status == 'Reserved') {
      statusColor = AppColors.warning;
    } else {
      statusColor = AppColors.success;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Table ${table.id}',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      table.status,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1),

            // Reserve / Unreserve (only for non-occupied tables)
            if (!isOccupied)
              ListTile(
                leading: Icon(
                  table.status == 'Reserved'
                      ? Icons.event_available_outlined
                      : Icons.event_seat_outlined,
                  color: AppColors.warning,
                ),
                title: Text(
                  table.status == 'Reserved' ? 'Mark as Available' : 'Reserve Table',
                  style: GoogleFonts.poppins(),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final newStatus = table.status == 'Reserved' ? 'Available' : 'Reserved';
                  await tableStore.updateTableStatus(table.id, newStatus);
                  NotificationService.instance.showSuccess(
                    'Table ${table.id} is now $newStatus',
                  );
                },
              ),

            // Rename
            ListTile(
              leading: Icon(Icons.edit_outlined, color: AppColors.primary),
              title: Text('Rename Table', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(ctx);
                _renameTable(table);
              },
            ),

            // Delete
            ListTile(
              enabled: !isOccupied,
              leading: Icon(
                Icons.delete_outline,
                color: isOccupied ? Colors.grey.shade400 : AppColors.danger,
              ),
              title: Text(
                'Delete Table',
                style: GoogleFonts.poppins(
                  color: isOccupied ? Colors.grey.shade400 : AppColors.danger,
                ),
              ),
              subtitle: isOccupied
                  ? Text(
                      'Cannot delete an occupied table',
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade400),
                    )
                  : null,
              onTap: isOccupied
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _deleteTable(table);
                    },
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Rename ─────────────────────────────────────────────────────────────────

  void _renameTable(TableModel table) {
    final controller = TextEditingController(text: table.id);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rename Table', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 300,
          child: TextField(
            controller: controller,
            autofocus: true,
            style: GoogleFonts.poppins(),
            decoration: InputDecoration(
              hintText: 'Enter new table name',
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
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == table.id) {
                Navigator.pop(ctx);
                return;
              }
              final exists = await tableStore.tableExists(newName);
              if (exists) {
                if (ctx.mounted) {
                  NotificationService.instance.showError('Table "$newName" already exists.');
                }
                return;
              }
              // Rename = delete old + add new with same status/capacity
              await tableStore.deleteTable(table.id);
              await tableStore.addTable(
                TableModel(
                  id: newName,
                  status: table.status,
                  tableCapacity: table.tableCapacity,
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              NotificationService.instance.showSuccess('Table renamed to "$newName"');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Rename',
              style: GoogleFonts.poppins(color: AppColors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  void _deleteTable(TableModel table) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Table',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: AppColors.danger),
        ),
        content: Text(
          'Delete "${table.id}"? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await tableStore.deleteTable(table.id);
              if (ctx.mounted) Navigator.pop(ctx);
              NotificationService.instance.showSuccess('Table "${table.id}" deleted.');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: AppColors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: Column(
        children: [
          // Header: Add Table + Legend
          Container(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            color: AppColors.white,
            child: Column(
              children: [
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
            child: Observer(
              builder: (_) {
                if (tableStore.isLoading && tableStore.tables.isEmpty) {
                  return Center(child: CircularProgressIndicator());
                }

                if (tableStore.tables.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_restaurant_outlined, size: 80, color: AppColors.divider),
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

                final allTables = tableStore.tables;
                final crossAxisCount = isTablet ? 4 : 2;

                return GridView.builder(
                  padding: EdgeInsets.all(20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: allTables.length,
                  itemBuilder: (context, index) {
                    final table = allTables[index];

                    // Show customer name from the linked active order (if any)
                    final activeOrder = orderStore.getActiveOrderByTableId(table.id);
                    final customerName = activeOrder?.customerName?.isNotEmpty == true
                        ? activeOrder!.customerName!
                        : null;

                    return TableCard(
                      table: table,
                      customerName: customerName,
                      onLongPress: () => _showTableActions(table),
                      onTap: () {
                        final isOccupied = table.status == 'Processing' ||
                            table.status == 'Cooking' ||
                            table.status == 'Running' ||
                            table.status == 'Ready' ||
                            table.status == 'Served';

                        if (isOccupied) {
                          // Open active order in cart
                          if (activeOrder != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CartScreen(
                                  existingOrder: activeOrder,
                                  selectedTableNo: table.id,
                                ),
                              ),
                            );
                          } else {
                            // Orphaned table — status is occupied but no order exists
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                title: Text(
                                  'No Active Order Found',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700),
                                ),
                                content: Text(
                                  'Table "${table.id}" shows as ${table.status} but has no linked order.\n\nWhat would you like to do?',
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text('Cancel',
                                        style: GoogleFonts.poppins(
                                            color: AppColors.textSecondary)),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      await tableStore.deleteTable(table.id);
                                      NotificationService.instance.showSuccess(
                                          'Table "${table.id}" deleted.');
                                    },
                                    child: Text('Delete Table',
                                        style: GoogleFonts.poppins(
                                            color: Colors.red)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      await tableStore.updateTableStatus(
                                          table.id, 'Available');
                                      NotificationService.instance.showSuccess(
                                          'Table "${table.id}" reset to Available.');
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    child: Text('Reset to Available',
                                        style: GoogleFonts.poppins(
                                            color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                          }
                        } else {
                          // Available or Reserved — start a new order
                          if (widget.isfromcart == true) {
                            Navigator.pop(context, table.id);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    Startorder(newOrderForTableId: table.id),
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

// ═══════════════════════════════════════════════════════════════════════════
// TABLE CARD
// ═══════════════════════════════════════════════════════════════════════════

class TableCard extends StatelessWidget {
  final TableModel table;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? customerName;

  const TableCard({
    super.key,
    required this.table,
    required this.onTap,
    this.onLongPress,
    this.customerName,
  });

  String _formatOrderTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      return DateFormat('hh:mm a').format(dateTime);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    switch (table.status) {
      case 'Processing':
      case 'Cooking':
      case 'Running':
      case 'Ready':
      case 'Served':
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
      onLongPress: onLongPress,
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
            // Main card content
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
                          customerName ?? 'Guest',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                  ],
                ],
              ),
            ),

            // Status label badge over the top border
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