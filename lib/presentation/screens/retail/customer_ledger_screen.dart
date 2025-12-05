import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:unipos/domain/store/retail/credit_store.dart';

import '../../../core/di/service_locator.dart';
import '../../../data/models/retail/hive_model/customer_model_208.dart';



/// Customer Ledger Screen - Timeline view of customer transactions
class CustomerLedgerScreen extends StatefulWidget {
  final CustomerModel customer;

  const CustomerLedgerScreen({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  bool _isLoading = true;
  List<LedgerEntry> _entries = [];
  DateTimeRange? _dateFilter;

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    try {
      final entries = await creditStore.getCustomerLedger(widget.customer.customerId);
      setState(() => _entries = entries);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<LedgerEntry> get _filteredEntries {
    if (_dateFilter == null) return _entries;

    return _entries.where((entry) {
      final entryDate = DateTime.tryParse(entry.date);
      if (entryDate == null) return true;
      return entryDate.isAfter(_dateFilter!.start.subtract(const Duration(days: 1))) &&
          entryDate.isBefore(_dateFilter!.end.add(const Duration(days: 1)));
    }).toList();
  }

  Future<void> _selectDateRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateFilter,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4CAF50),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      setState(() => _dateFilter = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Customer Ledger'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_alt_outlined,
              color: _dateFilter != null ? const Color(0xFF4CAF50) : null,
            ),
            onPressed: _selectDateRange,
          ),
          if (_dateFilter != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => _dateFilter = null),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Customer Summary Card
                _buildCustomerSummary(),

                // Filter Info
                if (_dateFilter != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFFE3F2FD),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF1976D2)),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('dd/MM/yy').format(_dateFilter!.start)} - ${DateFormat('dd/MM/yy').format(_dateFilter!.end)}',
                          style: const TextStyle(color: Color(0xFF1976D2), fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                // Ledger Timeline
                Expanded(
                  child: _filteredEntries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No transactions found',
                                style: TextStyle(color: Color(0xFF6B6B6B)),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadLedger,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredEntries.length,
                            itemBuilder: (context, index) {
                              final entry = _filteredEntries[index];
                              return _buildLedgerEntry(entry, dateFormat, index == 0);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCustomerSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF4CAF50).withOpacity(0.1),
                child: Text(
                  widget.customer.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.customer.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      widget.customer.phone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total Purchase',
                '₹${widget.customer.totalPurchaseAmount.toStringAsFixed(0)}',
                Colors.blue,
              ),
              _buildStatItem(
                'Outstanding',
                '₹${widget.customer.creditBalance.toStringAsFixed(0)}',
                widget.customer.creditBalance > 0 ? Colors.red : Colors.green,
              ),
              _buildStatItem(
                'Visits',
                widget.customer.visitCount.toString(),
                Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B6B6B),
          ),
        ),
      ],
    );
  }

  Widget _buildLedgerEntry(LedgerEntry entry, DateFormat dateFormat, bool isFirst) {
    final entryDate = DateTime.tryParse(entry.date);
    final dateStr = entryDate != null ? dateFormat.format(entryDate) : entry.date;

    // Determine colors and icons based on entry type
    Color iconColor;
    IconData icon;
    Color amountColor;
    String amountPrefix;

    switch (entry.type) {
      case LedgerEntryType.creditSale:
        iconColor = const Color(0xFFFF9800);
        icon = Icons.receipt_long;
        amountColor = Colors.red;
        amountPrefix = '+';
        break;
      case LedgerEntryType.payment:
        iconColor = const Color(0xFF4CAF50);
        icon = Icons.payment;
        amountColor = const Color(0xFF4CAF50);
        amountPrefix = '';
        break;
      case LedgerEntryType.writeOff:
        iconColor = const Color(0xFF9E9E9E);
        icon = Icons.delete_outline;
        amountColor = const Color(0xFF9E9E9E);
        amountPrefix = '';
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline Line
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: iconColor, width: 2),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            if (!isFirst || _filteredEntries.length > 1)
              Container(
                width: 2,
                height: 60,
                color: const Color(0xFFE8E8E8),
              ),
          ],
        ),
        const SizedBox(width: 12),

        // Entry Details
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
                const SizedBox(height: 4),

                // Description
                Text(
                  entry.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),

                // Amount and Balance
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$amountPrefix₹${entry.amount.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: amountColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Bal: ₹${entry.runningBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}