import 'package:flutter/material.dart';

import 'package:unipos/data/models/retail/hive_model/sale_model_203.dart';
import 'package:unipos/data/models/retail/hive_model/sale_item_model_204.dart';
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
      final items = await saleItemRepository.getItemsBySaleId(widget.saleId);

      setState(() {
        _sale = sale;
        _saleItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sale: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _processReturn() async {
    if (_sale == null) return;

    // Confirm return
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Return'),
        content: Text(
          _returnType == 'full'
              ? 'Process full return of ₹${_sale!.totalAmount.toStringAsFixed(2)}?'
              : 'Process partial return of ₹${_calculatePartialReturnAmount().toStringAsFixed(2)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Return processed successfully!\nReturn ID: ${returnSaleId.substring(0, 13)}'),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing return: $e'), backgroundColor: Colors.red),
        );
      }
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
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Process Return', style: TextStyle(fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
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
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Original Sale',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Sale ID', _sale!.saleId.substring(0, 13).toUpperCase()),
          _buildInfoRow('Total Items', '${_sale!.totalItems}'),
          _buildInfoRow('Total Amount', '₹${_sale!.totalAmount.toStringAsFixed(2)}'),
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
          Text(label, style: const TextStyle(color: Color(0xFF6B6B6B))),
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
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Return Type',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Full Return'),
                  subtitle: const Text('Return all items'),
                  value: 'full',
                  groupValue: _returnType,
                  onChanged: (value) => setState(() {
                    _returnType = value!;
                    _selectedItems.clear();
                  }),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Partial Return'),
                  subtitle: const Text('Select items'),
                  value: 'partial',
                  groupValue: _returnType,
                  onChanged: (value) => setState(() => _returnType = value!),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
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
        border: Border.all(color: const Color(0xFFE8E8E8)),
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
        border: Border.all(color: const Color(0xFFE8E8E8)),
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
        color: isSelected ? const Color(0xFFFFF3E0) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.orange : const Color(0xFFE8E8E8),
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
                    if (item.size != null || item.color != null)
                      Text(
                        '${item.size ?? ''} ${item.color ?? ''}'.trim(),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
                      ),
                  ],
                ),
              ),
              Text(
                '₹${item.total.toStringAsFixed(2)}',
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
          colors: [Colors.red, Color(0xFFD32F2F)],
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
            '₹${returnAmount.toStringAsFixed(2)}',
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
            color: Colors.black.withOpacity(0.1),
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