import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/data/models/common/categorymodel_300.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/dialog_dispose_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

import '../../../core/di/service_locator.dart';

/// Retail product categories. Also hosted as the Categories tab of
/// [ProductManagementScreen] — see [embedded].
class CategoryManagementScreen extends StatefulWidget {
  /// True when hosted as a tab of ProductManagementScreen — the host owns the
  /// AppBar (and its contextual Add action), so this screen drops its own.
  final bool embedded;

  /// Ticks when the host switches tabs; clears the search box so the other tab
  /// is never filtered by a query typed on this one.
  final Listenable? clearSearchSignal;

  const CategoryManagementScreen({
    super.key,
    this.embedded = false,
    this.clearSearchSignal,
  });

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    categoryStore.loadCategories();
    widget.clearSearchSignal?.addListener(_clearSearch);
  }

  @override
  void dispose() {
    widget.clearSearchSignal?.removeListener(_clearSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty && _searchQuery.isEmpty) return;
    _searchController.clear();
    if (mounted) setState(() => _searchQuery = '');
  }

  /// MUST be read inside an Observer — this is what registers the MobX
  /// dependency on the category list.
  List<Category> get _filteredCategories {
    if (_searchQuery.isEmpty) return categoryStore.categories;
    final query = _searchQuery.toLowerCase();
    return categoryStore.categories
        .where((cat) => cat.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: widget.embedded
          ? null
          : buildPrimaryAppBar(
              title: 'Categories',
              actions: [
                Observer(
                  builder: (_) => categoryStore.categories.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.add),
                          tooltip: 'Add Category',
                          onPressed: () => showAddCategoryDialog(context),
                        ),
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  // ==================== BODY ====================
  Widget _buildBody(BuildContext context) {
    return Observer(
      builder: (context) {
        if (categoryStore.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = _filteredCategories;
        if (categories.isEmpty) return _buildEmptyState();

        // Phones read better as a list; wider screens fit a card grid.
        if (AppResponsive.isMobile(context)) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: categories.length,
            itemBuilder: (context, index) =>
                _buildCategoryCard(categories[index]),
          );
        }

        final columns = AppResponsive.gridColumns(
          context,
          mobile: 1,
          tablet: 2,
          desktop: 3,
        );
        final spacing = AppResponsive.getValue(
          context,
          mobile: 16.0,
          tablet: 16.0,
          desktop: 24.0,
        );
        return GridView.builder(
          padding: AppResponsive.getValue(
            context,
            mobile: const EdgeInsets.all(20),
            tablet: const EdgeInsets.all(20),
            desktop: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 2.4,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) =>
              _buildCategoryCard(categories[index]),
        );
      },
    );
  }

  /// A search that matched nothing is a different problem from an empty
  /// catalog — only the latter gets an Add prompt.
  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      return const AppEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No categories found',
        message: 'Try a different search term.',
      );
    }
    return AppEmptyState(
      icon: Icons.category_outlined,
      title: 'No categories yet',
      message: 'Group your products so billing stays fast.',
      action: appEmptyStateAction(
        label: 'Add Category',
        onPressed: () => showAddCategoryDialog(context),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: AppTextField(
        controller: _searchController,
        hint: 'Search categories...',
        icon: Icons.search_rounded,
        // Only offered once there is something to clear.
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                tooltip: 'Clear search',
                visualDensity: VisualDensity.compact,
                onPressed: _clearSearch,
              ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  // ==================== CARD ====================
  /// One card for every breakpoint — the list and the grid both use it, so the
  /// edit/delete affordances can never drift apart.
  Widget _buildCategoryCard(Category category) {
    final productCount = categoryStore.getItemCountForCategory(category.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showEditCategoryDialog(category),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.category_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$productCount product${productCount == 1 ? '' : 's'}',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Edit/delete stay behind the overflow menu — never extra chips.
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                // M3 tints menu surfaces by default; keep them plain white.
                color: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditCategoryDialog(category);
                  } else if (value == 'delete') {
                    _confirmDelete(category);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Edit',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Delete',
                          style: GoogleFonts.poppins(
                            fontSize: AppResponsive.bodyFontSize(context),
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== DIALOGS ====================
  Future<void> _showEditCategoryDialog(Category category) async {
    final name = await _promptCategoryName(
      context: context,
      title: 'Edit Category',
      confirmLabel: 'Save',
      initialValue: category.name,
    );
    if (name == null || name.isEmpty) return;

    final updated = category.copyWith(
      name: name,
      lastEditedTime: DateTime.now(),
      editCount: category.editCount + 1,
    );

    final success = await categoryStore.updateCategory(updated);
    if (!mounted) return;
    if (success) {
      NotificationService.instance.showSuccess(
        'Category "${updated.name}" updated',
      );
    } else {
      NotificationService.instance.showError(
        categoryStore.errorMessage ?? 'Failed to update category',
      );
    }
  }

  Future<void> _confirmDelete(Category category) async {
    final productCount = categoryStore.getItemCountForCategory(category.id);

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete Category?',
      message: productCount > 0
          ? 'Delete "${category.name}"? $productCount product'
                '${productCount == 1 ? '' : 's'} will be moved to Uncategorized.'
          : 'Delete "${category.name}"?',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    final success = await categoryStore.deleteCategory(category.id);
    if (!mounted) return;
    if (success) {
      NotificationService.instance.showSuccess(
        'Category "${category.name}" deleted',
      );
    } else {
      NotificationService.instance.showError(
        categoryStore.errorMessage ?? 'Failed to delete category',
      );
    }
  }
}

// ── Shared entry points ──────────────────────────────────────────────────────
// Top-level so ProductManagementScreen's contextual "+" can open the same
// dialog the standalone screen uses, without reaching into its State.

/// Creates a new category. Safe to call from any context.
Future<void> showAddCategoryDialog(BuildContext context) async {
  final name = await _promptCategoryName(
    context: context,
    title: 'Add Category',
    subtitle: 'Groups products on the billing screen',
    confirmLabel: 'Add',
    hint: 'e.g. Electronics, Clothing',
  );
  if (name == null || name.isEmpty) return;

  final category = Category(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    name: name,
    createdTime: DateTime.now(),
  );

  final success = await categoryStore.addCategory(category);
  if (!context.mounted) return;
  if (success) {
    NotificationService.instance.showSuccess(
      'Category "${category.name}" added',
    );
  } else {
    NotificationService.instance.showError(
      categoryStore.errorMessage ?? 'Failed to add category',
    );
  }
}

/// Shared name prompt for add/edit. Returns the trimmed name, or null when the
/// user cancels. The text is captured before the pop, so nothing reads a
/// controller that [DialogDisposeScope] has already torn down.
Future<String?> _promptCategoryName({
  required BuildContext context,
  required String title,
  required String confirmLabel,
  String? subtitle,
  String? hint,
  String? initialValue,
}) {
  final controller = TextEditingController(text: initialValue);

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => DialogDisposeScope(
      disposables: [controller],
      child: AppDialogShell(
        title: title,
        subtitle: subtitle,
        accent: AppColors.primary,
        icon: Icons.category_rounded,
        body: AppTextField(
          controller: controller,
          label: 'Category Name',
          hint: hint,
          icon: Icons.category_outlined,
          required: true,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (v) => Navigator.pop(dialogContext, v.trim()),
        ),
        actions: [
          appDialogCancelButton(dialogContext),
          const SizedBox(width: 12),
          appDialogPrimaryButton(
            label: confirmLabel,
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
          ),
        ],
      ),
    ),
  );
}
