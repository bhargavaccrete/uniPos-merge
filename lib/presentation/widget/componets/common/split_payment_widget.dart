import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:uuid/uuid.dart';
import 'package:unipos/core/di/service_locator.dart';
import 'package:unipos/stores/payment_method_store.dart';
import 'package:unipos/util/common/currency_helper.dart';
import 'package:unipos/util/common/decimal_settings.dart';

/// Payment entry for split payment
class PaymentEntry {
  final String id;
  String method;
  double amount; // The bill amount allocated to this payment method
  String? referenceId;
  double cashReceived; // For cash: actual amount received from customer
  double cashChange; // For cash: change to return to customer

  final TextEditingController amountController;
  final TextEditingController referenceController;
  final TextEditingController cashReceivedController;

  PaymentEntry({
    String? id,
    this.method = 'cash',
    this.amount = 0,
    this.referenceId,
    this.cashReceived = 0,
    this.cashChange = 0,
  })  : id = id ?? const Uuid().v4(),
        amountController = TextEditingController(text: amount > 0 ? amount.toStringAsFixed(2) : ''),
        referenceController = TextEditingController(text: referenceId ?? ''),
        cashReceivedController = TextEditingController(text: cashReceived > 0 ? cashReceived.toStringAsFixed(2) : '');

  void dispose() {
    amountController.dispose();
    referenceController.dispose();
    cashReceivedController.dispose();
  }

  /// Check if this is a cash payment
  bool get isCash => method == 'cash';

  /// For cash: the actual amount that goes into the drawer (full received amount)
  double get cashInDrawer => isCash ? cashReceived : amount;

  /// For cash: validate if sufficient amount received
  bool get isCashSufficient => !isCash || cashReceived >= amount;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'method': method,
      'amount': amount,
    };

    if (referenceId != null && referenceId!.isNotEmpty) {
      map['ref'] = referenceId;
    }

    // Add cash-specific fields
    if (isCash && cashReceived > 0) {
      map['received'] = cashReceived;
      map['cashInDrawer'] = cashInDrawer;
      map['change'] = cashChange;
    }

    return map;
  }
}

/// Split Payment Widget for checkout
class SplitPaymentWidget extends StatefulWidget {
  final double billTotal;
  final Function(List<PaymentEntry>, double totalPaid, double change) onPaymentChanged;
  final Function(bool isValid) onValidationChanged;

  const SplitPaymentWidget({
    super.key,
    required this.billTotal,
    required this.onPaymentChanged,
    required this.onValidationChanged,
  });

  @override
  State<SplitPaymentWidget> createState() => _SplitPaymentWidgetState();
}

class _SplitPaymentWidgetState extends State<SplitPaymentWidget> {
  final List<PaymentEntry> _payments = [];
  late PaymentMethodStore _paymentMethodStore;

  // Icon mapping from string names to IconData
  static const Map<String, IconData> _iconMap = {
    'money': Icons.money,
    'credit_card': Icons.credit_card,
    'qr_code_2': Icons.qr_code_2,
    'account_balance_wallet': Icons.account_balance_wallet,
    'receipt_long': Icons.receipt_long,
    'more_horiz': Icons.more_horiz,
    'payment': Icons.payment,
    'account_balance': Icons.account_balance,
    'attach_money': Icons.attach_money,
    'phone_android': Icons.phone_android,
  };

