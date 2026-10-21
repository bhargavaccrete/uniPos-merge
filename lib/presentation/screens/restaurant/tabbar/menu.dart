import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:billberrylite/presentation/screens/restaurant/start%20order/cart/cart.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/core/constants/image_sizes.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../domain/services/restaurant/day_management_service.dart';
import '../../../widget/restaurant/opening_balance_dialog.dart';
import '../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../data/models/common/categorymodel_300.dart';
import '../../../../data/models/restaurant/db/ordermodel_309.dart';
import '../../../../domain/services/common/list_sort_service.dart';
import '../../../widget/componets/common/list_sort_button.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../../domain/store/restaurant/cart_store.dart'
    show ProductCartState;
import '../../../../domain/services/restaurant/inventory_service.dart';
import '../../../../util/restaurant/staticswitch.dart';
import '../../../widget/componets/restaurant/componets/Button.dart';
import '../../../widget/componets/common/app_text_field.dart';
import '../../../widget/componets/common/app_empty_state.dart';
import 'weight_item_dialog_restaurant.dart';
import 'item_options_dialog.dart';
import '../../../../util/common/app_responsive.dart';
import '../../../../util/common/currency_helper.dart';
import 'package:billberrylite/util/common/decimal_settings.dart';

part 'widgets/category_section_card.dart';

/// Absolute height of an item card on DESKTOP.
///
/// Desktop must NOT size these cells with `childAspectRatio`. The card's
/// content floor is constant — image, an up-to-two-line name, and the price
/// row — but a ratio derives height from column width, and desktop's 4 columns
/// make the widest screens give tall cells and the narrowest give short ones.
/// The same ratio therefore overflowed by 19px at 1024 while leaving visible
/// slack at 1440.
///
/// `mainAxisExtent` pins the height instead: the card is identical at every
/// desktop width and only the columns get wider. Raise this if a long name
/// ever clips; lower it to tighten the cards.
///
/// `menu_grid_screen.dart` keeps its own copy — it is deliberately
/// self-contained and does not import this file. Keep the two in step.
const double kMenuItemCardHeightDesktop = 240.0;

/// Desktop column count derived from the MEASURED grid pane, not the screen.
///
/// The grid is an `Expanded` beside a fixed sidebar, so screen breakpoints
/// over-count it: a flat 4 columns produced a 181px card at 1024 and a 285px
/// card at 1440 — the same card, 57% apart, inside one breakpoint.
///
/// Targeting a card width instead lets the count fall out of the arithmetic,
/// which holds the card near 215-260px from 1024 all the way to 1920.
///
/// Desktop only. Tablet keeps `AppResponsive.gridColumns`: its pane is just
/// ~380px wide at 600, where this formula would drop to a single column.
int menuGridColumnsForPane(double paneWidth) {
  const targetCardWidth = 220.0;
  const spacing = 16.0;
  const gridPadding = 32.0; // GridView padding, both sides
  final cols =
      ((paneWidth - gridPadding + spacing) / (targetCardWidth + spacing))
          .round();
  return cols.clamp(2, 6);
}

/// Screen width at which the menu grows a third pane holding the cart.
///
/// Deliberately NOT the 1024 desktop breakpoint. A cart pane at 1024 leaves the
/// grid ~384px — two columns of ~166px, narrower than anything this screen has
/// ever shown. At 1280 the grid still gets 3 columns at ~192px, so 1280 is the
/// width where the pane starts paying for the space it takes.
const double kMenuCartPaneBreakpoint = 1280.0;

/// Width of the inline cart pane.
///
/// Fixed, not flexible: the pane holds a name, a stepper, a price and a delete
/// button, and those have a real minimum. Letting it flex would squeeze the
/// name column on the narrowest screen that shows the pane at all.
const double kMenuCartPaneWidth = 380.0;

/// Whether the menu shows its cart inline rather than behind the bottom bar.
///
/// When true the bottom cart bar is suppressed and the grid drops its 80px
/// bottom reserve — the two must never both render, or the total shows twice.
bool menuShowsCartPane(BuildContext context) =>
    AppResponsive.screenWidth(context) >= kMenuCartPaneBreakpoint;

enum StockStatus { inStock, orderAvailable, outOfStock, notTracked }

class MenuScreen extends StatefulWidget {
  final String? tableIdForNewOrder;
  final OrderModel? existingOrder;
  final bool isForAddingItem;

  /// Bumped by the host tab bar each time the user comes BACK to the menu tab.
  /// The screen is kept alive now, so this is what re-applies the things the
  /// old rebuild-on-return used to do (see `didUpdateWidget`).
  final int tabRevisitTick;

