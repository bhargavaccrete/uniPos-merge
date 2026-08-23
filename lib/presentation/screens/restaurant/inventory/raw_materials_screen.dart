import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/itemmodel_302.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import '../manage menu/tab/edit_item.dart';

/// Read-only list of every Raw Material item — mirrors the visual style of
/// `manage_Inventory.dart`'s item tiles (name, unit, stock, low-stock colour
/// coding) without the stock-adjustment controls, since raw-material stock
/// is meant to move through the PO/GRN pipeline (a later phase), not manual
/// adjustment here. See docs/inventory_recipe_system_plan.md §8.3.
///
/// Not wired to a route yet — a later step adds the navigation entry point.
class RawMaterialsScreen extends StatefulWidget {
  const RawMaterialsScreen({super.key});

  @override
  State<RawMaterialsScreen> createState() => _RawMaterialsScreenState();
}

class _RawMaterialsScreenState extends State<RawMaterialsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (itemStore.items.isEmpty) {
      itemStore.loadItems();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Raw Materials'),
      body: Column(
        children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search raw materials…',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                filled: true,
                fillColor: AppColors.surfaceLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Observer(
              builder: (_) {
                final items =
                    itemStore.items
                        .where(
                          (i) =>
                              i.isRawMaterial &&
                              (_query.isEmpty ||
                                  i.name.toLowerCase().contains(_query)),
                        )
                        .toList()
                      ..sort((a, b) => a.name.compareTo(b.name));

                if (items.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.grain_rounded,
                    title: 'No raw materials yet',
                    message: 'Mark an item Raw Material to track it here.',
                  );
                }

                return ListView.builder(
                  padding: AppResponsive.padding(context),
                  itemCount: items.length,
                  itemBuilder: (context, index) =>
                      _RawMaterialTile(item: items[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RawMaterialTile extends StatelessWidget {
  final Items item;

  const _RawMaterialTile({required this.item});

  String _formatStock(double stock, String unit, bool isWeightBased) {
    if (!isWeightBased) return stock.toStringAsFixed(0);
    return stock == stock.roundToDouble()
        ? stock.toStringAsFixed(0)
        : stock.toStringAsFixed(2);
  }

  Widget _buildStockBadge(BuildContext context) {
    final MaterialColor base;
    final String label;
    if (!item.trackInventory) {
      base = Colors.blueGrey;
      label = 'Not Tracked';
    } else if (!item.isInStock) {
      base = Colors.red;
      label = 'Out of Stock';
    } else if (item.isLowStock) {
      base = Colors.orange;
      label = 'Low Stock';
    } else {
      base = Colors.green;
      label = 'In Stock';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: base.shade600,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: base.shade700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeightBased = item.isSoldByWeight;
    final unit = item.unit ?? (isWeightBased ? 'kg' : 'pcs');

    return InkWell(
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EdititemScreen(items: item)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(
            AppResponsive.borderRadius(context),
          ),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.grain_rounded,
                color: AppColors.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Stock: ${_formatStock(item.stockQuantity, unit, isWeightBased)} $unit',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (item.lastPurchaseCost != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          'Last cost: ${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.lastPurchaseCost!)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildStockBadge(context),
          ],
        ),
      ),
    );
  }
}
