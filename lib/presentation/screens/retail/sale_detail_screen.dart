import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/di/service_locator.dart';
import '../../../domain/services/restaurant/notification_service.dart';
import 'package:unipos/data/models/retail/hive_model/sale_model_203.dart';
import 'package:unipos/data/models/retail/hive_model/sale_item_model_204.dart';
import 'package:unipos/data/models/retail/hive_model/customer_model_208.dart';
import 'package:unipos/presentation/screens/retail/sale_return_screen.dart';
import 'package:unipos/domain/services/retail/print_service.dart';
import 'package:unipos/domain/services/retail/store_settings_service.dart';
class SaleDetailScreen extends StatefulWidget {
  final String saleId;

  const SaleDetailScreen({
    super.key,
    required this.saleId,
  });

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  SaleModel? _sale;
  List<SaleItemModel> _saleItems = [];
  CustomerModel? _customer;
  bool _isLoading = true;
  bool _hasBeenRefunded = false;

  @override
  void initState() {
    super.initState();
    _loadSaleData();
  }

  Future<void> _loadSaleData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load sale header
      final sale = await saleStore.getSaleById(widget.saleId);

      // Load sale items
      final items = await saleItemRepository.getItemsBySaleId(widget.saleId);

      // Load customer if exists
      CustomerModel? customer;
      if (sale?.customerId != null) {
        customer = await customerStoreRestail.getCustomerById(sale!.customerId!);
      }

      // Check if this sale has been refunded (look for return transactions)
      bool hasRefund = false;
      if (sale != null) {
        final allSales = await saleStore.getAllSales();
        hasRefund = allSales.any((s) =>
          (s.isReturn ?? false) && s.originalSaleId == widget.saleId
        );
      }

      setState(() {
        _sale = sale;
        _saleItems = items;
        _customer = customer;
        _hasBeenRefunded = hasRefund;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        NotificationService.instance.showError('Error loading sale: $e');
      }
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (e) {
      return isoDate;
    }
  }

