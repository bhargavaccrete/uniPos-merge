import 'package:flutter/material.dart';
import 'package:billberrylite/util/common/short_ref.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';

import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_item_model_204.dart';
import '../../../core/di/service_locator.dart';
import '../../../domain/services/retail/return_service.dart';

class SaleReturnScreen extends StatefulWidget {
  final String saleId;

  const SaleReturnScreen({
    super.key,
    required this.saleId,
  });

  @override
  State<SaleReturnScreen> createState() => _SaleReturnScreenState();
}

class _SaleReturnScreenState extends State<SaleReturnScreen> {
  final ReturnService _returnService = ReturnService();

  SaleModel? _sale;
  List<SaleItemModel> _saleItems = [];
  bool _isLoading = true;
  bool _isProcessing = false;

  // For partial return
  final Map<String, int> _selectedItems = {}; // variantId -> quantity to return

  String _refundMethod = 'cash';
  String _returnType = 'full'; // full or partial

  @override
  void initState() {
    super.initState();
    _loadSaleData();
  }

  Future<void> _loadSaleData() async {
    setState(() => _isLoading = true);

    try {
      final sale = await saleStore.getSaleById(widget.saleId);
      final items = await saleStore.getItemsForSale(widget.saleId);

      setState(() {
        _sale = sale;
        _saleItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        NotificationService.instance.showError('Error loading sale: $e');
      }
    }
  }

  Future<void> _processReturn() async {
    if (_sale == null) return;

    final isFull = _returnType == 'full';
    final refundAmount =
        isFull ? _sale!.totalAmount : _calculatePartialReturnAmount();

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: isFull ? 'Return whole sale?' : 'Return selected items?',
      message: 'Refund ${formatMoney(refundAmount)} via '
          '${_refundMethod.toUpperCase()}. Stock goes back in and the sale is '
          'marked returned. This cannot be undone.',
      confirmLabel: 'Confirm Return',
      accent: AppColors.danger,
      icon: Icons.assignment_return_rounded,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      String returnSaleId;

      if (_returnType == 'full') {
        returnSaleId = await _returnService.processFullReturn(
          originalSaleId: widget.saleId,
          refundMethod: _refundMethod,
        );
      } else {
        if (_selectedItems.isEmpty) {
          throw Exception('Please select items to return');
        }

        returnSaleId = await _returnService.processPartialReturn(
          originalSaleId: widget.saleId,
          itemsToReturn: _selectedItems,
          refundMethod: _refundMethod,
        );
      }

      if (mounted) {
        Navigator.pop(context, true); // Return to previous screen
        NotificationService.instance
            .showSuccess('Return processed • ${shortRef(returnSaleId, length: 13)}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      NotificationService.instance.showError('Error processing return: $e');
    }
  }


  double _calculatePartialReturnAmount() {
    double total = 0;
    for (var entry in _selectedItems.entries) {
      final variantId = entry.key;
      final returnQty = entry.value;

      final item = _saleItems.firstWhere((i) => i.varianteId == variantId);
      final itemSubtotal = item.price * returnQty;
      final itemDiscount = (item.discountAmount ?? 0) * (returnQty / item.qty);
      final itemTax = (item.taxAmount ?? 0) * (returnQty / item.qty);

      total += (itemSubtotal - itemDiscount + itemTax);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Process Return',
        titleFontSize: 18,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sale == null
              ? _buildErrorView()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildOriginalSaleCard(),
                      _buildReturnTypeSelector(),
                      _buildRefundMethodSelector(),
                      if (_returnType == 'partial') _buildItemsList(),
                      _buildSummaryCard(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
      bottomNavigationBar: _sale != null && !_isLoading
          ? _buildProcessButton()
          : null,
    );
  }

  Widget _buildErrorView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text('Sale not found or cannot be returned'),
        ],
      ),
    );
  }

  Widget _buildOriginalSaleCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Original Sale',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Sale ID', shortRef(_sale!.saleId, length: 13)),
          _buildInfoRow('Total Items', '${_sale!.totalItems}'),
          _buildInfoRow('Total Amount', formatMoney(_sale!.totalAmount)),
          _buildInfoRow('Payment Type', _sale!.paymentType.toUpperCase()),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildReturnTypeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Return Type',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          // Selectable tiles rather than RadioListTile — Flutter deprecated
          // Radio's groupValue/onChanged in favour of a RadioGroup ancestor,
          // and these match the tiles used in Material Receiving.
          Row(
            children: [
              Expanded(
                child: _returnTypeTile(
                  value: 'full',
                  label: 'Full Return',
                  caption: 'Return all items',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _returnTypeTile(
                  value: 'partial',
                  label: 'Partial Return',
                  caption: 'Select items',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _returnTypeTile({
    required String value,
    required String label,
    required String caption,
  }) {
    final selected = _returnType == value;

    return InkWell(
      onTap: () => setState(() {
        _returnType = value;
        // Switching back to a full return clears any partial picks, so the
        // refund total can't be computed from a stale selection.
        if (value == 'full') _selectedItems.clear();
      }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    caption,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefundMethodSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Refund Method',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('💵 Cash'),
                selected: _refundMethod == 'cash',
                onSelected: (selected) => setState(() => _refundMethod = 'cash'),
              ),
              ChoiceChip(
                label: const Text('💳 Card'),
                selected: _refundMethod == 'card',
                onSelected: (selected) => setState(() => _refundMethod = 'card'),
              ),
              ChoiceChip(
                label: const Text('📱 UPI'),
                selected: _refundMethod == 'upi',
                onSelected: (selected) => setState(() => _refundMethod = 'upi'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Items to Return',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ..._saleItems.map((item) => _buildItemTile(item)),
        ],
      ),
    );
  }

  Widget _buildItemTile(SaleItemModel item) {
    final isSelected = _selectedItems.containsKey(item.varianteId);
    final returnQty = _selectedItems[item.varianteId] ?? 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.warning.withValues(alpha: 0.1) : AppColors.surfaceMedium,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.orange : AppColors.divider,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedItems[item.varianteId] = 1;
                    } else {
                      _selectedItems.remove(item.varianteId);
                    }
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (attributeStore
                        .describeAttributes(item.attributes,
                            size: item.size, color: item.color, labelled: false)
                        .isNotEmpty)
                      Text(
                        attributeStore.describeAttributes(item.attributes,
                            size: item.size, color: item.color, labelled: false),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Text(
                formatMoney(item.total),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (isSelected) ...[
            const Divider(height: 16),
            Row(
              children: [
                const Text('Quantity: '),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: returnQty > 1
                      ? () => setState(() => _selectedItems[item.varianteId] = returnQty - 1)
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                Text(
                  '$returnQty / ${item.qty}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: returnQty < item.qty
                      ? () => setState(() => _selectedItems[item.varianteId] = returnQty + 1)
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final returnAmount = _returnType == 'full'
        ? _sale!.totalAmount
        : _calculatePartialReturnAmount();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.red, AppColors.danger],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            'Refund Amount',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(returnAmount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_returnType == 'partial') ...[
            const SizedBox(height: 8),
            Text(
              '${_selectedItems.values.fold(0, (sum, qty) => sum + qty)} items selected',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProcessButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processReturn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          minimumSize: const Size(double.infinity, 50),
        ),
        child: _isProcessing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'Process Return',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}