  @override
  void initState() {
    super.initState();
    _paymentMethodStore = locator<PaymentMethodStore>();

    // Initialize payment methods if not already loaded
    if (_paymentMethodStore.paymentMethods.isEmpty) {
      _paymentMethodStore.init();
    }

    // Add initial payment entry with full amount (without notifying parent during build)
    final entry = PaymentEntry(amount: widget.billTotal);
    if (widget.billTotal > 0) {
      entry.amountController.text = widget.billTotal.toStringAsFixed(2);
    }
    _payments.add(entry);

    // Notify parent after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyChanges();
    });
  }

  /// Get icon from string name
  IconData _getIcon(String iconName) {
    return _iconMap[iconName] ?? Icons.payment;
  }

  @override
  void dispose() {
    for (var payment in _payments) {
      payment.dispose();
    }
    super.dispose();
  }

  double get _totalPaid {
    return _payments.fold(0.0, (sum, p) => sum + p.amount);
  }

  double get _remaining {
    return widget.billTotal - _totalPaid;
  }

  double get _change {
    return _totalPaid > widget.billTotal ? _totalPaid - widget.billTotal : 0;
  }

  /// Total change to return from all cash payments
  double get _totalCashChange {
    return _payments.fold(0.0, (sum, p) => sum + (p.isCash ? p.cashChange : 0));
  }

  bool get _isValid {
    if (_payments.isEmpty) return false;
    if (_totalPaid < widget.billTotal) return false;
    for (var payment in _payments) {
      if (payment.amount <= 0) return false;
      // For cash payments in single payment mode, validate that sufficient amount is received
      // For split payments, assume exact amount is received (cash received field is hidden)
      if (_payments.length == 1 && payment.isCash && payment.cashReceived < payment.amount) {
        return false;
      }
    }
    return true;
  }

  /// Check if any cash payment has insufficient amount
  bool get _hasCashInsufficient {
    return _payments.any((p) => p.isCash && p.amount > 0 && p.cashReceived > 0 && p.cashReceived < p.amount);
  }

  void _addPaymentEntry({double initialAmount = 0}) {
    setState(() {
      final entry = PaymentEntry(amount: initialAmount);
      if (initialAmount > 0) {
        entry.amountController.text = initialAmount.toStringAsFixed(2);
      }
      _payments.add(entry);
      _notifyChanges();
    });
  }

  void _removePaymentEntry(int index) {
    if (_payments.length > 1) {
      setState(() {
        _payments[index].dispose();
        _payments.removeAt(index);
        _notifyChanges();
      });
    }
  }

  void _updatePaymentMethod(int index, String method) {
    setState(() {
      _payments[index].method = method;
      _notifyChanges();
    });
  }

  void _updatePaymentAmount(int index, String value) {
    setState(() {
      _payments[index].amount = double.tryParse(value) ?? 0;
      _notifyChanges();
    });
  }

  void _updatePaymentReference(int index, String value) {
    setState(() {
      _payments[index].referenceId = value.isEmpty ? null : value;
      _notifyChanges();
    });
  }

  void _updateCashReceived(int index, String value) {
    setState(() {
      final received = double.tryParse(value) ?? 0;
      _payments[index].cashReceived = received;
      // Auto-calculate change
      final billAmount = _payments[index].amount;
      _payments[index].cashChange = received > billAmount ? received - billAmount : 0;
      _notifyChanges();
    });
  }

  void _fillExactAmount(int index) {
    setState(() {
      final amount = _payments[index].amount;
      _payments[index].cashReceived = amount;
      _payments[index].cashReceivedController.text = amount.toStringAsFixed(2);
      _payments[index].cashChange = 0;
      _notifyChanges();
    });
  }

  void _fillRemaining(int index) {
    if (_remaining > 0) {
      final currentAmount = _payments[index].amount;
      final newAmount = currentAmount + _remaining;
      setState(() {
        _payments[index].amount = newAmount;
        _payments[index].amountController.text = newAmount.toStringAsFixed(2);
        _notifyChanges();
      });
    }
  }

  void _notifyChanges() {
    widget.onPaymentChanged(_payments, _totalPaid, _change);
    widget.onValidationChanged(_isValid);
  }

  bool _needsReference(String method) {
    return method == 'upi' || method == 'card' || method == 'wallet';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bill Total Header
     /*   Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bill Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Text(
                '₹${widget.billTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
        ),*/
        const SizedBox(height: 16),

        // Payment Entries
        ..._payments.asMap().entries.map((entry) {
          final index = entry.key;
          final payment = entry.value;
          return _buildPaymentRow(index, payment);
        }),

        // Add Payment Method Button
        TextButton.icon(
          onPressed: () => _addPaymentEntry(initialAmount: _remaining > 0 ? _remaining : 0),
          icon: const Icon(Icons.add_circle_outline, size: 20),
          label: const Text('Add Payment Method'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4CAF50),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),

        const SizedBox(height: 16),

        // Real-time Calculation Panel
        _buildCalculationPanel(),
      ],
    );
  }

  Widget _buildPaymentRow(int index, PaymentEntry payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Payment Method Dropdown
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                  ),
                  child: Observer(
                    builder: (_) {
                      // Check if store is loading
                      if (_paymentMethodStore.isLoading) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      final enabledMethods = _paymentMethodStore.enabledMethods;

                      // If no enabled methods, show empty state
                      if (enabledMethods.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No payment methods configured',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        );
                      }

                      // Get already selected payment methods (excluding current entry)
                      final selectedMethods = _payments
                          .where((p) => p.id != payment.id)
                          .map((p) => p.method)
                          .toSet();

                      // Filter out already selected methods for other entries
                      final availableMethods = enabledMethods
                          .where((m) => !selectedMethods.contains(m.value) || m.value == payment.method)
                          .toList();

                      // Validate current payment method exists in available methods
                      final currentMethodExists = availableMethods.any((m) => m.value == payment.method);
                      final currentMethod = currentMethodExists ? payment.method : availableMethods.first.value;

                      // Update payment method if it doesn't exist
                      if (!currentMethodExists) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _updatePaymentMethod(index, availableMethods.first.value);
                        });
                      }

                      return DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: currentMethod,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                          items: availableMethods.map((method) {
                            return DropdownMenuItem<String>(
                              value: method.value,
                              child: Row(
                                children: [
                                  Icon(
                                    _getIcon(method.iconName),
                                    size: 18,
                                    color: const Color(0xFF6B6B6B),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    method.name,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              _updatePaymentMethod(index, value);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Amount Input
              Expanded(
                flex: 2,
                child: TextField(
                  controller: payment.amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    prefixText: '${CurrencyHelper.currentSymbol} ',
                    hintText: '0.00',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: _remaining > 0 && payment.amount < widget.billTotal
                        ? IconButton(
                            icon: const Icon(Icons.add_circle, color: Color(0xFF4CAF50), size: 20),
                            tooltip: 'Fill remaining',
                            onPressed: () => _fillRemaining(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        : null,
                  ),
                  onChanged: (value) => _updatePaymentAmount(index, value),
                ),
              ),

              // Delete Button
              if (_payments.length > 1) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _removePaymentEntry(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ],
          ),

          // Reference ID Field (for UPI/Card)
          if (_needsReference(payment.method)) ...[
            const SizedBox(height: 8),
            TextField(
              controller: payment.referenceController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Reference ID (Optional)',
                hintStyle: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1),
                ),
                prefixIcon: const Icon(Icons.tag, size: 18, color: Color(0xFF6B6B6B)),
                filled: true,
                fillColor: const Color(0xFFFAFAFA),
              ),
              onChanged: (value) => _updatePaymentReference(index, value),
            ),
          ],

          // Cash Received Field (for Cash payments - only show for single payment)
          if (payment.isCash && payment.amount > 0 && _payments.length == 1) ...[
            const SizedBox(height: 12),
            _buildCashReceivedSection(index, payment),
          ],
        ],
      ),
    );
  }

  Widget _buildCashReceivedSection(int index, PaymentEntry payment) {
    final isInsufficient = payment.cashReceived > 0 && payment.cashReceived < payment.amount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isInsufficient
            ? Colors.red.withOpacity(0.05)
            : const Color(0xFF4CAF50).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isInsufficient
              ? Colors.red.withOpacity(0.3)
              : const Color(0xFF4CAF50).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bill Amount (readonly)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bill Amount',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B6B6B),
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: DecimalSettings.precisionNotifier,
                builder: (context, precision, child) {
                  final symbol = CurrencyHelper.currentSymbol;
                  final formattedAmount = payment.amount.toStringAsFixed(precision);
                  return Text(
                    '$symbol$formattedAmount',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Cash Received Input
          Row(
            children: [
              const Expanded(
                flex: 2,
                child: Text(
                  'Cash Received',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: payment.cashReceivedController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    prefixText: '${CurrencyHelper.currentSymbol} ',
                    hintText: '0.00',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: isInsufficient ? Colors.red : const Color(0xFFE8E8E8),
                        width: isInsufficient ? 1 : 0.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: isInsufficient ? Colors.red : const Color(0xFFE8E8E8),
                        width: isInsufficient ? 1 : 0.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: isInsufficient ? Colors.red : const Color(0xFF4CAF50),
                        width: 1,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 20),
                      tooltip: 'Fill exact amount',
                      onPressed: () => _fillExactAmount(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  onChanged: (value) => _updateCashReceived(index, value),
                ),
              ),
            ],
          ),

          // Insufficient amount warning
          if (isInsufficient) ...[
            const SizedBox(height: 8),
            ValueListenableBuilder<int>(
              valueListenable: DecimalSettings.precisionNotifier,
              builder: (context, precision, child) {
                final symbol = CurrencyHelper.currentSymbol;
                final shortage = (payment.amount - payment.cashReceived).toStringAsFixed(precision);
                return Row(
                  children: [
                    const Icon(Icons.warning_amber, size: 16, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      'Insufficient! Need $symbol$shortage more',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],

          // Change to Return
          if (payment.cashChange > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.keyboard_return, size: 18, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Change to Return',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: DecimalSettings.precisionNotifier,
                    builder: (context, precision, child) {
                      final symbol = CurrencyHelper.currentSymbol;
                      final formattedChange = payment.cashChange.toStringAsFixed(precision);
                      return Text(
                        '$symbol$formattedChange',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange.shade700,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],

          // Payment complete indicator
          if (payment.cashReceived >= payment.amount && payment.cashReceived > 0) ...[
            const SizedBox(height: 8),
            ValueListenableBuilder<int>(
              valueListenable: DecimalSettings.precisionNotifier,
              builder: (context, precision, child) {
                final symbol = CurrencyHelper.currentSymbol;
                final formattedChange = payment.cashChange.toStringAsFixed(precision);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: const Color(0xFF4CAF50)),
                    const SizedBox(width: 4),
                    Text(
                      payment.cashChange > 0
                          ? 'Cash received - Return change $symbol$formattedChange'
                          : 'Exact amount received',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalculationPanel() {
    final hasError = _totalPaid > 0 && _totalPaid < widget.billTotal;

    return ValueListenableBuilder<int>(
      valueListenable: DecimalSettings.precisionNotifier,
      builder: (context, precision, child) {
        final symbol = CurrencyHelper.currentSymbol;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hasError ? Colors.red.withOpacity(0.05) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasError ? Colors.red.withOpacity(0.3) : const Color(0xFFE8E8E8),
            ),
          ),
          child: Column(
            children: [
              // Total Paid
              _buildCalcRow(
                'Total Paid',
                '$symbol${_totalPaid.toStringAsFixed(precision)}',
                valueColor: _totalPaid >= widget.billTotal ? const Color(0xFF4CAF50) : null,
                isBold: true,
              ),
              const SizedBox(height: 8),

              // Remaining Amount
              if (_remaining > 0) ...[
                _buildCalcRow(
                  'Remaining',
                  '$symbol${_remaining.toStringAsFixed(precision)}',
                  valueColor: Colors.red,
                ),
                const SizedBox(height: 4),
                Text(
                  'Add $symbol${_remaining.toStringAsFixed(precision)} more to complete payment',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ],

              // Change to Return
              if (_change > 0) ...[
                const Divider(height: 16),
                _buildCalcRow(
                  'Change to Return',
                  '$symbol${_change.toStringAsFixed(precision)}',
                  valueColor: Colors.orange,
                  isBold: true,
                  fontSize: 16,
                ),
              ],

              // Validation Status
              if (_isValid) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: const Color(0xFF4CAF50),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Payment complete',
                      style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalcRow(String label, String value, {Color? valueColor, bool isBold = false, double fontSize = 14}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: const Color(0xFF6B6B6B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ?? const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}