  Future<void> _printBill() async {
    if (_sale == null || _saleItems.isEmpty) return;

    try {
      // Get store details
      final storeSettingsService = StoreSettingsService();
      final storeName = await storeSettingsService.getStoreName();
      final storeAddress = await storeSettingsService.getFormattedAddress();
      final storePhone = await storeSettingsService.getStorePhone();
      final storeEmail = await storeSettingsService.getStoreEmail();
      final gstNumber = await storeSettingsService.getGSTNumber();

      // Show print options dialog
      final printService = PrintService();
      await printService.showPrintOptionsDialog(
        context: context,
        sale: _sale!,
        items: _saleItems,
        customer: _customer,
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        storeEmail: storeEmail,
        gstNumber: gstNumber,
      );
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error printing: $e');
      }
    }
  }

  String _getPaymentIcon(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'cash':
        return '💵';
      case 'card':
        return '💳';
      case 'upi':
        return '📱';
      default:
        return '💰';
    }
  }

  Color _getPaymentColor(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'cash':
        return const Color(0xFF4CAF50);
      case 'card':
        return const Color(0xFF2196F3);
      case 'upi':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF6B6B6B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text(
          'Sale Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // TODO: Implement share functionality
              NotificationService.instance.showSuccess('Share feature coming soon');
            },
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: _isLoading || _sale == null ? null : _printBill,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sale == null
              ? _buildErrorView()
              : _buildSaleDetail(),

      bottomNavigationBar: _sale != null && !(_sale!.isReturn ?? false) && !_hasBeenRefunded && !_isLoading
          ? _buildReturnButton()
          : null,
    );
  }

  Widget _buildReturnButton() {
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
      child: ElevatedButton.icon(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SaleReturnScreen(saleId: widget.saleId),
            ),
          );

          if (result == true && mounted) {
            Navigator.pop(context, true); // Go back to sales history
          }
        },
        icon: const Icon(Icons.keyboard_return),
        label: const Text('Process Return/Refund', style: TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          minimumSize: const Size(double.infinity, 50),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Color(0xFFD0D0D0),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sale not found',
            style: TextStyle(fontSize: 16, color: Color(0xFF6B6B6B)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleDetail() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Sale Header Card
          _buildSaleHeaderCard(),

          // Sale Items List
          _buildSaleItemsList(),

          // Summary Card
          _buildSummaryCard(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSaleHeaderCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getPaymentColor(_sale!.paymentType),
            _getPaymentColor(_sale!.paymentType).withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _getPaymentColor(_sale!.paymentType).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Refund Status Banner
          if (_hasBeenRefunded) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.keyboard_return,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'REFUNDED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Full Return',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sale ID',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _sale!.saleId.substring(0, 13).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(
                      _getPaymentIcon(_sale!.paymentType),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _sale!.paymentType.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                _formatDate(_sale!.date),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                '${_sale!.totalItems} items',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (_customer != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_customer!.name} (${_customer!.phone})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaleItemsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Items Sold',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_saleItems.length} products',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE8E8E8)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _saleItems.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              thickness: 0.5,
              color: Color(0xFFE8E8E8),
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final item = _saleItems[index];
              return _buildSaleItemTile(item, index + 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaleItemTile(SaleItemModel item, int itemNumber) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item Number Badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$itemNumber',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName ?? 'Unknown Product',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (item.size != null)
                          _buildPropertyChip('Size: ${item.size}'),
                        if (item.color != null)
                          _buildPropertyChip('Color: ${item.color}'),
                        if (item.barcode != null)
                          _buildPropertyChip('📦 ${item.barcode}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Price Breakdown
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _buildPriceRow(
                  '${item.qty} × ₹${item.price.toStringAsFixed(2)}',
                  '₹${(item.qty * item.price).toStringAsFixed(2)}',
                  isBold: false,
                ),
                if (item.discountAmount != null && item.discountAmount! > 0) ...[
                  const SizedBox(height: 6),
                  _buildPriceRow(
                    'Discount',
                    '- ₹${item.discountAmount!.toStringAsFixed(2)}',
                    color: Colors.red,
                    isBold: false,
                  ),
                ],
                if (item.taxAmount != null && item.taxAmount! > 0) ...[
                  const SizedBox(height: 6),
                  _buildPriceRow(
                    'Tax',
                    '+ ₹${item.taxAmount!.toStringAsFixed(2)}',
                    color: const Color(0xFF4CAF50),
                    isBold: false,
                  ),
                ],
                const Divider(height: 16, thickness: 0.5),
                _buildPriceRow(
                  'Item Total',
                  '₹${item.total.toStringAsFixed(2)}',
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF6B6B6B),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          _buildPriceRow(
            'Subtotal',
            '₹${_sale!.subtotal.toStringAsFixed(2)}',
            isBold: false,
          ),
          const SizedBox(height: 12),
          _buildPriceRow(
            'Discount',
            '- ₹${_sale!.discountAmount.toStringAsFixed(2)}',
            color: Colors.red,
            isBold: false,
          ),
          const SizedBox(height: 12),
          _buildPriceRow(
            'Tax',
            '+ ₹${_sale!.taxAmount.toStringAsFixed(2)}',
            color: const Color(0xFF4CAF50),
            isBold: false,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 0.5, color: Color(0xFFE8E8E8)),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF4CAF50).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: _buildPriceRow(
              'Grand Total',
              '₹${_sale!.totalAmount.toStringAsFixed(2)}',
              isBold: true,
              fontSize: 20,
            ),
          ),
          // Split Payment Breakdown
          _buildSplitPaymentBreakdown(),
        ],
      ),
    );
  }

  Widget _buildSplitPaymentBreakdown() {
    final paymentList = _sale!.paymentList;

    // Only show if there are multiple payment methods or it's marked as split payment
    if (paymentList.length <= 1 && _sale!.isSplitPayment != true) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF2196F3).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.payment,
                    size: 18,
                    color: const Color(0xFF2196F3),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Split Payment Breakdown',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...paymentList.map((payment) {
                final method = (payment['method'] as String?)?.toUpperCase() ?? 'OTHER';
                final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
                final ref = payment['ref'] as String?;
                final received = (payment['received'] as num?)?.toDouble();
                final change = (payment['change'] as num?)?.toDouble();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _getPaymentMethodColor(method).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                _getPaymentMethodIcon(method),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  method,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                if (ref != null && ref.isNotEmpty)
                                  Text(
                                    'Ref: $ref',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B6B6B),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      // Show cash received and change for cash payments
                      if (method == 'CASH' && received != null && received > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          margin: const EdgeInsets.only(left: 44),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Cash Received',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
                                  ),
                                  Text(
                                    '₹${received.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              if (change != null && change > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Change Given',
                                      style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '₹${change.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              // Show total paid and change if any
              if (_sale!.totalPaid != null && _sale!.totalPaid! > _sale!.totalAmount) ...[
                const Divider(height: 16, thickness: 0.5),
                _buildPriceRow(
                  'Total Paid',
                  '₹${_sale!.totalPaid!.toStringAsFixed(2)}',
                  isBold: true,
                ),
              ],
              if (_sale!.changeReturn != null && _sale!.changeReturn! > 0) ...[
                const SizedBox(height: 8),
                _buildPriceRow(
                  'Change Returned',
                  '₹${_sale!.changeReturn!.toStringAsFixed(2)}',
                  color: Colors.orange,
                  isBold: true,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return '💵';
      case 'card':
        return '💳';
      case 'upi':
        return '📱';
      case 'wallet':
        return '👛';
      case 'credit':
        return '📝';
      default:
        return '💰';
    }
  }

  Color _getPaymentMethodColor(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return const Color(0xFF4CAF50);
      case 'card':
        return const Color(0xFF2196F3);
      case 'upi':
        return const Color(0xFF9C27B0);
      case 'wallet':
        return const Color(0xFFFF9800);
      case 'credit':
        return const Color(0xFFE91E63);
      default:
        return const Color(0xFF6B6B6B);
    }
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    bool isBold = true,
    double? fontSize,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize ?? 14,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: color ?? const Color(0xFF6B6B6B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize ?? 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}