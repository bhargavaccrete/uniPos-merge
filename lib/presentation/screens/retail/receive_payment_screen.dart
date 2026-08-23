import 'package:flutter/material.dart';
import 'package:billberrylite/util/common/short_ref.dart';
import 'package:flutter/services.dart';
import '../../../core/di/service_locator.dart';
import '../../../domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/data/models/common/customer_model_125.dart';
import 'package:billberrylite/data/models/retail/hive_model/sale_model_203.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/money_scope.dart';

/// Receive Payment Screen - Collect due payments from customers
class ReceivePaymentScreen extends StatefulWidget {
  final Customer customer;

  const ReceivePaymentScreen({super.key, required this.customer});

  @override
  State<ReceivePaymentScreen> createState() => _ReceivePaymentScreenState();
}

class _ReceivePaymentScreenState extends State<ReceivePaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedMode = 'cash';
  bool _isLoading = true;
  bool _isProcessing = false;
  List<SaleModel> _dueInvoices = [];
  double _totalDue = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDueInvoices();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadDueInvoices() async {
    setState(() => _isLoading = true);
    try {
      final invoices = await saleStore.getCustomerSalesWithDue(
        widget.customer.customerId,
      );
      final totalDue = await saleStore.getCustomerTotalDue(
        widget.customer.customerId,
      );
      setState(() {
        _dueInvoices = invoices;
        _totalDue = totalDue;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      NotificationService.instance.showError('Please enter a valid amount');
      return;
    }

    if (amount > _totalDue) {
      NotificationService.instance.showError(
        'Amount cannot exceed total due (${formatMoney(_totalDue)})',
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await creditStore.receivePayment(
        customerId: widget.customer.customerId,
        amount: amount,
        paymentMode: _selectedMode,
        referenceId: _referenceController.text.isEmpty
            ? null
            : _referenceController.text,
        note: _noteController.text.isEmpty ? null : _noteController.text,
      );

      if (result.success) {
        // Reload invoices
        await _loadDueInvoices();
        // Reload customer store
        await customerStore.loadCustomers();

        if (mounted) {
          await showDialog(
            context: context,
            builder: (dialogContext) => AppDialogShell(
              title: 'Payment Received',
              subtitle: '${formatMoney(amount)} collected',
              accent: AppColors.success,
              icon: Icons.check_circle,
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (result.closedInvoices?.isNotEmpty == true)
                    _resultLine(
                      context,
                      Icons.task_alt_rounded,
                      'Invoices cleared',
                      '${result.closedInvoices!.length}',
                    ),
                  if (result.partialInvoices?.isNotEmpty == true)
                    _resultLine(
                      context,
                      Icons.hourglass_bottom_rounded,
                      'Partially paid',
                      '${result.partialInvoices!.length}',
                    ),
                  _resultLine(
                    context,
                    Icons.account_balance_wallet_outlined,
                    'Remaining balance',
                    formatMoney(result.remainingDue ?? 0),
                    bold: true,
                  ),
                ],
              ),
              actions: [
                appDialogPrimaryButton(
                  label: 'Done',
                  color: AppColors.success,
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
          );

          // Clear form
          _amountController.clear();
          _referenceController.clear();
          _noteController.clear();
        }
      } else {
        if (mounted) {
          NotificationService.instance.showError(
            result.errorMessage ?? 'Payment failed',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.instance.showError('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Caps content width on large screens so this form doesn't stretch across a
  /// laptop.
  Widget _capped(BuildContext context, Widget child) {
    final maxWidth = AppResponsive.maxCardWidth(context);
    if (maxWidth == double.infinity) return child;
    return Align(
      // topCenter, not Center: Center aligns on BOTH axes, so a
      // shrink-wrapping child floats in the vertical middle.
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  /// One "label — value" line of the payment-received dialog.
  Widget _resultLine(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool bold = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppResponsive.smallIconSize(context),
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Receive Payment'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      // Every price on this screen goes through formatMoney; MoneyScope is the
      // one subscription that re-renders them when the store's currency or
      // decimal precision changes.
      body: MoneyScope(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: AppResponsive.padding(context),
                child: _capped(
                  context,
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Info Card
                        _buildCustomerInfoCard(),
                        const SizedBox(height: 16),

                        // Outstanding Balance Card
                        _buildOutstandingCard(),
                        const SizedBox(height: 16),

                        // Due Invoices List
                        if (_dueInvoices.isNotEmpty) ...[
                          _buildSectionTitle(
                            'Due Invoices (${_dueInvoices.length})',
                          ),
                          const SizedBox(height: 8),
                          _buildDueInvoicesList(),
                          const SizedBox(height: 16),
                        ],

                        // Payment Form
                        _buildSectionTitle('Payment Details'),
                        const SizedBox(height: 12),
                        _buildPaymentForm(),
                        const SizedBox(height: 24),

                        // Receive Payment Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: (_isProcessing || _totalDue <= 0)
                                ? null
                                : _processPayment,
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.payment),
                            label: Text(
                              _isProcessing
                                  ? 'Processing...'
                                  : 'Receive Payment',
                              style: TextStyle(
                                fontSize: AppResponsive.subheadingFontSize(
                                  context,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: AppResponsive.subheadingFontSize(context),
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.person, color: Color(0xFF4CAF50)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.customer.name ?? '',
                  style: TextStyle(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.customer.phone ?? '',
                  style: TextStyle(
                    fontSize: AppResponsive.bodyFontSize(context),
                    color: Color(0xFF6B6B6B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutstandingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _totalDue > 0
            ? const Color(0xFFFFEBEE)
            : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _totalDue > 0
              ? Colors.red.withOpacity(0.3)
              : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Outstanding Balance',
                style: TextStyle(
                  fontSize: AppResponsive.bodyFontSize(context),
                  color: Color(0xFF6B6B6B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatMoney(_totalDue),
                style: TextStyle(
                  fontSize: AppResponsive.getValue(
                    context,
                    mobile: 28.0,
                    tablet: 32.0,
                    desktop: 36.0,
                  ),
                  fontWeight: FontWeight.w700,
                  color: _totalDue > 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          if (_totalDue > 0)
            TextButton.icon(
              onPressed: () {
                _amountController.text = _totalDue.toStringAsFixed(2);
                setState(() {});
              },
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Pay Full'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
        ],
      ),
    );
  }

  Widget _buildDueInvoicesList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        children: _dueInvoices.take(5).map((invoice) {
          final invoiceDate = DateTime.tryParse(invoice.date);
          final dateStr = invoiceDate != null
              ? '${invoiceDate.day}/${invoiceDate.month}/${invoiceDate.year}'
              : 'Unknown';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: Color(0xFFFF9800),
                size: 20,
              ),
            ),
            title: Text(
              'INV-${shortRef(invoice.saleId)}',
              style: TextStyle(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              dateStr,
              style: TextStyle(
                fontSize: AppResponsive.smallFontSize(context),
                color: Color(0xFF9E9E9E),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(invoice.dueAmount),
                  style: TextStyle(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                Text(
                  'of ${formatMoney(invoice.totalAmount)}',
                  style: TextStyle(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amount Field
          Text(
            'Amount',
            style: TextStyle(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: TextStyle(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              prefixText: '${CurrencyHelper.currentSymbol} ',
              hintText: '0.00',
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF4CAF50),
                  width: 2,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter amount';
              }
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0) {
                return 'Please enter valid amount';
              }
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Payment Mode
          Text(
            'Payment Mode',
            style: TextStyle(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPaymentModeChip('cash', 'Cash', Icons.money),
              const SizedBox(width: 8),
              _buildPaymentModeChip('upi', 'UPI', Icons.qr_code_2),
              const SizedBox(width: 8),
              _buildPaymentModeChip('card', 'Card', Icons.credit_card),
            ],
          ),
          const SizedBox(height: 16),

          // Reference ID (for UPI/Card)
          if (_selectedMode != 'cash') ...[
            Text(
              'Reference ID (Optional)',
              style: TextStyle(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _referenceController,
              decoration: InputDecoration(
                hintText: 'Transaction ID',
                filled: true,
                fillColor: const Color(0xFFFAFAFA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Note
          Text(
            'Note (Optional)',
            style: TextStyle(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _noteController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Add a note...',
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
              ),
            ),
          ),

          // Live calculation
          if (_amountController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildPaymentSummary(),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentModeChip(String mode, String label, IconData icon) {
    final isSelected = _selectedMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFE8E8E8),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : const Color(0xFF6B6B6B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF6B6B6B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSummary() {
    final enteredAmount = double.tryParse(_amountController.text) ?? 0;
    final remainingAfter = _totalDue - enteredAmount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Current Due',
                style: TextStyle(color: Color(0xFF6B6B6B)),
              ),
              Text(formatMoney(_totalDue)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Payment', style: TextStyle(color: Color(0xFF6B6B6B))),
              Text(
                '- ${formatMoney(enteredAmount)}',
                style: const TextStyle(color: Color(0xFF4CAF50)),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Remaining After',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                formatMoney(remainingAfter),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: remainingAfter > 0 ? Colors.orange : Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
