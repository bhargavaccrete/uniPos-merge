// lib/screens/tabbar/weight_item_dialog.dart

import 'package:flutter/material.dart';   // Make sure this path is correct
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';


// Enum to manage which mode is currently active
enum EditMode { amount, quantity, price }

// The function you will call from your MenuScreen
Future<CartItem?> showWeightItemDialog(BuildContext context, Items item) async {
  if (!item.isSoldByWeight) return null;

  return showModalBottomSheet<CartItem>(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => WeightItemDialog(item: item),
  );
}

// The main widget for the dialog content
class WeightItemDialog extends StatefulWidget {
  final Items item;
  const WeightItemDialog({Key? key, required this.item}) : super(key: key);

  @override
  _WeightItemDialogState createState() => _WeightItemDialogState();
}

class _WeightItemDialogState extends State<WeightItemDialog> {
  EditMode _currentMode = EditMode.quantity;

  final TextEditingController _inputController = TextEditingController();

  double _displayWeight = 1.0;
  double _displayAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _displayAmount = widget.item.price ?? 0.0;
    _inputController.text = '1';
    _inputController.addListener(_updateCalculations);
  }

  @override
  void dispose() {
    _inputController.removeListener(_updateCalculations);
    _inputController.dispose();
    super.dispose();
  }

  void _updateCalculations() {
    final textValue = _inputController.text;
    final inputValue = double.tryParse(textValue) ?? 0.0;
    final pricePerUnit = widget.item.price ?? 1.0; // Avoid division by zero

    setState(() {
      switch (_currentMode) {
        case EditMode.amount:
          _displayAmount = inputValue;
          _displayWeight = pricePerUnit > 0 ? inputValue / pricePerUnit : 0;
          break;
        case EditMode.quantity:
          _displayWeight = inputValue;
          _displayAmount = inputValue * pricePerUnit;
          break;
        case EditMode.price:
          _displayAmount = inputValue;
          break;
      }
    });
  }

  void _onNumpadTap(String value) {
    if (value == '⌫') {
      if (_inputController.text.isNotEmpty) {
        _inputController.text = _inputController.text.substring(0, _inputController.text.length - 1);
      }
    } else if (_inputController.text.contains('.') && value == '.') {
      return; // Prevent multiple decimal points
    }
    else if (_inputController.text.length < 7) {
      _inputController.text += value;
    }
  }

  void _changeMode(EditMode newMode) {
    setState(() {
      _currentMode = newMode;
      _inputController.clear();
    });
  }

  String get _getHintText {
    switch (_currentMode) {
      case EditMode.amount: return 'Enter Amount';
      case EditMode.quantity: return 'Enter Quantity';
      case EditMode.price: return 'Enter Final Price';
    }
  }

  String _formatWeightDisplay(double weight, String? unit) {
    String unitStr = unit?.toUpperCase() ?? '';

    // For gram-based units, show without decimals when it's a whole number
    if (unitStr.contains('GM') || unitStr.contains('GRAM')) {
      if (weight == weight.toInt()) {
        return '${weight.toInt()}${unitStr}';
      } else {
        return '${weight.toStringAsFixed(1)}${unitStr}';
      }
    }

    // For kg-based units, show appropriate decimals
    if (unitStr.contains('KG') || unitStr.contains('KILOGRAM')) {
      if (weight < 1) {
        // Convert to grams for small quantities
        double grams = weight * 1000;
        if (grams == grams.toInt()) {
          return '${grams.toInt()}GM';
        } else {
          return '${grams.toStringAsFixed(1)}GM';
        }
      } else {
        return '${weight.toStringAsFixed(weight == weight.toInt() ? 0 : 2)}${unitStr}';
      }
    }

    // For other units, use appropriate decimal places
    if (weight == weight.toInt()) {
      return '${weight.toInt()}${unitStr}';
    } else {
      return '${weight.toStringAsFixed(2)}${unitStr}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDisplaySection(),
          SizedBox(height: 16),
          _buildModeButtons(),
          SizedBox(height: 16),
          TextField(
            controller: _inputController,
            readOnly: true,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: _getHintText,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          SizedBox(height: 16),
          _buildNumpad(),
          SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 40),
              backgroundColor: Color(0xFF1ABC9C),
              foregroundColor: Colors.white,
            ),
            // --- KEY CHANGE IS HERE ---
            onPressed: () {
              if (_displayWeight > 0 && _displayAmount > 0) {
                final cartItem = CartItem(
                  productId: widget.item.id,
                  id: widget.item.id, // Use item ID for proper stock deduction
                  title: widget.item.name,
                  imagePath: widget.item.imagePath ?? '',
                  price: _displayAmount, // The price for the specified weight

                  // Weight items are always 1 line item, actual weight is stored in weightDisplay
                  quantity: 1,
                  taxRate: widget.item.taxRate, // Add tax rate for weight-based items
                  weightDisplay: _formatWeightDisplay(_displayWeight, widget.item.unit),
                );
                Navigator.pop(context, cartItem);
              }
            },
            child: Text('Add Item', style: TextStyle(fontSize: 18)),
          )
        ],
      ),
    );
  }

  // --- Helper build methods for UI components (No changes needed here) ---
  Widget _buildDisplaySection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDisplayItem('Item', widget.item.name),
          _buildDisplayItem('Weight', _formatWeightDisplay(_displayWeight, widget.item.unit)),
          _buildDisplayItem('Amount', 'Rs.${_displayAmount.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildDisplayItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildModeButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(child: _buildModeButton(EditMode.amount, 'Edit Amount')),
        Expanded(child: _buildModeButton(EditMode.quantity, 'Edit Quantity')),
        Expanded(child: _buildModeButton(EditMode.price, 'Edit Price')),
      ],
    );
  }

  Widget _buildModeButton(EditMode mode, String text) {
    bool isSelected = _currentMode == mode;
    return ElevatedButton(
      onPressed: () => _changeMode(mode),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Color(0xFF1ABC9C) : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(text,style: GoogleFonts.poppins(fontSize: 10, ),overflow: TextOverflow.ellipsis,),
    );
  }

  Widget _buildNumpad() {
    final keys = [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['.', '0', '⌫']];
    return Column(
      children: keys.map((row) => Row(
        children: row.map((key) => Expanded(
          child: InkWell(
            onTap: () => _onNumpadTap(key),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(key, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
            ),
          ),
        )).toList(),
      )).toList(),
    );
  }
}