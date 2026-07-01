part of '../menu.dart';

class _CategorySectionCard extends StatelessWidget {
  final dynamic category;
  final List<Items> searchFilteredItems;
  final bool initiallyExpanded;
  final ExpansibleController? controller;
  final GlobalKey cardKey;
  final List<CartItem> cartItems;
  final void Function(Items) onItemTap;
  final void Function(Items) onToggleFavorite;
  final String Function(Items) formatStock;
  final StockStatus Function(Items) getStockStatus;

  const _CategorySectionCard({
    required this.category,
    required this.searchFilteredItems,
    required this.initiallyExpanded,
    required this.controller,
    required this.cardKey,
    required this.cartItems,
    required this.onItemTap,
    required this.onToggleFavorite,
    required this.formatStock,
    required this.getStockStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      key: cardKey,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          controller: controller,
          initiallyExpanded: initiallyExpanded,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.restaurant_menu,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          title: Text(
            category.name,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            '${searchFilteredItems.length} items',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: searchFilteredItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, itemIndex) {
                final item = searchFilteredItems[itemIndex];
                return _ItemListTile(
                  key: ValueKey('${item.id}_${item.isFavorite}'),
                  item: item,
                  onTap: () => onItemTap(item),
                  onToggleFavorite: () => onToggleFavorite(item),
                  formatStock: formatStock,
                  getStockStatus: getStockStatus,
                  cartEntries: cartItems
                      .where((c) => c.productId == item.id)
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
