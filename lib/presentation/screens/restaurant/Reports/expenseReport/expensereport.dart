import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unipos/constants/restaurant/color.dart';
import 'package:unipos/data/models/restaurant/db/expensel_316.dart';

import '../../../../../core/di/service_locator.dart';

enum TimePeriod { Today, Month, Year, Custom }

class ExpenseReport extends StatefulWidget {
  const ExpenseReport({super.key});

  @override
  State<ExpenseReport> createState() => _ExpenseReportState();
}

class _ExpenseReportState extends State<ExpenseReport> {
  TimePeriod _selectedPeriod = TimePeriod.Today;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primarycolor,
        title: Text(
          "Expense Report",
          style: GoogleFonts.poppins(
              fontSize: 20, color: Colors.white, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _filterButton(TimePeriod.Today, 'Today'),
                      const SizedBox(width: 10),
                      _filterButton(TimePeriod.Month, 'Month Wise'),
                      const SizedBox(width: 10),
                      _filterButton(TimePeriod.Year, 'Year Wise'),
                      const SizedBox(width: 10),
                      _filterButton(TimePeriod.Custom, 'Custom'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ExpenseDataView(
                  key: ValueKey(_selectedPeriod),
                  period: _selectedPeriod,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterButton(TimePeriod period, String title) {
    bool isSelected = _selectedPeriod == period;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? primarycolor : Colors.grey.shade300,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
    );
  }
}

class ExpenseDataView extends StatefulWidget {
  final TimePeriod period;
  const ExpenseDataView({super.key, required this.period});

  @override
  State<ExpenseDataView> createState() => _ExpenseDataViewState();
}

class _ExpenseDataViewState extends State<ExpenseDataView> {
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  List<Expense> _expenses = [];
  Map<String, String> _categoryNames = {}; // Map of category ID to name
  bool _isLoading = true;
  double _totalExpenses = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCategoriesAndExpenses();
  }

  Future<void> _loadCategoriesAndExpenses() async {
    setState(() => _isLoading = true);

    try {
      // First, load all expense categories to map IDs to names
      final categories = expenseStore.categories.toList();
      final categoryMap = <String, String>{};
      for (var category in categories) {
        categoryMap[category.id] = category.name;
      }

      setState(() {
        _categoryNames = categoryMap;
      });

      // Then load expenses
      await _loadExpenses();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
    }
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);

    try {
      final allExpenses = expenseStore.expenses.toList();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      List<Expense> filtered = [];

      switch (widget.period) {
        case TimePeriod.Today:
          filtered = allExpenses.where((expense) {
            final expenseDate = DateTime(
              expense.dateandTime.year,
              expense.dateandTime.month,
              expense.dateandTime.day,
            );
            return expenseDate.isAtSameMomentAs(today);
          }).toList();
          break;

        case TimePeriod.Month:
          // Group by month - for now show current month, can be enhanced
          filtered = allExpenses.where((expense) {
            return expense.dateandTime.year == now.year &&
                expense.dateandTime.month == now.month;
          }).toList();
          break;

        case TimePeriod.Year:
          // Group by year - for now show current year
          filtered = allExpenses.where((expense) {
            return expense.dateandTime.year == now.year;
          }).toList();
          break;

        case TimePeriod.Custom:
          if (_customStartDate != null && _customEndDate != null) {
            filtered = allExpenses.where((expense) {
              return expense.dateandTime.isAfter(_customStartDate!) &&
                  expense.dateandTime.isBefore(_customEndDate!.add(const Duration(days: 1)));
            }).toList();
          }
          break;
      }

      // Sort by date descending
      filtered.sort((a, b) => b.dateandTime.compareTo(a.dateandTime));

      // Calculate total
      final total = filtered.fold<double>(0.0, (sum, expense) => sum + expense.amount);

      setState(() {
        _expenses = filtered;
        _totalExpenses = total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading expenses: $e')),
        );
      }
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primarycolor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      _loadExpenses();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.period == TimePeriod.Custom &&
        (_customStartDate == null || _customEndDate == null)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Select a date range',
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.date_range),
              label: const Text('Pick Date Range'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primarycolor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No expenses found',
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Summary Card
        Card(
          elevation: 4,
          color: primarycolor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Expenses',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${_totalExpenses.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_expenses.length} items',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Custom date range display
        if (widget.period == TimePeriod.Custom)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${DateFormat('MMM dd, yyyy').format(_customStartDate!)} - ${DateFormat('MMM dd, yyyy').format(_customEndDate!)}',
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
                ),
                TextButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Change'),
                ),
              ],
            ),
          ),

        // Expense List Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('Category / Expense',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Expanded(
                flex: 2,
                child: Text('Date',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Expanded(
                flex: 2,
                child: Text('Amount',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Expense List
        Expanded(
          child: ListView.builder(
            itemCount: _expenses.length,
            itemBuilder: (context, index) {
              final expense = _expenses[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _categoryNames[expense.categoryOfExpense] ?? expense.categoryOfExpense ?? 'Uncategorized',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: primarycolor,
                                  ),
                                ),
                                if (expense.reason != null && expense.reason!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      expense.reason!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              DateFormat('MMM dd, yyyy').format(expense.dateandTime),
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '₹${expense.amount.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (expense.paymentType != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Payment: ${expense.paymentType}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}