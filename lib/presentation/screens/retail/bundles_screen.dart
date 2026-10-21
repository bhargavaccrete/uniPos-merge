import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/retail/hive_model/bundle_model.dart';
import 'package:billberrylite/data/models/retail/hive_model/product_model_200.dart';
import 'package:billberrylite/data/models/retail/hive_model/variante_model_201.dart';
import 'package:billberrylite/domain/services/retail/inventory_service.dart';
import 'package:billberrylite/presentation/screens/retail/add_product_screen.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';

/// Card grid over every `bundle`/`repack` product — retail's equivalent of
/// restaurant's `RecipesScreen`. See docs/retail_inventory_system_plan.md §3.2
/// and §3 of docs/inventory_recipe_system_plan.md for the restaurant screen
/// this mirrors. Reachable from the Inventory screen's app bar.
class BundlesScreen extends StatefulWidget {
  const BundlesScreen({super.key});

  @override
  State<BundlesScreen> createState() => _BundlesScreenState();
}

class _BundlesScreenState extends State<BundlesScreen> {
  Future<void> _openProduct(ProductModel product) async {
    // Same navigation call the rest of the app uses to edit a product.
    await openEditProductScreen(context, product);
    // The edit screen may have changed stock mode, components, or stock —
    // refresh the cards on return.
    if (mounted) setState(() {});
  }

  double _costOf(String variantId) {
    for (final v in productStore.variants) {
      if (v.varianteId == variantId) return v.costPrice ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Bundles'),
      body: Observer(
        builder: (context) {
          final bundleProducts =
              productStore.products
                  .where((p) => p.needsBundleComponents)
                  .toList()
                ..sort((a, b) => a.productName.compareTo(b.productName));

          if (bundleProducts.isEmpty) {
            return AppEmptyState(
              icon: Icons.widgets_outlined,
              title: 'No bundles yet',
              message:
                  'Create a Bundle or Repack/Kit product from Add Product to see it here.',
            );
          }

          // One card per (product, variant) — a multi-variant bundle/repack
          // product (e.g. a "Combo Meal" in Small/Medium/Large) gets a card
          // per variant since each has its own component list. A product
          // with no variants yet still gets a single card so it isn't
          // dropped from the grid entirely.
          final cardEntries = <_BundleCardEntry>[
            for (final product in bundleProducts)
              if (productStore.variantsFor(product.productId).isEmpty)
                _BundleCardEntry(product: product, variant: null)
              else
                for (final variant in productStore.variantsFor(
                  product.productId,
                ))
                  _BundleCardEntry(product: product, variant: variant),
          ];

          return AppResponsive.constrainedContent(
            context: context,
            maxWidth: AppResponsive.maxContentWidth(context),
            child: GridView.builder(
              padding: AppResponsive.screenPadding(context),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: AppResponsive.gridColumns(context),
                crossAxisSpacing: AppResponsive.gridSpacing(context),
                mainAxisSpacing: AppResponsive.gridSpacing(context),
                childAspectRatio: AppResponsive.getValue(
                  context,
                  mobile: 0.80,
                  tablet: 0.78,
                  desktop: 0.76,
                ),
              ),
              itemCount: cardEntries.length,
              itemBuilder: (context, index) {
                final entry = cardEntries[index];
                final variant = entry.variant;
                final bundle = variant == null
                    ? null
                    : bundleRepository.getBundleForVariant(variant.varianteId);

                return _BundleCard(
                  product: entry.product,
                  variant: variant,
                  bundle: bundle,
                  costOf: _costOf,
                  onTap: () => _openProduct(entry.product),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// A (product, variant) pairing shown as one grid card — see the comment
/// above [_BundlesScreenState.build] for why a card is per-variant rather
/// than per-product.
class _BundleCardEntry {
  final ProductModel product;
  final VarianteModel? variant;

  const _BundleCardEntry({required this.product, required this.variant});
}

// Everything INSIDE a _BundleCard keeps static padding, gaps and icon sizes.
// The grid gives each cell a FIXED height via childAspectRatio, so growing the
// interior is what re-triggers BOTTOM OVERFLOWED. The fonts and the aspect
// ratio scale instead: the ratio drops on wider breakpoints (0.80/0.78/0.76)
// precisely to buy the height the larger fonts need, and the card's Spacer()
// absorbs whatever slack is left.

class _BundleCard extends StatelessWidget {
  final ProductModel product;
  final VarianteModel? variant;
  final RetailBundleModel? bundle;
  final double Function(String variantId) costOf;
  final VoidCallback onTap;

  const _BundleCard({
    required this.product,
    required this.variant,
    required this.bundle,
    required this.costOf,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRepack = product.isRepack;
    final componentCount = bundle?.components.length ?? 0;
    final estimatedCost = bundle?.estimatedCost(costOf) ?? 0.0;

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              AppResponsive.borderRadius(context),
            ),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StockModeBadge(isRepack: isRepack),
              const SizedBox(height: 10),
              Text(
                product.productName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              // Distinguishes the cards when a bundle/repack product has
              // multiple variants, each with its own component list.
              if (variant != null && variant!.hasAttributes) ...[
                const SizedBox(height: 2),
                Text(
                  variant!.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const Spacer(),
              _InfoRow(
                icon: Icons.inventory_2_outlined,
                label:
                    '$componentCount component${componentCount == 1 ? '' : 's'}',
              ),
              const SizedBox(height: 6),
              _InfoRow(
                icon: Icons.savings_outlined,
                label:
                    '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(estimatedCost)} cost',
              ),
              const SizedBox(height: 10),
              if (variant == null)
                Text(
                  'No variant configured',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (!isRepack)
                _AvailabilityPill(
                  available: RetailInventoryService.calculateAvailableToSell(
                    product,
                    variant!,
                  ),
                  minStock: variant!.minStock,
                )
              else
                _InfoRow(
                  icon: Icons.stacked_line_chart_rounded,
                  label: 'Stock: ${variant!.stockQty}',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockModeBadge extends StatelessWidget {
  final bool isRepack;

  const _StockModeBadge({required this.isRepack});

  @override
  Widget build(BuildContext context) {
    final color = isRepack ? AppColors.info : AppColors.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRepack ? Icons.build_circle_outlined : Icons.widgets_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isRepack ? 'Repack / Kit' : 'Bundle',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.captionFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Available to Sell" chip, color-coded green/orange/red — the bundle
/// equivalent of restaurant's "N can be made" chip.
class _AvailabilityPill extends StatelessWidget {
  final double available;
  final double? minStock;

  const _AvailabilityPill({required this.available, this.minStock});

  @override
  Widget build(BuildContext context) {
    final threshold = minStock ?? 5;
    final Color color;
    if (available <= 0) {
      color = AppColors.danger;
    } else if (available <= threshold) {
      color = AppColors.warning;
    } else {
      color = AppColors.success;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(
          AppResponsive.smallBorderRadius(context),
        ),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        available <= 0 ? 'Out of stock' : '$available can be sold',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.smallFontSize(context),
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
