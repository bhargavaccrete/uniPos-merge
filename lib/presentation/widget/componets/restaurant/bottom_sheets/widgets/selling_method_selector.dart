import 'package:flutter/material.dart';
import '../add_item_form_state.dart';

/// Widget for selecting selling method (by Unit or by Weight)
class SellingMethodSelector extends StatelessWidget {
  final SellingMethod sellingMethod;
  final String selectedUnit;
  final Function(SellingMethod) onMethodChanged;
  final Function(String) onUnitChanged;

  const SellingMethodSelector({
    super.key,
    required this.sellingMethod,
    required this.selectedUnit,
    required this.onMethodChanged,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Sold by:",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: RadioListTile<SellingMethod>(
                title: const Text('Unit'),
                value: SellingMethod.byUnit,
                groupValue: sellingMethod,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) => onMethodChanged(value!),
              ),
            ),
            Expanded(
              child: RadioListTile<SellingMethod>(
                title: const Text('Weight'),
                value: SellingMethod.byWeight,
                groupValue: sellingMethod,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) => onMethodChanged(value!),
              ),
            ),
          ],
        ),
        if (sellingMethod == SellingMethod.byWeight)
          DropdownButtonFormField<String>(
            value: selectedUnit,
            decoration: const InputDecoration(
              labelText: 'Select Unit',
              border: OutlineInputBorder(),
            ),
            items: ['kg', 'gm', 'lbs', 'litre', 'ml', 'pcs'].map((String unit) {
              return DropdownMenuItem<String>(
                value: unit,
                child: Text(unit),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                onUnitChanged(newValue);
              }
            },
          ),
      ],
    );
  }
}