  const MenuScreen({
    super.key,
    this.existingOrder,
    this.isForAddingItem = false,
    this.tableIdForNewOrder,
    this.tabRevisitTick = 0,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with AutomaticKeepAliveClientMixin {
  // The Menu lives in a TabBarView, which disposes a tab when you leave it.
  // Without this, coming back from Orders or Tables re-created the whole
  // screen: reload, re-stage every section, "Preparing menu…" again. Keeping
  // it alive means the tab is exactly as you left it — including scroll
  // position and which categories are open.
  @override
  bool get wantKeepAlive => true;

  // Sentinel category id for the "Favorites" tab.
  static const String _kFavorites = '__favorites__';
  int _scrollRequestId = 0;

  void _toggleFavorite(Items item) {
    itemStore.updateItem(item.copyWith(isFavorite: !item.isFavorite));
  }

  /// Tappable star overlay used on item cards to mark/unmark favorite.
  Widget _favStar(Items item) {
    return GestureDetector(
      onTap: () => _toggleFavorite(item),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          shape: BoxShape.circle,
        ),
        child: Icon(
          item.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
          size: 18,
          color: item.isFavorite ? Colors.amber : AppColors.textSecondary,
        ),
      ),
    );
  }

  /// Mobile "Favorites" section pinned at the top of the category list.
  // ── Sort (shared by every layout on this screen) ──────────────────────────
  //
  // One preference, `SortableList.posMenu`, drives both the category order and
  // the item order inside each section, so the quick-nav strip and the
  // sections below it can never disagree.

  ListSortOption get _sort =>
      ListSortService.instance.optionFor(SortableList.posMenu);

  List<Category> _sortCategories(List<Category> categories) => applySort(
    categories,
    _sort,
    nameOf: (c) => c.name,
    createdAtOf: (c) => c.createdTime,
  );

  /// Sort the menu's item list ONCE, right where it is filtered down to what
  /// is sellable. Every other list on this screen — per-category sections,
  /// favourites, the uncategorised bucket — is derived from it with `.where`,
  /// which preserves order, so they all inherit the sort from this one call.
  List<Items> _sortItems(List<Items> items) => applySort(
    items,
    _sort,
    nameOf: (i) => i.name,
    createdAtOf: (i) => i.createdTime,
  );

  /// Items belonging to no surviving category.
  ///
  /// Deleting a category re-parents its items rather than destroying them, so
  /// without this section such an item would still exist, still be enabled, and
  /// still be counted on the menu — while being completely unreachable from the
  /// order screen. It renders only when there is something to show, so a shop
  /// that keeps every item categorised never sees it.
  Widget _buildUncategorisedSection(
    List<Items> visibleItems,
    List<dynamic> renderedCategories,
    String query,
    String lowerQuery,
  ) {
    // A sentinel, not '' — the key maps are shared with real categories and an
    // empty id is a plausible value for legacy data.
    const uncategorisedId = '__uncategorised__';

    final known = renderedCategories.map((c) => c.id as String).toSet();
    var orphans = visibleItems
        .where((item) => !known.contains(item.categoryOfItem ?? ''))
        .toList();

    if (query.isNotEmpty) {
      orphans = orphans
          .where(
            (i) =>
                i.name.toLowerCase().contains(lowerQuery) ||
                (i.itemCode != null &&
                    i.itemCode!.toLowerCase().contains(lowerQuery)),
          )
          .toList();
    }
    if (orphans.isEmpty) return const SizedBox.shrink();

    _categoryKeys.putIfAbsent(uncategorisedId, () => GlobalKey());
    _expansionControllers.putIfAbsent(
      uncategorisedId,
      () => ExpansibleController(),
    );

    return _CategorySectionCard(
      category: Category(id: uncategorisedId, name: 'Uncategorized'),
      searchFilteredItems: orphans,
      initiallyExpanded:
          (query.isNotEmpty || AppSettings.keepCategoriesOpen) &&
          _opensImmediately(uncategorisedId, orphans.length),
      controller: _expansionControllers[uncategorisedId],
      cardKey: _categoryKeys[uncategorisedId]!,
      onItemTap: _handleItemTap,
      onToggleFavorite: _toggleFavorite,
      formatStock: _formatStockDisplay,
      getStockStatus: _getStockStatus,
      gridView: AppSettings.menuGridView,
      buildGridCard: _buildGridItemCard,
    );
  }

  Widget _buildFavoritesSection(
    List<Items> visibleItems,
    String query,
    String lowerQuery,
  ) {
    var favItems = visibleItems.where((i) => i.isFavorite).toList();
    if (query.isNotEmpty) {
      favItems = favItems
          .where(
            (i) =>
                i.name.toLowerCase().contains(lowerQuery) ||
                (i.itemCode != null &&
                    i.itemCode!.toLowerCase().contains(lowerQuery)),
          )
          .toList();
    }
    // No favorites yet (or none match the search) — hide the section entirely,
    // just like the Favorites strip chip. It appears only once an item is starred.
    if (favItems.isEmpty) return const SizedBox.shrink();
    // Register key + controller under the favorites sentinel so the quick-nav
    // strip can expand/scroll to it via the same _selectStripCategory path as a
    // real category section.
    _categoryKeys.putIfAbsent(_kFavorites, () => GlobalKey());
    _expansionControllers.putIfAbsent(
      _kFavorites,
      () => ExpansibleController(),
    );

    return Card(
      key: _categoryKeys[_kFavorites],
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          controller: _expansionControllers[_kFavorites],
          // Collapsed by default — opens on tap, during search, or when the
          // "Keep Categories Open" setting is on. Staged like every other
          // section, so a long favourites list cannot block the first frame.
          initiallyExpanded:
              (query.isNotEmpty || AppSettings.keepCategoriesOpen) &&
              _opensImmediately(_kFavorites, favItems.length),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Colors.amber,
              size: 24,
            ),
          ),
          title: Text(
            'Favorites',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            '${favItems.length} items',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          children: [
            if (AppSettings.menuGridView)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: AppResponsive.gridColumns(
                    context,
                    mobile: 2,
                    tablet: 3,
                    desktop: 4,
                  ),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  // Absolute height on desktop — see kMenuItemCardHeightDesktop.
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
                itemCount: favItems.length,
                itemBuilder: (_, i) => _buildGridItemCard(favItems[i]),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: favItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final item = favItems[i];
                  return _ItemListTile(
                    key: ValueKey('${item.id}_${item.isFavorite}'),
                    item: item,
                    onTap: () => _handleItemTap(item),
                    onToggleFavorite: () => _toggleFavorite(item),
                    formatStock: _formatStockDisplay,
                    getStockStatus: _getStockStatus,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String? activeCategory;
  String query = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final Map<String, GlobalKey> _categoryKeys = {};
  final Map<String, ExpansibleController> _expansionControllers = {};
  final ScrollController _listScrollController = ScrollController();
  bool _isLoadingData = false;

  // Last-seen value of the "Keep Categories Open" setting, so the listener can
  // tell an actual toggle apart from any other settings change.
  bool _lastKeepOpen = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _lastKeepOpen = AppSettings.keepCategoriesOpen;
    AppSettings.settingsNotifier.addListener(_onSettingsChanged);

    _searchController.addListener(() {
      setState(() {
        query = _searchController.text;
      });
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STAGED SECTION EXPANSION
  //
  // "Keep Categories Open" (and an active search) means EVERY section is open,
  // and an open section builds and lays out all of its tiles. Doing that for
  // the whole menu in one frame is what froze the screen for seconds on a
  // large menu — the first usable frame had to pay for every item at once.
  //
  // The sections still all open and the list stays eager; they just open a
  // couple per frame instead of all at once. The shell (search field, category
  // strip, section headers) is up on the first frame and stays responsive
  // while the rest fills in behind it.
  // ═══════════════════════════════════════════════════════════════════════

  // Budgets are in ITEMS, not sections: what a frame costs is the number of
  // tiles it builds, and sections vary from 3 items to 60. Counting sections
  // made a 200-item menu take one frame per category for no reason, while a
  // single huge category could still overshoot.

  /// Items worth of sections rendered already-open in the first frame —
  /// roughly what fits on screen.
  static const int _kItemsOpenOnFirstFrame = 40;

  /// Items opened per frame after that. At least one section always opens, so
  /// a category larger than this cannot stall the queue.
  static const int _kItemsOpenedPerFrame = 60;

  /// Below this many items the whole menu just opens at once: staging costs a
  /// frame per batch plus an expansion animation per section, and on a small
  /// menu that machinery takes LONGER than simply building everything. Measured
  /// at 200 items — staged and unstaged both landed around a second, all of it
  /// staging overhead rather than tile building.
  static const int _kStageAboveItemCount = 300;

  /// Whether the current fill is staged. False on a small menu, which then
  /// shows no loader and does not freeze the list.
  bool _stagedFill = false;

  /// Item count per section id, filled in as sections build. Only used to size
  /// the batches.
  final Map<String, int> _sectionItemCounts = {};

  /// Section ids still waiting to be opened, in render order.
  final List<String> _expansionQueue = [];

  /// Bumped whenever the expansion INTENT changes (search typed or cleared,
  /// Keep Categories Open toggled, section list changed). A drain callback
  /// carrying an older token is stale and exits — this is what cancels
  /// in-flight staging instead of letting two runs fight each other.
  int _expansionToken = 0;
  bool _drainScheduled = false;

  /// True while sections are still being opened. Driven by the drain, and
  /// listened to ONLY by the overlay and the scroll physics — a `setState`
  /// here would rebuild every tile on screen, which is the cost this whole
  /// mechanism exists to avoid.
  final ValueNotifier<bool> _stagingSections = ValueNotifier<bool>(false);

  /// True while a scroll gesture is in flight. Opening a section during a
  /// scroll is what makes the list feel like it catches — the work lands on
  /// the same frames that should be moving the viewport. The queue simply
  /// waits; [ScrollEndNotification] restarts it.
  bool _scrollInProgress = false;

  /// The current expansion intent, so the section build can tell a real change
  /// from an ordinary rebuild (a cart change must not restart staging).
  String _expansionSignature = '';

  /// Items accounted for so far in this section build, in render order, so the
  /// first screenful renders already-open and the rest is staged.
  int _itemsBudgetUsed = 0;

  bool _opensImmediately(String sectionId, int itemCount) {
    _sectionItemCounts[sectionId] = itemCount;
    if (!_stagedFill) return true;
    if (_itemsBudgetUsed >= _kItemsOpenOnFirstFrame) return false;
    _itemsBudgetUsed += itemCount;
    return true;
  }

  /// Called from the section build with the section ids in RENDER order.
  ///
  /// The ids are passed in rather than read from `_expansionControllers`: on a
  /// fresh open those controllers are created further down in this same build,
  /// so reading them here queued nothing and every section past the first two
  /// stayed shut. A queued id whose controller does not exist yet is fine —
  /// the drain runs post-frame, by which time the section has been built.
  void _syncSectionExpansion(
    bool expanding,
    List<String> sectionIds, {
    required bool staged,
  }) {
    // Keyed on WHETHER a search is active and WHICH sections are rendered —
    // deliberately not on the query text. With the raw query in here, every
    // keystroke counted as a new intent: staging restarted, every section was
    // re-queued for an `expand()` that was already a no-op, and the
    // "Preparing menu…" pill plus the frozen list flashed back on each
    // character. Hashing the id LIST rather than its length matters: as
    // matches change, one section can drop out while another appears, leaving
    // the count identical — and a section that appeared would never be queued.
    final signature =
        '$expanding|$staged|${query.isEmpty}|'
        '${Object.hashAll(sectionIds)}';
    if (signature == _expansionSignature) return;
    _expansionSignature = signature;

    // Cancel whatever was still being staged for the previous intent.
    _expansionToken++;
    _expansionQueue.clear();

    if (!expanding) {
      _stagingSections.value = false;
      // Collapsing is cheap — an ExpansionTile drops its children — so it can
      // happen in one go.
      final token = _expansionToken;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || token != _expansionToken) return;
        for (final controller in _expansionControllers.values) {
          try {
            controller.collapse();
          } catch (_) {
            // Not attached yet — `initiallyExpanded` covers it.
          }
        }
      });
      return;
    }

    // Render order. The first few are already open via `initiallyExpanded`,
    // and expanding an open tile is a no-op.
    _stagedFill = staged;
    _expansionQueue.addAll(sectionIds);
    _scheduleExpansionDrain();
  }

  void _scheduleExpansionDrain() {
    if (_drainScheduled || _expansionQueue.isEmpty) return;
    _drainScheduled = true;
    // The loader and the frozen list are only for a staged fill; a small menu
    // opens in one go and never shows them.
    _stagingSections.value = _stagedFill;
    final token = _expansionToken;
    // A post-frame callback only runs if a frame actually happens, and a batch
    // can be all no-ops (the first sections are already open), which schedules
    // no animation and therefore no frame. Ask for one so the chain cannot
    // stall with sections still queued. Idempotent — not a timer, and not a
    // rebuild.
    WidgetsBinding.instance.ensureVisualUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _drainScheduled = false;
      if (!mounted || token != _expansionToken) return;
      // Scrolling — leave the queue alone; ScrollEndNotification resumes it.
      if (_scrollInProgress) return;
      var itemsOpened = 0;
      while (_expansionQueue.isNotEmpty &&
          (!_stagedFill ||
              itemsOpened == 0 ||
              itemsOpened < _kItemsOpenedPerFrame)) {
        final id = _expansionQueue.removeAt(0);
        try {
          _expansionControllers[id]?.expand();
        } catch (_) {
          // Tile not attached yet — it adopts the state when first built.
        }
        itemsOpened += _sectionItemCounts[id] ?? 1;
      }
      if (_expansionQueue.isNotEmpty) {
        _scheduleExpansionDrain();
      } else {
        _stagingSections.value = false;
      }
    });
  }

  /// Keep Categories Open toggled: rebuild so the section build re-evaluates
  /// the intent and stages the work. The expansion is NOT done here any more —
  /// opening every section at once is what froze the menu.
  void _onSettingsChanged() {
    final keepOpen = AppSettings.keepCategoriesOpen;
    if (keepOpen == _lastKeepOpen) return;
    _lastKeepOpen = keepOpen;
    // An active search already forces everything open — don't fight it.
    if (query.isNotEmpty) return;
    if (mounted) setState(() {});
  }

  Future<void> _loadData({bool force = false}) async {
    if (_isLoadingData && !force) return;
    if (!mounted) return;

    setState(() {
      _isLoadingData = true;
    });

    try {
      await Future.wait([
        categoryStore.ensureLoaded(),
        itemStore.ensureLoaded(),
        restaurantCartStore.loadCartItems(),
      ]).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Data loading timed out after 10 seconds');
        },
      );
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error loading menu: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  /// The screen used to be rebuilt from scratch on every tab return, which
  /// re-read the cart, cleared the search and put the list back at the top.
  /// It is kept alive now (rebuilding it cost a full menu re-stage), so those
  /// three effects are reproduced here instead — none of them rebuild the
  /// section list.
  ///
  /// Driven by [MenuScreen.tabRevisitTick] rather than by visibility: a route
  /// pushed on top of the menu (the cart) also hides it, and coming back from
  /// THAT never reset anything.
  @override
  void didUpdateWidget(covariant MenuScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabRevisitTick != oldWidget.tabRevisitTick) {
      restaurantCartStore.loadCartItems();
      if (_searchController.text.isNotEmpty) _searchController.clear();
      if (_listScrollController.hasClients) _listScrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    AppSettings.settingsNotifier.removeListener(_onSettingsChanged);
    _stagingSections.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _handleItemTap(Items item) async {
    final strictlyPending = await DayManagementService.isEodStrictlyPending();
    if (strictlyPending) {
      NotificationService.instance.showError(
        'Day has ended. Complete End of Day to unlock.',
      );
      return;
    }

    if (item.isSoldByWeight) {
      final CartItem? weightCartItem = await showWeightItemDialog(
        context,
        item,
      );
      if (weightCartItem != null) {
        await _addItemToCart(weightCartItem);
      }
      return;
    }

    final bool hasVariants = item.variant != null && item.variant!.isNotEmpty;
    final bool hasExtra = item.extraId != null && item.extraId!.isNotEmpty;
    final bool hasChoice = item.choiceIds != null && item.choiceIds!.isNotEmpty;
    String? categoryName;
    try {
      final category = categoryStore.categories.firstWhere(
        (cat) => cat.id == item.categoryOfItem,
      );
      categoryName = category.name;
    } catch (e) {
      categoryName = 'Uncategorized';
    }

    if (hasVariants || hasExtra || hasChoice) {
      CartItem? result;

      if (AppResponsive.isMobile(context)) {
        result = await showModalBottomSheet<CartItem>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: ItemOptionsDialog(
                  item: item,
                  categoryName: categoryName,
                ),
              ),
            );
          },
        );
      } else {
        final hInset =
            ((AppResponsive.screenWidth(context) -
                        AppResponsive.dialogWidth(context)) /
                    2)
                .clamp(40.0, 300.0);
        result = await showDialog<CartItem>(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: AppColors.white,
            insetPadding: EdgeInsets.symmetric(
              horizontal: hInset,
              vertical: 40,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: ItemOptionsDialog(item: item, categoryName: categoryName),
          ),
        );
      }

