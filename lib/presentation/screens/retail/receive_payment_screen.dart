import 'package:flutter/material.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:google_fonts/google_fonts.dart';
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
          SizedBox(width: AppResponsive.smallSpacing(context)),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(width: AppResponsive.smallSpacing(context)),
          Text(
            value,
            maxLines: 1,
            style: GoogleFonts.poppins(
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
      backgroundColor: AppColors.surfaceLight,
      // buildPrimaryAppBar like every other screen in this flow. This was a
      // raw white AppBar with an unstyled title, so it was the only
      // primary-less header in the purchase/return tree.
      appBar: buildPrimaryAppBar(title: 'Receive Payment'),
      // Every price on this screen goes through formatMoney; MoneyScope is the
      // one subscription that re-renders them when the store's currency or
      // decimal precision changes.
      body: MoneyScope(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: AppResponsive.padding(context),
                child: AppResponsive.constrainedContent(
                  context: context,
                  alignment: Alignment.topCenter,
                  maxWidth: AppResponsive.maxCardWidth(context),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Info Card
                        _buildCustomerInfoCard(),
                        SizedBox(height: AppResponsive.largeSpacing(context)),

                        // Outstanding Balance Card
                        _buildOutstandingCard(),
                        SizedBox(height: AppResponsive.largeSpacing(context)),

                        // Due Invoices List
                        if (_dueInvoices.isNotEmpty) ...[
                          _buildSectionTitle(
                            'Due Invoices (${_dueInvoices.length})',
                          ),
                          SizedBox(height: AppResponsive.smallSpacing(context)),
                          _buildDueInvoicesList(),
                          SizedBox(height: AppResponsive.largeSpacing(context)),
                        ],

                        // Payment Form
                        _buildSectionTitle('Payment Details'),
                        SizedBox(height: AppResponsive.mediumSpacing(context)),
                        _buildPaymentForm(),
                        SizedBox(
                          height: AppResponsive.extraLargeSpacing(context),
                        ),

                        // Receive Payment Button
                        SizedBox(
                          width: double.infinity,
                          height: AppResponsive.buttonHeight(context),
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
                                : Icon(Icons.payment),
                            label: Text(
                              _isProcessing
                                  ? 'Processing...'
                                  : 'Receive Payment',
                              style: GoogleFonts.poppins(
                                fontSize: AppResponsive.subheadingFontSize(
                                  context,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppResponsive.smallBorderRadius(context),
                                ),
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
      style: GoogleFonts.poppins(
        fontSize: AppResponsive.subheadingFontSize(context),
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    return Container(
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.smallBorderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: AppResponsive.avatarSize(context),
            height: AppResponsive.avatarSize(context),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              // smallBorderRadius, like the other avatar tiles in retail. A
              // fixed 24 stopped being circular once avatarSize reached 56 on
              // desktop, so it rendered as a squircle there and a circle below.
              borderRadius: BorderRadius.circular(
                AppResponsive.smallBorderRadius(context),
              ),
            ),
            child: Icon(Icons.person, color: AppColors.success),
          ),
          SizedBox(width: AppResponsive.mediumSpacing(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.customer.name ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  widget.customer.phone ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    color: AppColors.textSecondary,
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
      padding: AppResponsive.padding(context),
      decoration: BoxDecoration(
        color: _totalDue > 0
            ? const Color(0xFFFFEBEE)
            : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(
          AppResponsive.smallBorderRadius(context),
        ),
        border: Border.all(
          color: _totalDue > 0
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.green.withValues(alpha: 0.3),
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
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                formatMoney(_totalDue),
                style: GoogleFonts.poppins(
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
              icon: Icon(
                Icons.check_circle_outline,
                size: AppResponsive.smallIconSize(context),
              ),
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
        borderRadius: BorderRadius.circular(
          AppResponsive.smallBorderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
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
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
              ),
              child: Icon(
                Icons.receipt_long,
                color: AppColors.warning,
                size: AppResponsive.iconSize(context),
              ),
            ),
            title: Text(
              invoice.displayNumber,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              dateStr,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(invoice.dueAmount),
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                Text(
                  'of ${formatMoney(invoice.totalAmount)}',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.captionFontSize(context),
                    color: AppColors.textSecondary,
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
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.smallBorderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amount Field
          Text(
            'Amount',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.subheadingFontSize(context),
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              prefixText: '${CurrencyHelper.currentSymbol} ',
              hintText: '0.00',
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
                borderSide: const BorderSide(
                  color: AppColors.success,
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
          SizedBox(height: AppResponsive.largeSpacing(context)),

          // Payment Mode
          Text(
            'Payment Mode',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Row(
            children: [
              _buildPaymentModeChip('cash', 'Cash', Icons.money),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              _buildPaymentModeChip('upi', 'UPI', Icons.qr_code_2),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              _buildPaymentModeChip('card', 'Card', Icons.credit_card),
            ],
          ),
          SizedBox(height: AppResponsive.largeSpacing(context)),

          // Reference ID (for UPI/Card)
          if (_selectedMode != 'cash') ...[
            Text(
              'Reference ID (Optional)',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            TextFormField(
              controller: _referenceController,
              decoration: InputDecoration(
                hintText: 'Transaction ID',
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppResponsive.smallBorderRadius(context),
                  ),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppResponsive.smallBorderRadius(context),
                  ),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
              ),
            ),
            SizedBox(height: AppResponsive.largeSpacing(context)),
          ],

          // Note
          Text(
            'Note (Optional)',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.bodyFontSize(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          TextFormField(
            controller: _noteController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Add a note...',
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppResponsive.smallBorderRadius(context),
                ),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
            ),
          ),

          // Live calculation
          if (_amountController.text.isNotEmpty) ...[
            SizedBox(height: AppResponsive.largeSpacing(context)),
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
          padding: EdgeInsets.symmetric(
            vertical: AppResponsive.mediumSpacing(context),
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.success : Colors.white,
            borderRadius: BorderRadius.circular(
              AppResponsive.smallBorderRadius(context),
            ),
            border: Border.all(
              color: isSelected ? AppColors.success : AppColors.divider,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: AppResponsive.smallIconSize(context),
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
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
      padding: EdgeInsets.all(AppResponsive.mediumSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.surfaceMedium,
        borderRadius: BorderRadius.circular(
          AppResponsive.smallBorderRadius(context),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Due',
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
              Text(formatMoney(_totalDue)),
            ],
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment',
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
              Text(
                '- ${formatMoney(enteredAmount)}',
                style: GoogleFonts.poppins(color: AppColors.success),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Remaining After',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              Text(
                formatMoney(remainingAfter),
                style: GoogleFonts.poppins(
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
