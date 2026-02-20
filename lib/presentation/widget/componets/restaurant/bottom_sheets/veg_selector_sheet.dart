import 'package:flutter/material.dart';

/// Bottom sheet for selecting Veg/Non-Veg category
class VegSelectorSheet extends StatelessWidget {
  final String currentSelection;
  final Function(String) onSelected;

  const VegSelectorSheet({
    super.key,
    required this.currentSelection,
    required this.onSelected,
  });

  /// Show the veg selector bottom sheet and return selected value
  static Future<String?> show(BuildContext context, {required String currentSelection}) async {
    String? result;

    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return VegSelectorSheet(
          currentSelection: currentSelection,
          onSelected: (value) {
            result = value;
            Navigator.pop(context);
          },
        );
      },
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        const Divider(),
        _buildOption(
          label: 'Veg',
          color: Colors.green,
          isSelected: currentSelection == 'Veg',
          onTap: () => onSelected('Veg'),
        ),
        _buildOption(
          label: 'Non-Veg',
          color: Colors.red,
          isSelected: currentSelection == 'Non-Veg',
          onTap: () => onSelected('Non-Veg'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildOption({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(Icons.circle, color: color),
      title: Text(label),
      trailing: isSelected ? Icon(Icons.check, color: color) : null,
      onTap: onTap,
    );
  }
}

/// Veg/Non-Veg selector button widget (displays current selection)
class VegSelectorButton extends StatelessWidget {
  final String selectedCategory;
  final VoidCallback onTap;

  const VegSelectorButton({
    super.key,
    required this.selectedCategory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  color: selectedCategory == 'Veg' ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(selectedCategory),
              ],
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }
}
