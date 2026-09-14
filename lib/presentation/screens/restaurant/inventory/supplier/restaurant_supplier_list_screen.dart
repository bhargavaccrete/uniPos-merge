import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/restaurant_supplier_model.dart';
import 'package:billberrylite/presentation/screens/restaurant/inventory/supplier/restaurant_supplier_detail_screen.dart';
import 'package:billberrylite/presentation/screens/restaurant/inventory/supplier/restaurant_supplier_form_sheet.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/gradient_hero_header.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Restaurant suppliers — who is owed what, and the way in to each account.
///
/// Balances shown here come straight from `RestaurantSupplierModel.currentBalance`,
/// which only ever moves through `RestaurantSupplierStore.recordBalanceMovement`.
class RestaurantSupplierListScreen extends StatefulWidget {
  const RestaurantSupplierListScreen({super.key});

  @override
  State<RestaurantSupplierListScreen> createState() =>
      _RestaurantSupplierListScreenState();
}

class _RestaurantSupplierListScreenState
    extends State<RestaurantSupplierListScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    restaurantSupplierStore.loadSuppliers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addSupplier() async {
    final created = await showRestaurantSupplierFormSheet(context);
    if (created != null && mounted) {
      _openSupplier(created);
    }
  }

  void _openSupplier(RestaurantSupplierModel supplier) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RestaurantSupplierDetailScreen(supplierId: supplier.supplierId),
      ),
    ).then((_) => restaurantSupplierStore.loadSuppliers());
  }

  @override
  Widget build(BuildContext context) {
    return MoneyScope(
      child: Scaffold(
        backgroundColor: AppColors.surfaceLight,
        appBar: buildPrimaryAppBar(title: 'Suppliers'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addSupplier,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            'Add Supplier',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        body: Observer(
          builder: (context) {
            final all = restaurantSupplierStore.suppliers.toList();
            final visible = restaurantSupplierStore.filteredSuppliers;
            final owed = restaurantSupplierStore.totalOutstanding;
            final withBalance = all.where((s) => s.currentBalance != 0).length;

            return Column(
              children: [
                GradientHeroHeader(
                  title: 'Suppliers',
                  subtitle:
                      'Contacts, balances and payments for raw-material suppliers',
                  icon: Icons.people_alt_rounded,
                  accent: AppColors.secondary,
                  stats: [
                    HeroStat(
                      icon: Icons.storefront_rounded,
                      value: '${all.length}',
                      label: all.length == 1 ? 'Supplier' : 'Suppliers',
                    ),
                    HeroStat(
                      icon: Icons.account_balance_wallet_rounded,
                      value: formatMoney(owed),
                      label: 'Outstanding',
                    ),
                    HeroStat(
                      icon: Icons.pending_actions_rounded,
                      value: '$withBalance',
                      label: 'With balance',
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppResponsive.getValue(
                      context,
                      mobile: 16.0,
                      tablet: 20.0,
                      desktop: 24.0,
                    ),
                    12,
                    AppResponsive.getValue(
                      context,
                      mobile: 16.0,
                      tablet: 20.0,
                      desktop: 24.0,
                    ),
                    8,
                  ),
                  child: AppTextField(
                    controller: _searchController,
                    hint: 'Search by name, phone or GST',
                    icon: Icons.search_rounded,
                    onChanged: restaurantSupplierStore.setSearchQuery,
                  ),
                ),
                // Hero stays full-bleed; only the supplier list narrows.
                Expanded(
                  child: AppResponsive.constrainedContent(
                    context: context,
                    maxWidth: AppResponsive.maxFormWidth(context),
                    alignment: Alignment.topCenter,
                    child: all.isEmpty
                        ? AppEmptyState(
                            icon: Icons.people_alt_rounded,
                            title: 'No suppliers yet',
                            message:
                                'Add the suppliers you buy raw materials from, then raise purchase orders against them.',
                            action: appEmptyStateAction(
                              label: 'Add Supplier',
                              onPressed: _addSupplier,
                            ),
                          )
                        : visible.isEmpty
                        ? const AppEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matches',
                            message:
                                'No supplier matches that search. Try a different name, phone or GST number.',
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              AppResponsive.getValue(
                                context,
                                mobile: 16.0,
                                tablet: 20.0,
                                desktop: 24.0,
                              ),
                              4,
                              AppResponsive.getValue(
                                context,
                                mobile: 16.0,
                                tablet: 20.0,
                                desktop: 24.0,
                              ),
                              96,
                            ),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _supplierCard(visible[i]),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _supplierCard(RestaurantSupplierModel supplier) {
    final balance = supplier.currentBalance;
    final isAdvance = balance < 0;
    final settled = balance == 0;

    final balanceColor = settled
        ? AppColors.textSecondary
        : (isAdvance ? AppColors.info : AppColors.danger);

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openSupplier(supplier),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  supplier.name.isEmpty
                      ? '?'
                      : supplier.name.characters.first.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if ((supplier.phone ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        supplier.phone!,
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.captionFontSize(context),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(balance.abs()),
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: balanceColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    settled ? 'Settled' : (isAdvance ? 'Advance' : 'Owed'),
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: balanceColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
