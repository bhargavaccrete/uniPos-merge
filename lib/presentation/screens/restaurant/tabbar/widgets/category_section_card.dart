part of '../menu.dart';

class _CategorySectionCard extends StatelessWidget {
  final dynamic category;
  final List<Items> searchFilteredItems;
  final bool initiallyExpanded;
  final ExpansibleController? controller;
  final GlobalKey cardKey;
  final void Function(Items) onItemTap;
  final void Function(Items) onToggleFavorite;
  final String Function(Items) formatStock;
  final StockStatus Function(Items) getStockStatus;

  /// When true, render this section's items as a GRID (the opt-in "Menu Grid
  /// View" mode) instead of the default vertical list of tiles. [buildGridCard]
  /// supplies each grid cell — it's `_MenuScreenState._buildGridItemCard`, the
  /// same card the tablet layout uses, so both modes share one card.
  final bool gridView;
  final Widget Function(Items item)? buildGridCard;

  const _CategorySectionCard({
    required this.category,
    required this.searchFilteredItems,
    required this.initiallyExpanded,
    required this.controller,
    required this.cardKey,
    required this.onItemTap,
    required this.onToggleFavorite,
    required this.formatStock,
    required this.getStockStatus,
    this.gridView = false,
    this.buildGridCard,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      key: cardKey,
      margin: EdgeInsets.only(bottom: AppResponsive.mediumSpacing(context)),
      elevation: 2,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          controller: controller,
          initiallyExpanded: initiallyExpanded,
          leading: Container(
            padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.restaurant_menu,
              color: AppColors.primary,
              size: AppResponsive.getValue(
                context,
                mobile: 24.0,
                tablet: 26.0,
                desktop: 28.0,
              ),
            ),
          ),
          title: Text(
            category.name,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            '${searchFilteredItems.length} items',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          children: [
            if (gridView)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppResponsive.mediumSpacing(context),
                  0,
                  AppResponsive.mediumSpacing(context),
                  AppResponsive.mediumSpacing(context),
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: AppResponsive.gridColumns(
                    context,
                    mobile: 2,
                    tablet: 3,
                    desktop: 4,
                  ),
                  crossAxisSpacing: AppResponsive.gridSpacing(context),
                  mainAxisSpacing: AppResponsive.gridSpacing(context),
                  // Absolute height on desktop — see kMenuItemCardHeightDesktop
                  // in menu.dart (this file is `part of` it).
                  mainAxisExtent: AppResponsive.isDesktop(context)
                      ? kMenuItemCardHeightDesktop
                      : null,
                  childAspectRatio: AppResponsive.getValue(
                    context,
                    mobile: 0.75,
                    tablet: 0.70,
                    // Ignored on desktop — mainAxisExtent pins the height there instead.
                    desktop: 0.75,
                  ),
                ),
                itemCount: searchFilteredItems.length,
                itemBuilder: (_, i) => buildGridCard!(searchFilteredItems[i]),
              )
            else
              // A Column, not a shrink-wrapped ListView. The section is
              // already non-scrollable and builds every tile anyway, so the
              // list bought nothing — but it wrapped each tile in
              // AutomaticKeepAlive / KeepAlive / _SelectionKeepAlive /
              // NotificationListener / KeyedSubtree and ran the children
              // through a sliver viewport. That measured ~10 extra widgets per
              // tile and ~18% of the frame on a large menu with every category
              // expanded. Same children, same order, same padding, and the
              // same spacing between tiles.
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppResponsive.mediumSpacing(context),
                  0,
                  AppResponsive.mediumSpacing(context),
                  AppResponsive.mediumSpacing(context),
                ),
                child: Column(
                  children: [
                    for (var itemIndex = 0;
                        itemIndex < searchFilteredItems.length;
                        itemIndex++) ...[
                      // Between tiles only — exactly where separatorBuilder
                      // put it.
                      if (itemIndex > 0)
                        SizedBox(height: AppResponsive.smallSpacing(context)),
                      // Kept from the ListView this replaced: it wrapped every
                      // child in a RepaintBoundary, and dropping that made the
                      // section repaint as one layer (measurably worse paint).
                      RepaintBoundary(
                        child: _ItemListTile(
                          key: ValueKey(
                            '${searchFilteredItems[itemIndex].id}_'
                            '${searchFilteredItems[itemIndex].isFavorite}',
                          ),
                          item: searchFilteredItems[itemIndex],
                          onTap: () => onItemTap(searchFilteredItems[itemIndex]),
                          onToggleFavorite: () =>
                              onToggleFavorite(searchFilteredItems[itemIndex]),
                          formatStock: formatStock,
                          getStockStatus: getStockStatus,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