      if (result != null) {
        await _addItemToCart(result);
      }
    } else {
      final simpleCartItem = CartItem(
        productId: item.id,
        isStockManaged: item.trackInventory,
        id: const Uuid().v4(),
        title: item.name,
        price: item.price ?? 0,
        quantity: 1,
        taxRate: item.taxRate,
        weightDisplay: null,
        categoryName: categoryName,
      );

      await _addItemToCart(simpleCartItem);
    }
  }

  Future<void> _addItemToCart(CartItem cartItem) async {
    // First item of a not-yet-started day → offer to start it now (cancelable).
    // Either choice still adds the item; the day is ENFORCED at checkout, so an
    // order can never be placed without a session even if this is cancelled.
    if (restaurantCartStore.cartItems.isEmpty &&
        !await DayManagementService.isSessionOpen() &&
        mounted) {
      await promptStartDay(context);
    }
    try {
      final result = await restaurantCartStore.addToCart(cartItem);

      if (result['success'] == true) {
        if (mounted) {
          NotificationService.instance.showSuccess(
            '${cartItem.title} added to cart',
          );
        }
      } else {
        if (mounted) {
          NotificationService.instance.showError(
            result['message'] ?? 'Cannot add item to cart',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error adding item to cart');
      }
    }
  }

  String _formatStockDisplay(Items item) {
    if (!InventoryService.isStockGoverned(item)) return '';

    final allowOrderWhenOutOfStock = item.allowOrderWhenOutOfStock;

    // Recipe-Based items hold no stock of their own — show how many the
    // current ingredient stock can make. Checked before the variant branch:
    // v1 recipes are item-level, so a variant's own stock is meaningless here.
    if (item.isRecipeBased) {
      final recipe = recipeRepository.getRecipeForItem(item.id);
      if (recipe == null || !recipe.hasIngredients) {
        return 'Recipe Not Configured';
      }
      final canMake = InventoryService.effectiveAvailableStock(item);
      if (canMake <= 0) {
        return allowOrderWhenOutOfStock ? 'Order Available' : 'Out of Stock';
      }
      if (canMake.isInfinite) return '';
      return 'Makes ${canMake.toStringAsFixed(0)}';
    }

    // For items with variants, show variant availability status
    if (item.variant != null && item.variant!.isNotEmpty) {
      int inStockCount = 0;
      int totalVariants = item.variant!.length;

      for (var variant in item.variant!) {
        final variantStock = variant.stockQuantity ?? 0;
        if (variantStock > 0) {
          inStockCount++;
        }
      }

      if (inStockCount == 0) {
        // All variants out of stock
        if (allowOrderWhenOutOfStock) {
          return 'Order Available';
        } else {
          return 'Out of Stock';
        }
      } else if (inStockCount == totalVariants) {
        // All variants in stock
        return 'All Variants Available';
      } else {
        // Some variants in stock
        return '$inStockCount/$totalVariants Variants';
      }
    }

    // For regular items without variants, show base stock
    final stock = item.stockQuantity;
    final unit = item.unit ?? (item.isSoldByWeight ? 'kg' : 'pcs');

    if (stock <= 0) {
      if (allowOrderWhenOutOfStock) {
        return 'Order Available';
      } else {
        return 'Out of Stock';
      }
    }

    if (item.isSoldByWeight) {
      final upperUnit = unit.toUpperCase();
      final isGm =
          upperUnit.contains('GM') ||
          upperUnit.contains('GRAM') ||
          upperUnit == 'G';
      final isKg = upperUnit.contains('KG');

      if (isGm && stock >= 1000) {
        // Stock in grams but large enough to show as kg
        final kg = stock / 1000;
        return '${kg.toStringAsFixed(kg == kg.roundToDouble() ? 0 : 1)} kg';
      } else if (isKg || isGm) {
        // Show in item's own unit
        final formatted = stock == stock.roundToDouble()
            ? stock.toStringAsFixed(0)
            : stock.toStringAsFixed(2);
        return '$formatted $unit';
      }
      return '${stock.toStringAsFixed(2)} $unit';
    } else {
      return '${stock.toStringAsFixed(0)} $unit';
    }
  }

  StockStatus _getStockStatus(Items item) {
    if (!InventoryService.isStockGoverned(item)) return StockStatus.notTracked;

    final allowOrderWhenOutOfStock = item.allowOrderWhenOutOfStock;

    // Recipe-Based: availability comes from ingredients, not a stored figure.
    if (item.isRecipeBased) {
      final recipe = recipeRepository.getRecipeForItem(item.id);
      if (recipe == null || !recipe.hasIngredients) {
        return StockStatus.outOfStock;
      }
      switch (InventoryService.posStatusFromAvailable(
        available: InventoryService.effectiveAvailableStock(item),
        allowOrderWhenOutOfStock: allowOrderWhenOutOfStock,
      )) {
        case PosStockStatus.inStock:
          return StockStatus.inStock;
        case PosStockStatus.orderAvailable:
          return StockStatus.orderAvailable;
        case PosStockStatus.outOfStock:
          return StockStatus.outOfStock;
        case PosStockStatus.notTracked:
          return StockStatus.notTracked;
      }
    }

    // For items with variants, check if at least one variant has stock
    if (item.variant != null && item.variant!.isNotEmpty) {
      bool hasAnyVariantInStock = false;

      for (var variant in item.variant!) {
        final variantStock = variant.stockQuantity ?? 0;
        if (variantStock > 0) {
          hasAnyVariantInStock = true;
          break;
        }
      }

      if (hasAnyVariantInStock) {
        return StockStatus.inStock;
      } else {
        // All variants are out of stock
        if (allowOrderWhenOutOfStock) {
          return StockStatus.orderAvailable;
        } else {
          return StockStatus.outOfStock;
        }
      }
    }

    // For regular items without variants, check base stock
    final stock = item.stockQuantity;
    if (stock <= 0) {
      if (allowOrderWhenOutOfStock) {
        return StockStatus.orderAvailable;
      } else {
        return StockStatus.outOfStock;
      }
    } else {
      return StockStatus.inStock;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    final size = MediaQuery.of(context).size;
    final isTablet = !AppResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: isTablet
          ? _buildTabletLayout(context, size)
          : _buildMobileLayout(context, size),
    );
  }

  Widget _buildMobileLayout(BuildContext context, Size size) {
    final height = size.height;

    return Stack(
      children: [
        // NOT wrapped in an Observer. The only cart-dependent part of this
        // column is the bottom reserve for the cart bar, and that now has its
        // own Observer at the end of the column — observing the cart here
        // rebuilt the search field, the category strip and every category
        // section on each add/quantity/remove.
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                // The sort button listens to ListSortService itself, so this
                // header stays outside any sort listener — see ListSortButton.
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          hint: 'Search Items',
                          icon: Icons.search_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const ListSortButton(list: SortableList.posMenu),
                    ],
                  ),
                ),
              ),

              // Horizontal category quick-nav strip — replaces the category FAB
              ListenableBuilder(
                listenable: ListSortService.instance,
                builder: (context, _) => Observer(
                  builder: (_) {
                    final enabledItems = itemStore.items
                        .where((i) => i.isEnabled && i.sellsAtPos)
                        .toList();
                    // Sorted so the strip's pill order matches the section
                    // order below it — they are two views of one list.
                    final cats = _sortCategories(
                      categoryStore.categoriesWithItems(enabledItems),
                    );
                    // Show a Favorites pill first, but only when there are
                    // favorites to jump to (mirrors hiding empty categories).
                    final hasFav = enabledItems.any((i) => i.isFavorite);
                    return _HorizontalCategoryStrip(
                      categories: cats,
                      hasFavorites: hasFav,
                      activeCategory: activeCategory,
                      onCategorySelected: _selectStripCategory,
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),

              // Collapsible Category Sections
              Expanded(
                child: _isLoadingData
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Loading menu...',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListenableBuilder(
                        // Scoped to the section list only — the header above
                        // stays out of it, and the sort changes rarely (a user
                        // pick, plus one notification when prefs load).
                        listenable: ListSortService.instance,
                        builder: (context, _) => Observer(
                          builder: (_) {
                            final allCategories = categoryStore.categories;

                            if (allCategories.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.category_outlined,
                                      size: 64,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No Categories Found',
                                      style: GoogleFonts.poppins(
                                        fontSize:
                                            AppResponsive.subheadingFontSize(
                                              context,
                                            ),
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final allItems = itemStore.items;
                            // Sorted here once — favourites, every category
                            // section and the uncategorised bucket all derive
                            // from this list via `.where`, which keeps order.
                            final visibleItems = _sortItems(
                              allItems
                                  .where(
                                    (item) => item.isEnabled && item.sellsAtPos,
                                  )
                                  .toList(),
                            );
                            final lowerQuery = query.toLowerCase();
                            // Deliberately NO cart read here. Each item tile
                            // observes its own cart state
                            // (`cartStateFor(item.id)`), so a lazily-built
                            // tile still tracks add/remove/qty without this
                            // Observer — and the sections around it — having
                            // to rebuild for every cart write.

                            // Hide categories with no items — the order screen only
                            // needs categories you can actually pick from.
                            final categories = _sortCategories(
                              categoryStore.categoriesWithItems(visibleItems),
                            );

                            // Sections open a couple per frame from here
                            // (see STAGED SECTION EXPANSION).
                            final sectionsExpand =
                                query.isNotEmpty ||
                                AppSettings.keepCategoriesOpen;
                            // Small menu: skip the staging entirely.
                            final stagedFill =
                                visibleItems.length > _kStageAboveItemCount;
                            _stagedFill = stagedFill;
                            _itemsBudgetUsed = 0;
                            // Render order: favourites, the categories, then the
                            // uncategorised bucket. The two sentinels are queued
                            // unconditionally — if that section isn't showing,
                            // opening it is a no-op.
                            _syncSectionExpansion(
                              sectionsExpand,
                              staged: stagedFill,
                              [
                                _kFavorites,
                                ...categories.map<String>((c) => c.id),
                                '__uncategorised__',
                              ],
                            );

                            // Searching but nothing matches → empty state instead
                            // of a blank scroll area.
                            if (query.isNotEmpty &&
                                !visibleItems.any(
                                  (item) =>
                                      item.name.toLowerCase().contains(
                                        lowerQuery,
                                      ) ||
                                      (item.itemCode != null &&
                                          item.itemCode!.toLowerCase().contains(
                                            lowerQuery,
                                          )),
                                )) {
                              return const AppEmptyState(
                                icon: Icons.search_off_rounded,
                                title: 'No items found',
                                message: 'Try a different search term.',
                              );
                            }

                            final sectionList = NotificationListener<ScrollNotification>(
                              // Hold the staged opening while the user is
                              // actually scrolling, then pick it up again.
                              onNotification: (notification) {
                                if (notification is ScrollStartNotification) {
                                  _scrollInProgress = true;
                                } else if (notification
                                        is ScrollEndNotification ||
                                    notification is UserScrollNotification &&
                                        notification.direction ==
                                            ScrollDirection.idle) {
                                  if (_scrollInProgress) {
                                    _scrollInProgress = false;
                                    _scheduleExpansionDrain();
                                  }
                                }
                                return false;
                              },
                              child: SingleChildScrollView(
                                controller: _listScrollController,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                child: Column(
                                  children: [
                                    _buildFavoritesSection(
                                      visibleItems,
                                      query,
                                      lowerQuery,
                                    ),
                                    ...categories.map((category) {
                                      if (!_categoryKeys.containsKey(
                                        category.id,
                                      )) {
                                        _categoryKeys[category.id] =
                                            GlobalKey();
                                      }
                                      if (!_expansionControllers.containsKey(
                                        category.id,
                                      )) {
                                        _expansionControllers[category.id] =
                                            ExpansibleController();
                                      }

                                      final categoryItems = visibleItems
                                          .where(
                                            (item) =>
                                                item.categoryOfItem ==
                                                category.id,
                                          )
                                          .toList();

                                      final searchFilteredItems = query.isEmpty
                                          ? categoryItems
                                          : categoryItems.where((item) {
                                              return item.name
                                                      .toLowerCase()
                                                      .contains(lowerQuery) ||
                                                  (item.itemCode != null &&
                                                      item.itemCode!
                                                          .toLowerCase()
                                                          .contains(
                                                            lowerQuery,
                                                          ));
                                            }).toList();

                                      // Don't show empty categories when searching
                                      if (query.isNotEmpty &&
                                          searchFilteredItems.isEmpty) {
                                        return const SizedBox.shrink();
                                      }

                                      return _CategorySectionCard(
                                        category: category,
                                        searchFilteredItems:
                                            searchFilteredItems,
                                        // Only the first sections render open in
                                        // the first frame; the staged drain opens
                                        // the rest.
                                        initiallyExpanded:
                                            sectionsExpand &&
                                            _opensImmediately(
                                              category.id,
                                              searchFilteredItems.length,
                                            ),
                                        controller:
                                            _expansionControllers[category.id],
                                        cardKey: _categoryKeys[category.id]!,
                                        onItemTap: _handleItemTap,
                                        onToggleFavorite: _toggleFavorite,
                                        formatStock: _formatStockDisplay,
                                        getStockStatus: _getStockStatus,
                                        // Opt-in grid mode (was the separate
                                        // MenuGridScreen) — mobile only; tablet has
                                        // its own grid layout.
                                        gridView: AppSettings.menuGridView,
                                        buildGridCard: _buildGridItemCard,
                                      );
                                    }).toList(),
                                    _buildUncategorisedSection(
                                      visibleItems,
                                      categories,
                                      query,
                                      lowerQuery,
                                    ),
                                  ],
                                ),
                              ),
                            );

                            // While the sections are still opening, hold the
                            // list still and say so. Scrolling mid-fill is what
                            // felt like a stutter, and a frozen list also lets
                            // the queue run at full speed instead of yielding to
                            // the gesture.
                            //
                            // `child:` is the already-built list, handed through
                            // untouched — the tiles are NOT rebuilt when this
                            // flips.
                            return ValueListenableBuilder<bool>(
                              valueListenable: _stagingSections,
                              child: sectionList,
                              builder: (context, staging, child) {
                                if (!staging) return child!;
                                return Stack(
                                  children: [
                                    AbsorbPointer(
                                      child: ScrollConfiguration(
                                        behavior: const _FrozenScrollBehavior(),
                                        child: child!,
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 16,
                                      child: Center(
                                        child: _buildPreparingBanner(context),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
              ),

              // Room for the cart bar that floats over this column. Its
              // own Observer: a cart change resizes this spacer instead of
              // rebuilding the column above it.
              Observer(
                builder: (_) => SizedBox(
                  height: restaurantCartStore.cartItems.isEmpty ? 0 : 80,
                ),
              ),
            ],
          ),
        ),

        // Fixed Cart Bar at Bottom
        Observer(
          builder: (_) {
            if (restaurantCartStore.cartItems.isEmpty) return SizedBox.shrink();
            return Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildCartBar(context),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context, Size size) {
    final showCartPane = menuShowsCartPane(context);

    return Row(
      children: [
        // Left Sidebar — category navigation
        Container(
          // Sidebar holds category names; a fixed 220 is only 15% of a 1440px
          // window and truncates longer names.
          width: AppResponsive.getValue(
            context,
            mobile: 220.0,
            tablet: 220.0,
            desktop: 260.0,
          ),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border(right: BorderSide(color: AppColors.divider)),
          ),
          child: ListenableBuilder(
            listenable: ListSortService.instance,
            builder: (context, _) => Observer(
              builder: (_) {
                final enabledItems = itemStore.items
                    .where((i) => i.isEnabled && i.sellsAtPos)
                    .toList();
                final allCategories = _sortCategories(
                  categoryStore.categoriesWithItems(enabledItems),
                );
                return Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _searchController,
                                hint: 'Search items…',
                                icon: Icons.search_rounded,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const ListSortButton(list: SortableList.posMenu),
                          ],
                        ),
                      ),
                    ),

                    // Favorites Button (pinned at top)
                    _buildCategoryButton(
                      icon: Icons.star_rounded,
                      label: 'Favorites',
                      isSelected: activeCategory == _kFavorites,
                      onTap: () => setState(() => activeCategory = _kFavorites),
                    ),

                    // All Items Button
                    _buildCategoryButton(
                      icon: Icons.grid_view,
                      label: 'All Items',
                      isSelected: activeCategory == null,
                      onTap: () => setState(() => activeCategory = null),
                    ),

                    // Category List
                    Expanded(
                      child: ListView.builder(
                        itemCount: allCategories.length,
                        itemBuilder: (context, index) {
                          final category = allCategories[index];
                          return _buildCategoryButton(
                            icon: Icons.folder_outlined,
                            label: category.name,
                            isSelected: activeCategory == category.id,
                            onTap: () =>
                                setState(() => activeCategory = category.id),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        // Main Content Area
        Expanded(
          child: _isLoadingData
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading menu...',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.bodyFontSize(context),
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    ListenableBuilder(
                      listenable: ListSortService.instance,
                      builder: (context, _) => Observer(
                        builder: (_) {
                          final hasItems =
                              restaurantCartStore.cartItems.isNotEmpty;
                          // No cart snapshot: each grid card observes its own
                          // in-cart badge state (see `_buildGridItemCard`).
                          final allItems = itemStore.items;
                          // Sorted once here; the category/favourite/search
                          // narrowing below is all `.where`, which keeps order.
                          var filteredItems = _sortItems(
                            allItems
                                .where(
                                  (item) => item.isEnabled && item.sellsAtPos,
                                )
                                .toList(),
                          );

                          if (activeCategory == _kFavorites) {
                            filteredItems = filteredItems
                                .where((item) => item.isFavorite)
                                .toList();
                          } else if (activeCategory != null) {
                            filteredItems = filteredItems
                                .where(
                                  (item) =>
                                      item.categoryOfItem == activeCategory,
                                )
                                .toList();
                          }

                          if (query.isNotEmpty) {
                            final lowerQuery = query.toLowerCase();
                            filteredItems = filteredItems
                                .where(
                                  (item) =>
                                      item.name.toLowerCase().contains(
                                        lowerQuery,
                                      ) ||
                                      (item.itemCode != null &&
                                          item.itemCode!.toLowerCase().contains(
                                            lowerQuery,
                                          )),
                                )
                                .toList();
                          }

                          if (filteredItems.isEmpty) {
                            return AppEmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No items found',
                              message: query.isNotEmpty
                                  ? 'Try a different search term.'
                                  : 'No items in this category yet.',
                            );
                          }

                          final isDesktop = AppResponsive.isDesktop(context);
                          final aspectRatio = AppResponsive.getValue(
                            context,
                            mobile: 0.75,
                            tablet: 0.70,
                            // Ignored on desktop — mainAxisExtent pins the height there instead.
                            desktop: 0.75,
                          );

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: (hasItems && !showCartPane) ? 80 : 16,
                            ),
                            // Measures the grid pane, not the screen. Only the
                            // bottom padding sits above this, so maxWidth is the
                            // true width the cells divide up.
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final gridColumns = isDesktop
                                    ? menuGridColumnsForPane(
                                        constraints.maxWidth,
                                      )
                                    : AppResponsive.gridColumns(
                                        context,
                                        mobile: 2,
                                        tablet: 3,
                                        desktop: 4,
                                      );
                                return GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: gridColumns,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        // Absolute height on desktop — see
                                        // kMenuItemCardHeightDesktop.
                                        mainAxisExtent: isDesktop
                                            ? kMenuItemCardHeightDesktop
                                            : null,
                                        childAspectRatio: aspectRatio,
                                      ),
                                  itemCount: filteredItems.length,
                                  itemBuilder: (context, index) =>
                                      _buildGridItemCard(filteredItems[index]),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),

                    // Fixed Cart Bar at Bottom — only when the cart is not
                    // already shown as a pane beside this one.
                    Observer(
                      builder: (_) {
                        if (showCartPane ||
                            restaurantCartStore.cartItems.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: _buildCartBar(context),
                        );
                      },
                    ),
                  ],
                ),
        ),

        // Right Pane — inline cart, wide desktops only
        if (showCartPane) _buildCartPane(context),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // INLINE CART PANE  (>= kMenuCartPaneBreakpoint)
  // ═════════════════════════════════════════════════════════════════════════

  /// The cart, shown beside the menu instead of behind a full-screen push.
  ///
  /// Deliberately NOT a reuse of `CartScreen`: that is a 1100-line route with
  /// its own Scaffold, AppBar and back-press handling, and it still owns
  /// checkout. This pane covers the add-items loop — see, adjust, remove — and
  /// hands off to `CartScreen` unchanged at Checkout.
  Widget _buildCartPane(BuildContext context) {
    return Container(
      width: kMenuCartPaneWidth,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(left: BorderSide(color: AppColors.divider)),
      ),
      child: Observer(
        builder: (_) {
          final items = restaurantCartStore.cartItems.toList();
          return Column(
            children: [
              _buildCartPaneHeader(context, items.length),
              const Divider(height: 1),
              Expanded(
                child: items.isEmpty
                    ? AppEmptyState(
                        icon: Icons.shopping_cart_outlined,
                        title: 'Cart is empty',
                        message: 'Tap an item to add it to the order.',
                      )
                    : ListView.separated(
                        padding: EdgeInsets.symmetric(
                          vertical: AppResponsive.smallSpacing(context),
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) =>
                            _buildCartPaneLine(context, items[i]),
                      ),
              ),
              if (items.isNotEmpty) _buildCartPaneFooter(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCartPaneHeader(BuildContext context, int lineCount) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.mediumSpacing(context),
        vertical: AppResponsive.smallSpacing(context) + 4,
      ),
      child: Row(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: AppResponsive.iconSize(context),
            color: AppColors.primary,
          ),
          SizedBox(width: AppResponsive.smallSpacing(context)),
          Expanded(
            child: Text(
              'Current Order',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.subheadingFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (lineCount > 0)
            Text(
              '$lineCount ${lineCount == 1 ? 'line' : 'lines'}',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  /// One cart line: name + options above, stepper and line total below.
  ///
  /// Two rows rather than one. A 380px pane minus padding leaves ~348px, and a
  /// stepper (~104) plus a price (~80) plus a delete target (~40) claims 224 of
  /// it — which would hand a name like "Paneer Butter Masala" about 120px.
  Widget _buildCartPaneLine(BuildContext context, CartItem item) {
    final subtitle = _cartPaneLineSubtitle(item);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.mediumSpacing(context),
        vertical: AppResponsive.smallSpacing(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            // 2px: groups the option line to its name, below the spacing floor.
            const SizedBox(height: 2),
            // Deliberately uncapped. This pane exists so you can check what was
            // added without opening the cart, and toppings are exactly what
            // gets checked — a maxLines cap would ellipsise the extras away and
            // send you to the cart anyway. A line with many extras is tall, and
            // the pane scrolls.
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ],
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Row(
            children: [
              _cartPaneStepper(context, item),
              const Spacer(),
              // Money must not wrap: scale it down before it grows the row.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.totalPrice)}',
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppResponsive.smallSpacing(context) / 2),
              IconButton(
                onPressed: () => restaurantCartStore.removeFromCart(item.id),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: AppResponsive.smallIconSize(context),
                  color: AppColors.danger,
                ),
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Variant, choices and note, joined — null when the line has none of them.
  String? _cartPaneLineSubtitle(CartItem item) {
    final parts = <String>[
      if ((item.variantName ?? '').isNotEmpty) item.variantName!,
      ...?item.choiceNames,
      ..._cartPaneExtras(item),
      if ((item.instruction ?? '').isNotEmpty) 'Note: ${item.instruction}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Extras (toppings / add-ons), grouped and formatted the same way
  /// `orderDetails.dart` does so the pane and the order screens agree:
  /// repeats of one extra collapse into `2x Cheese(₹40.00)`.
  List<String> _cartPaneExtras(CartItem item) {
    final extras = item.extras;
    if (extras == null || extras.isEmpty) return const [];

    final grouped = <String, Map<String, dynamic>>{};
    for (final extra in extras) {
      final name = extra['displayName'] ?? extra['name'] ?? 'Unknown';
      final price = extra['price']?.toDouble() ?? 0.0;
      final qty = extra['quantity']?.toInt() ?? 1;
      final key = '$name-${price.toStringAsFixed(2)}';
      if (grouped.containsKey(key)) {
        grouped[key]!['quantity'] = (grouped[key]!['quantity'] as int) + qty;
      } else {
        grouped[key] = {'displayName': name, 'price': price, 'quantity': qty};
      }
    }

    return grouped.values.map((e) {
      final qty = e['quantity'] as int;
      final name = e['displayName'] as String;
      final price = e['price'] as double;
      final money =
          '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(price)}';
      return qty > 1 ? '${qty}x $name($money)' : '$name($money)';
    }).toList();
  }

  /// Quantity stepper. Both directions go through `updateQuantity`, which
  /// validates stock on the way up and routes 0 to `removeFromCart` on the way
  /// down — so this never needs to special-case the last unit.
  Widget _cartPaneStepper(BuildContext context, CartItem item) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(
          AppResponsive.smallBorderRadius(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepperButton(
            context,
            Icons.remove_rounded,
            () =>
                restaurantCartStore.updateQuantity(item.id, item.quantity - 1),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.smallSpacing(context),
            ),
            child: Text(
              '${item.quantity}',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _stepperButton(
            context,
            Icons.add_rounded,
            () =>
                restaurantCartStore.updateQuantity(item.id, item.quantity + 1),
          ),
        ],
      ),
    );
  }

  Widget _stepperButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        AppResponsive.smallBorderRadius(context),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppResponsive.smallSpacing(context) / 2),
        child: Icon(
          icon,
          size: AppResponsive.smallIconSize(context),
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildCartPaneFooter(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${restaurantCartStore.totalQuantity} '
                '${restaurantCartStore.totalQuantity == 1 ? 'item' : 'items'}',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(restaurantCartStore.cartTotal)}',
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.headingFontSize(context),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          SizedBox(
            width: double.infinity,
            height: AppResponsive.buttonHeight(context),
            child: CommonButton(
              bordercircular: 10,
              bgcolor: AppColors.primary,
              height: AppResponsive.buttonHeight(context),
              onTap: _openCheckout,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.isForAddingItem == true ? 'Done' : 'Checkout',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.buttonFontSize(context),
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: AppResponsive.smallSpacing(context) / 2),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: AppResponsive.captionFontSize(context),
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Same destination the bottom bar View Cart button uses — the pane replaces
  /// the browsing trip to the cart, not the checkout route itself.
  Future<void> _openCheckout() async {
    if (widget.isForAddingItem == true) {
      Navigator.pop(context);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CartScreen(selectedTableNo: widget.tableIdForNewOrder),
      ),
    );
  }

  Widget _buildCategoryButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.white : AppColors.textSecondary,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppColors.white : AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItemCard(Items item) {
    final stockStatus = _getStockStatus(item);
    return _GridItemCard(
      item: item,
      isDisabled: stockStatus == StockStatus.outOfStock,
      priceLabel: _getPriceDisplayForGrid(item),
      onTap: _handleItemTap,
      buildImage: _buildItemImageForGrid,
      favStar: _favStar,
    );
  }

  Widget _buildItemImageForGrid(Items item) {
    if (item.imageBytes != null && item.imageBytes!.isNotEmpty) {
      final file = item.imageBytes;
      if (file != null)
        return Image.memory(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: ImageDecodeSizes.gridTile,
        );
    }
    return Icon(
      Icons.fastfood_rounded,
      size: 48,
      color: AppColors.textSecondary,
    );
  }

  String _getPriceDisplayForGrid(Items item) {
    if (item.price != null)
      return '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.price!)}';
    if (item.variant != null && item.variant!.isNotEmpty)
      return '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(item.variant!.first.price)}+';
    return 'N/A';
  }

  void _scrollToCategoryWhenStable(
    String categoryId,
    int requestId, {
    int maxFrames = 20,
  }) {
    double lastHeight = 0.0;
    int frameCount = 0;

    void checkStability() {
      if (!mounted || requestId != _scrollRequestId) return;

      final key = _categoryKeys[categoryId];
      final context = key?.currentContext;

      if (context != null) {
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final double currentHeight = box.size.height;
          frameCount++;

          debugPrint(
            '[MENU_TRACE] [SCROLL-POLL] t=${DateTime.now().millisecondsSinceEpoch}ms categoryId=$categoryId frame=$frameCount height=$currentHeight',
          );

          const double kHeightTolerance = 0.5;
          if ((currentHeight - lastHeight).abs() > kHeightTolerance &&
              frameCount < maxFrames) {
            lastHeight = currentHeight;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => checkStability(),
            );
            return;
          }
        }
      }

      if (context != null && mounted && requestId == _scrollRequestId) {
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box != null && box.attached) {
          final RenderBox? scrollBox =
              Scrollable.maybeOf(context)?.context.findRenderObject()
                  as RenderBox?;
          if (scrollBox != null) {
            try {
              final double localY = box
                  .localToGlobal(Offset.zero, ancestor: scrollBox)
                  .dy;
              if (localY.abs() < 1.5) {
                return;
              }
              if (_listScrollController.hasClients) {
                final double currentOffset = _listScrollController.offset;
                final double maxOffset =
                    _listScrollController.position.maxScrollExtent;
                if ((currentOffset - maxOffset).abs() < 1.5) {
                  return;
                }
              }
            } catch (_) {}
          }

          final offset = _listScrollController.hasClients
              ? _listScrollController.offset
              : 0.0;
          debugPrint(
            '[MENU_TRACE] [SCROLL-STABLE] t=${DateTime.now().millisecondsSinceEpoch}ms categoryId=$categoryId offset=$offset',
          );

          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: 0.0,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
          );
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => checkStability());
  }

  /// A single pill in the horizontal quick-nav strip. Shared by the Favorites
  /// chip and the per-category chips.
  void _selectStripCategory(String categoryId) {
    // Collapse the previously active category — unless the user opted to keep
    // every opened category expanded (Customization → Keep Categories Open).
    if (!AppSettings.keepCategoriesOpen &&
        activeCategory != null &&
        activeCategory != categoryId) {
      final prev = _expansionControllers[activeCategory];
      if (prev != null) {
        try {
          debugPrint(
            '[MENU_TRACE] [COLLAPSE] t=${DateTime.now().millisecondsSinceEpoch}ms categoryId=$activeCategory',
          );
          prev.collapse();
        } catch (_) {}
      }
    }

    activeCategory = categoryId;

    // Expand the selected category immediately (always built and mounted)
    final ctrl = _expansionControllers[categoryId];
    if (ctrl != null) {
      try {
        debugPrint(
          '[MENU_TRACE] [EXPAND] t=${DateTime.now().millisecondsSinceEpoch}ms categoryId=$categoryId',
        );
        ctrl.expand();
      } catch (_) {}
    }

    // Increment request ID to cancel any pending stabilization frame checks
    final int currentId = ++_scrollRequestId;

    // Cancelable Dynamic Correction: Refocus precisely once layout has fully stabilized
    _scrollToCategoryWhenStable(categoryId, currentId);
  }

  /// Shown while the remaining categories are still opening.
  Widget _buildPreparingBanner(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.mediumSpacing(context),
        vertical: AppResponsive.smallSpacing(context),
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          SizedBox(width: AppResponsive.smallSpacing(context)),
          Text(
            'Preparing menu…',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 2,
              child: Observer(
                builder: (_) {
                  final cartItems = restaurantCartStore.cartItems;
                  final total = cartItems.fold(
                    0.0,
                    (sum, item) => sum + item.totalPrice,
                  );
                  final itemCount = cartItems.fold(
                    0,
                    (sum, item) => sum + item.quantity,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                        textScaler: TextScaler.linear(1),
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: AppResponsive.captionFontSize(context),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(total)}',
                        textScaler: TextScaler.linear(1),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: AppResponsive.subheadingFontSize(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: CommonButton(
                bordercircular: 10,
                bgcolor: Colors.white,
                height: AppResponsive.buttonHeight(context),
                onTap: () async {
                  if (widget.isForAddingItem == true) {
                    Navigator.pop(context);
                  } else {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CartScreen(
                          selectedTableNo: widget.tableIdForNewOrder,
                        ),
                      ),
                    );
                    // Cart items automatically update via MobX reactivity
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'View Cart',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                      textScaler: TextScaler.linear(1),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One item card in the menu GRID (tablet's grid, and mobile's opt-in "Menu
/// Grid View").
///
/// A [StatelessObserverWidget] so the card's element carries its own MobX
/// reaction: grid item builders run lazily, outside any enclosing `Observer`,
/// so the card has to track the cart itself — and doing it here rather than in
/// a nested `Observer` keeps it to one element per card.
class _GridItemCard extends StatelessObserverWidget {
  const _GridItemCard({
    required this.item,
    required this.isDisabled,
    required this.priceLabel,
    required this.onTap,
    required this.buildImage,
    required this.favStar,
  });

  final Items item;
  final bool isDisabled;
  final String priceLabel;
  final void Function(Items) onTap;
  final Widget Function(Items) buildImage;
  final Widget Function(Items) favStar;

  @override
  Widget build(BuildContext context) {
    // Read HERE, in the tracked build, so the card reacts to ITS item going
    // in and out of the cart without the menu around it rebuilding. Same
    // reason `_ItemListTile` is a StatefulObserverWidget.
    final cart = restaurantCartStore.cartStateFor(item.id).value;
    final int cartQty = cart.quantity;
    final bool inCart = cart.inCart;

    return ValueListenableBuilder<Map<String, bool>>(
      valueListenable: AppSettings.settingsNotifier,
      builder: (context, _, __) {
        final showImage = AppSettings.showItemImage;
        final showPrice = AppSettings.showItemPrice;

        return GestureDetector(
          onTap: isDisabled ? null : () => onTap(item),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDisabled
                      ? AppColors.surfaceMedium.withOpacity(0.5)
                      : inCart
                      ? AppColors.primary.withOpacity(0.04)
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  // In-cart items stay calm: a thin accent border + the small green
                  // "in cart" pill mark them, instead of a heavy fill/glow.
                  border: Border.all(
                    color: inCart
                        ? AppColors.primary.withOpacity(0.45)
                        : (isDisabled
                              ? AppColors.divider
                              : AppColors.divider.withOpacity(0.5)),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item Image — conditionally shown
                    if (showImage)
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMedium,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: Center(child: buildImage(item)),
                        ),
                      ),

                    // Item Details
                    Expanded(
                      flex: showImage ? 2 : 1,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (item.isVeg != null) ...[
                                      _buildVegIndicator(item.isVeg),
                                      const SizedBox(width: 6),
                                    ],
                                    Expanded(
                                      child: Text(
                                        (item.itemCode != null &&
                                                item.itemCode!.isNotEmpty)
                                            ? '${item.itemCode} ${item.name}'
                                            : item.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: AppResponsive.bodyFontSize(
                                            context,
                                          ),
                                          fontWeight: FontWeight.w600,
                                          color: isDisabled
                                              ? AppColors.textSecondary
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (showPrice)
                                  Text(
                                    priceLabel,
                                    style: GoogleFonts.poppins(
                                      fontSize: AppResponsive.bodyFontSize(
                                        context,
                                      ),
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                if (!isDisabled)
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.add,
                                          color: AppColors.white,
                                          size: 16,
                                        ),
                                      ),
                                      if (inCart)
                                        Positioned(
                                          top: -7,
                                          right: -7,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            constraints: const BoxConstraints(
                                              minWidth: 18,
                                              minHeight: 18,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.accent,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Text(
                                              '$cartQty',
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.poppins(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(top: 6, right: 6, child: favStar(item)),
              // "In cart" pill at the top-left mirrors the favourite star.
              if (inCart)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _cartLabel(cart),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Short cart label for the grid pill: total qty, or variant breakdown when
  /// the item was added with variants (e.g. "Large ×2, Regular ×1").
  String _cartLabel(ProductCartState cart) {
    if (cart.variantBreakdown.isEmpty) return 'In cart · ${cart.quantity}';
    return cart.variantBreakdown.join(', ');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ITEM LIST TILE
// ═══════════════════════════════════════════════════════════════════════════
/// A [StatefulObserverWidget], not a plain one wrapped in an `Observer`: the
/// tile's own element carries the MobX reaction, so per-tile cart reactivity
/// costs no extra element in a list that can mount a thousand tiles at once.
class _ItemListTile extends StatefulObserverWidget {
  final Items item;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final String Function(Items) formatStock;
  final StockStatus Function(Items) getStockStatus;

  const _ItemListTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onToggleFavorite,
    required this.formatStock,
    required this.getStockStatus,
  });

  @override
  State<_ItemListTile> createState() => _ItemListTileState();
}

class _ItemListTileState extends State<_ItemListTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final stockStatus = widget.getStockStatus(widget.item);
    final isDisabled = stockStatus == StockStatus.outOfStock;

    // Read HERE, in the tracked build, so this tile — and only this tile —
    // rebuilds when its own cart state changes. `cartStateFor` is derived per
    // product, so adding a different item leaves this tile alone.
    final cart = restaurantCartStore.cartStateFor(widget.item.id).value;
    final int cartQty = cart.quantity;
    final bool inCart = cart.inCart;

    return ValueListenableBuilder<Map<String, bool>>(
      valueListenable: AppSettings.settingsNotifier,
      builder: (context, _, __) {
        final showImage = AppSettings.showItemImage;
        final showPrice = AppSettings.showItemPrice;

        return GestureDetector(
          onTapDown: isDisabled
              ? null
              : (_) => setState(() => _isPressed = true),
          onTapUp: isDisabled
              ? null
              : (_) {
                  setState(() => _isPressed = false);
                  widget.onTap();
                },
          onTapCancel: isDisabled
              ? null
              : () => setState(() => _isPressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(14),
            transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
            decoration: BoxDecoration(
              color: _isPressed
                  ? AppColors.primary.withOpacity(0.08)
                  : isDisabled
                  ? AppColors.surfaceMedium.withOpacity(0.5)
                  : inCart
                  ? AppColors.primary.withOpacity(0.04)
                  : AppColors.white,
              borderRadius: BorderRadius.circular(14),
              // In-cart items stay calm: a thin accent border + the small green
              // "in cart" chip mark them, instead of a heavy fill/glow.
              border: Border.all(
                color: _isPressed
                    ? AppColors.primary.withOpacity(0.3)
                    : inCart
                    ? AppColors.primary.withOpacity(0.45)
                    : isDisabled
                    ? AppColors.divider
                    : AppColors.divider.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                if (showImage) ...[
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMedium,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildItemImage(),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (widget.item.isVeg != null) ...[
                            _buildVegIndicator(widget.item.isVeg),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              (widget.item.itemCode != null &&
                                      widget.item.itemCode!.isNotEmpty)
                                  ? '${widget.item.itemCode} ${widget.item.name}'
                                  : widget.item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: FontWeight.w600,
                                color: isDisabled
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (showPrice)
                            Text(
                              _getPriceDisplay(),
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.bodyFontSize(context),
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          if (widget.item.trackInventory) ...[
                            if (showPrice) const SizedBox(width: 10),
                            Flexible(child: _buildStockBadge(stockStatus)),
                          ],
                        ],
                      ),
                      // In-cart summary: total qty, or per-variant breakdown.
                      if (inCart) ...[
                        const SizedBox(height: 6),
                        _buildCartSummary(cart),
                      ],
                    ],
                  ),
                ),
                // GestureDetector, not InkWell: the ink response pulled Focus,
                // Actions and its own ink internals into EVERY tile (~11
                // widgets each), which is the single heaviest thing a tile
                // built. Same tap target — `opaque` keeps the 6px padding
                // tappable the way the ink response did — same icon, same
                // button semantics; only the ripple is gone. Matches the
                // grid card's star (`_favStar`), which already works this way.
                Semantics(
                  button: true,
                  child: GestureDetector(
                    onTap: widget.onToggleFavorite,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        widget.item.isFavorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 22,
                        color: widget.item.isFavorite
                            ? Colors.amber
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                if (!isDisabled)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: AppColors.white,
                          size: 20,
                        ),
                      ),
                      // Count badge — how many of this item are in the cart.
                      if (inCart)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              '$cartQty',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Compact in-cart summary: "2 in cart" or per-variant "Large ×2, Regular ×1".
  Widget _buildCartSummary(ProductCartState cart) {
    final label = cart.variantBreakdown.isEmpty
        ? '${cart.quantity} in cart'
        : cart.variantBreakdown.join(', ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 13,
            color: AppColors.success,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage() {
    if (widget.item.imageBytes != null && widget.item.imageBytes!.isNotEmpty) {
      final file = widget.item.imageBytes;
      if (file != null)
        return Image.memory(
          file,
          fit: BoxFit.cover,
          width: 58,
          height: 58,
          cacheWidth: ImageDecodeSizes.thumbnail,
        );
    }
    return const Icon(
      Icons.fastfood_rounded,
      size: 26,
      color: AppColors.textSecondary,
    );
  }

  String _getPriceDisplay() {
    if (widget.item.price != null)
      return '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(widget.item.price!)}';
    if (widget.item.variant != null && widget.item.variant!.isNotEmpty)
      return '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(widget.item.variant!.first.price)}+';
    return 'Price N/A';
  }

  Widget _buildStockBadge(StockStatus status) {
    Color bgColor, textColor;
    String text = widget.formatStock(widget.item);
    switch (status) {
      case StockStatus.inStock:
        bgColor = AppColors.success.withOpacity(0.12);
        textColor = AppColors.success;
        break;
      case StockStatus.orderAvailable:
        bgColor = AppColors.warning.withOpacity(0.12);
        textColor = AppColors.warning;
        break;
      case StockStatus.outOfStock:
        bgColor = AppColors.danger.withOpacity(0.12);
        textColor = AppColors.danger;
        break;
      case StockStatus.notTracked:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.captionFontSize(context),
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

/// Freezes a scroll view without rebuilding it: the list widget stays the same
/// instance (so its tiles are not rebuilt) and only the inherited behaviour
/// changes while the menu is filling in.
class _FrozenScrollBehavior extends ScrollBehavior {
  const _FrozenScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const NeverScrollableScrollPhysics();
}

class _HorizontalCategoryStrip extends StatefulWidget {
  final List<dynamic> categories;
  final bool hasFavorites;
  final String? activeCategory;
  final ValueChanged<String> onCategorySelected;

  const _HorizontalCategoryStrip({
    required this.categories,
    required this.hasFavorites,
    required this.activeCategory,
    required this.onCategorySelected,
  });

  @override
  State<_HorizontalCategoryStrip> createState() =>
      _HorizontalCategoryStripState();
}

class _HorizontalCategoryStripState extends State<_HorizontalCategoryStrip> {
  String? _activeCategory;

  @override
  void initState() {
    super.initState();
    _activeCategory = widget.activeCategory;
  }

  @override
  void didUpdateWidget(covariant _HorizontalCategoryStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeCategory != oldWidget.activeCategory) {
      _activeCategory = widget.activeCategory;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty && !widget.hasFavorites) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: widget.categories.length + (widget.hasFavorites ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (widget.hasFavorites && i == 0) {
            return _buildStripChip(
              label: 'Favorites',
              icon: Icons.star_rounded,
              isActive: _activeCategory == _MenuScreenState._kFavorites,
              onTap: () {
                setState(() => _activeCategory = _MenuScreenState._kFavorites);
                widget.onCategorySelected(_MenuScreenState._kFavorites);
              },
            );
          }
          final cat = widget.categories[i - (widget.hasFavorites ? 1 : 0)];
          return _buildStripChip(
            label: cat.name,
            isActive: _activeCategory == cat.id,
            onTap: () {
              setState(() => _activeCategory = cat.id);
              widget.onCategorySelected(cat.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildStripChip({
    required String label,
    IconData? icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isActive ? Colors.white : Colors.amber,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildVegIndicator(String? isVeg) {
  if (isVeg == null) return const SizedBox.shrink();
  final clean = isVeg.toLowerCase().trim();
  if (clean != 'veg' && clean != 'non-veg') return const SizedBox.shrink();
  final isVegBool = clean == 'veg';
  final color = isVegBool ? Colors.green : Colors.red.shade800;
  return Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      border: Border.all(color: color, width: 1.2),
      color: Colors.transparent,
    ),
    padding: const EdgeInsets.all(1.5),
    child: Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}
