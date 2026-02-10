
import 'package:flutter/material.dart';   // Make sure this path is correct
import 'package:google_fonts/google_fonts.dart';

import '../../../../data/models/restaurant/db/cartmodel_308.dart';
import '../../../../data/models/restaurant/db/itemmodel_302.dart';
import '../../../../domain/services/restaurant/notification_service.dart';
import '../../../../util/color.dart';
import '../../../../util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';

// Enum to manage which mode is currently active
enum EditMode { amount, quantity, price }

// The function you will call from your MenuScreen
Future<CartItem?> showWeightItemDialog(BuildContext context, Items item) async {
  if (!item.isSoldByWeight) return null;

  return showModalBottomSheet<CartItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Weight-based Item',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        // ✅ Show available stock
                        if (widget.item.trackInventory == true)
                          Container(
                            margin: EdgeInsets.only(top: 4),
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: widget.item.stockQuantity > 0
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: widget.item.stockQuantity > 0
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              'Available: ${_formatWeightDisplay(widget.item.stockQuantity, widget.item.unit)}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.item.stockQuantity > 0
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMedium,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildDisplaySection(),
                  SizedBox(height: 20),
                  _buildModeButtons(),
                  SizedBox(height: 20),
                  TextField(
                    controller: _inputController,
                    readOnly: true,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: _getHintText,
                      hintStyle: GoogleFonts.poppins(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                  ),
                  SizedBox(height: 20),
                  _buildNumpad(),
                ],
              ),
            ),

            // Bottom Add Button
            Container(
              padding: EdgeInsets.all(20),
              child: GestureDetector(
                onTap: () {
                  if (_displayWeight > 0 && _displayAmount > 0) {
                    // ✅ VALIDATION: Check stock availability for weight-based items
                    if (widget.item.trackInventory == true) {
                      final availableStock = widget.item.stockQuantity;

                      if (_displayWeight > availableStock) {
                        NotificationService.instance.showError(
                          'Insufficient stock!\n'
                          'You requested: ${_formatWeightDisplay(_displayWeight, widget.item.unit)}\n'
                          'Available: ${_formatWeightDisplay(availableStock, widget.item.unit)}'
                        );
                        return;
                      }
                    }

                    final cartItem = CartItem(
                      productId: widget.item.id,
                      id: widget.item.id,
                      title: widget.item.name,
                      imagePath: '',
                      price: _displayAmount,
                      quantity: 1,
                      taxRate: widget.item.taxRate,
                      weightDisplay: _formatWeightDisplay(_displayWeight, widget.item.unit),
                    );
                    Navigator.pop(context, cartItem);
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Amount',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.white.withOpacity(0.8),
                            ),
                          ),
                          Text(
                            '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_displayAmount)}',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'Add to Cart',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, color: AppColors.white, size: 20),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper build methods for UI components ---
  Widget _buildDisplaySection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDisplayItem(Icons.restaurant_menu, 'Item', widget.item.name),
          Container(width: 1, height: 40, color: AppColors.divider),
          _buildDisplayItem(Icons.scale, 'Weight', _formatWeightDisplay(_displayWeight, widget.item.unit)),
          Container(width: 1, height: 40, color: AppColors.divider),
          _buildDisplayItem(Icons.payments, 'Amount', '${CurrencyHelper.currentSymbol}${DecimalSettings.formatAmount(_displayAmount)}'),
        ],
      ),
    );
  }

  Widget _buildDisplayItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildModeButtons() {
    return Row(
      children: [
        Expanded(child: _buildModeButton(EditMode.amount, Icons.attach_money, 'Amount')),
        SizedBox(width: 8),
        Expanded(child: _buildModeButton(EditMode.quantity, Icons.scale, 'Quantity')),
        SizedBox(width: 8),
        Expanded(child: _buildModeButton(EditMode.price, Icons.payments, 'Price')),
      ],
    );
  }

  Widget _buildModeButton(EditMode mode, IconData icon, String text) {
    bool isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: () => _changeMode(mode),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.white : AppColors.textSecondary,
            ),
            SizedBox(height: 4),
            Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.white : AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', '⌫']
    ];
    return Column(
      children: keys.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: row.map((key) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: InkWell(
                onTap: () => _onNumpadTap(key),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: key == '⌫' ? AppColors.danger.withOpacity(0.1) : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider.withOpacity(0.3)),
                  ),
                  child: key == '⌫'
                      ? Icon(Icons.backspace_outlined, size: 24, color: AppColors.danger)
                      : Text(
                          key,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                ),
              ),
            ),
          )).toList(),
        ),
      )).toList(),
    );
  }
}