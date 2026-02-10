/*
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';

/// 🎯 GENERIC TAB MANAGER
///
/// A reusable component that handles common tab functionality for ANY data type.
/// Instead of creating separate tab components for Items, Categories, Variants, etc.,
/// we use ONE component with different configurations.
///
/// **Learning Goal**: Understand how generics (<T>) enable code reusability
///
/// Usage Example:
/// ```dart
/// GenericTabManager<Items>(
///   config: TabConfig<Items>(
///     dataStream: itemStore.itemsStream,
///     onDelete: (id) => itemStore.deleteItem(id),
///     onEdit: (item) => EdititemScreen(items: item),
///     searchHint: 'Search items...',
///     itemBuilder: (item) => ItemCard(item: item),
///   ),
/// )
/// ```
class GenericTabManager<T> extends StatefulWidget {
  /// Configuration object containing all tab-specific logic
  final TabConfig<T> config;

  const GenericTabManager({
    Key? key,
    required this.config,
  }) : super(key: key);

  @override
  State<GenericTabManager<T>> createState() => _GenericTabManagerState<T>();
}

class _GenericTabManagerState<T> extends State<GenericTabManager<T>> {
  /// Search controller - manages the search text input
  final TextEditingController _searchController = TextEditingController();

  /// Current search query
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Listen to search input changes and update UI
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    // Clean up controller to prevent memory leaks
    _searchController.dispose();
    super.dispose();
  }

  /// Handles delete action with confirmation dialog
  Future<void> _handleDelete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Delete Item', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this item?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.config.onDelete(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Item deleted successfully!', style: GoogleFonts.poppins()),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Handles edit navigation
  Future<void> _handleEdit(T item) async {
    final editScreen = widget.config.onEdit(item);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => editScreen),
    );
  }

  /// Calculates grid columns based on screen width (responsive design)
  int _getGridColumns(double width) {
    if (width > 1200) return 4;
    else if (width > 900) return 3;
    else if (width > 600) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Modern Search Bar
          _buildSearchBar(),

          // Data List/Grid (using MobX Observer)
          Expanded(
            child: Observer(
              builder: (context) {
                // Get data from MobX observable
                final allItems = widget.config.getItems();
                print('🔍 GenericTabManager: Got ${allItems.length} items from store');

                // No data
                if (allItems.isEmpty) {
                  print('⚠️ GenericTabManager: No items found, showing empty state');
                  return _buildEmpty(widget.config.emptyMessage);
                }

                // Filter data based on search query
                final items = widget.config.filterItems(allItems, _query);
                print('🔍 GenericTabManager: After filtering with "$_query", ${items.length} items remaining');

                // No results after filtering
                if (items.isEmpty) {
                  print('⚠️ GenericTabManager: No items after filtering');
                  return _buildEmpty('No results found for "$_query"');
                }

                // Display data
                print('✅ GenericTabManager: Building ${isTablet ? 'grid' : 'list'} with ${items.length} items');
                return isTablet
                    ? _buildGrid(items, size.width)
                    : _buildList(items);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.config.floatingActionButton,
    );
  }

  /// Builds the search bar UI
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            hintText: widget.config.searchHint,
            hintStyle: GoogleFonts.poppins(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 22),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey, size: 20),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  /// Builds grid layout for tablet/desktop
  Widget _buildGrid(List<T> items, double width) {
    final columns = _getGridColumns(width);

    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final id = widget.config.getItemId(item);

        return widget.config.itemBuilder(
          item,
          () => _handleEdit(item),
          () => _handleDelete(id),
        );
      },
    );
  }

  /// Builds list layout for mobile
  Widget _buildList(List<T> items) {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final id = widget.config.getItemId(item);

        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: widget.config.itemBuilder(
            item,
            () => _handleEdit(item),
            () => _handleDelete(id),
          ),
        );
      },
    );
  }

  /// Loading indicator
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text(
            'Loading...',
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  /// Empty state
  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 80, color: Colors.grey.shade300),
          SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// Error state
  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red.shade300),
          SizedBox(height: 16),
          Text(
            'Error loading data',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade700,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// 🎯 CONFIGURATION CLASS
///
/// Contains all the tab-specific logic that differs between tabs.
/// This is the "recipe card" that tells GenericTabManager how to work
/// with your specific data type (Items, Categories, etc.)
class TabConfig<T> {
  /// Function that returns the list of items from MobX observable
  /// Example: () => itemStore.items
  final List<T> Function() getItems;

  /// Function to delete an item by ID
  /// Example: (id) => itemStore.deleteItem(id)
  final Future<void> Function(String id) onDelete;

  /// Function that returns the edit screen for an item
  /// Example: (item) => EdititemScreen(items: item)
  final Widget Function(T item) onEdit;

  /// Function to get the ID from an item
  /// Example: (item) => item.id
  final String Function(T item) getItemId;

  /// Search bar placeholder text
  /// Example: 'Search items...'
  final String searchHint;

  /// Builds the card/tile widget for each item
  /// Receives: item, onEdit callback, onDelete callback
  /// Example: (item, onEdit, onDelete) => ItemCard(item: item, onEdit: onEdit, onDelete: onDelete)
  final Widget Function(T item, VoidCallback onEdit, VoidCallback onDelete) itemBuilder;

  /// Message shown when no items exist
  /// Example: 'No items found'
  final String emptyMessage;

  /// Optional: Floating action button (e.g., Add button)
  final Widget? floatingActionButton;

  /// Function to filter items based on search query
  /// TODO(human): You'll implement this to learn how filtering works!
  final List<T> Function(List<T> items, String query) filterItems;

  TabConfig({
    required this.getItems,
    required this.onDelete,
    required this.onEdit,
    required this.getItemId,
    required this.searchHint,
    required this.itemBuilder,
    required this.emptyMessage,
    required this.filterItems,
    this.floatingActionButton,
  });
}
*/
