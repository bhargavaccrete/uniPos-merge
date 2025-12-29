import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/core/constants/cash_denominations.dart';
import 'package:unipos/domain/services/restaurant/day_management_service.dart';
import 'package:unipos/domain/services/restaurant/eod_service.dart';

class StartDayScreen extends StatefulWidget {
  const StartDayScreen({super.key});

  @override
  State<StartDayScreen> createState() => _StartDayScreenState();
}

class _StartDayScreenState extends State<StartDayScreen> {
  final TextEditingController _openingBalanceController = TextEditingController();
  final Map<String, TextEditingController> _denominationControllers = {};

  bool _isLoading = false;
  bool _useLastClosingBalance = false;
  double _lastClosingBalance = 0.0;
  double _calculatedTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeDenominationControllers();
    _loadLastClosingBalance();
  }

  void _initializeDenominationControllers() {
    for (final denomination in CashDenominations.all) {
      final controller = TextEditingController(text: '0');
      controller.addListener(_calculateTotalFromDenominations);
      _denominationControllers[denomination.toString()] = controller;
    }
  }

  Future<void> _loadLastClosingBalance() async {
    final lastBalance = await EODService.getLastClosingBalance();
    setState(() {
      _lastClosingBalance = lastBalance;
    });
  }

  void _calculateTotalFromDenominations() {
    double total = 0.0;
    _denominationControllers.forEach((denomination, controller) {
      final denomValue = double.tryParse(denomination) ?? 0.0;
      final count = int.tryParse(controller.text) ?? 0;
      total += denomValue * count;
    });

    setState(() {
      _calculatedTotal = total;
      _openingBalanceController.text = total.toStringAsFixed(2);
    });
  }

  Future<void> _startDay() async {
    final openingBalance = double.tryParse(_openingBalanceController.text);

    if (openingBalance == null || openingBalance < 0) {
      _showError('Please enter a valid opening balance');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await DayManagementService.setOpeningBalance(openingBalance);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Day started successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error starting day: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _openingBalanceController.dispose();
    _denominationControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Start Day', style: GoogleFonts.poppins()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Opening Balance',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the opening cash balance for today',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Last Closing Balance Option
            if (_lastClosingBalance > 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Last Closing Balance',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rs. ${_lastClosingBalance.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _useLastClosingBalance,
                      onChanged: (value) {
                        setState(() {
                          _useLastClosingBalance = value ?? false;
                          if (_useLastClosingBalance) {
                            _openingBalanceController.text = _lastClosingBalance.toStringAsFixed(2);
                          } else {
                            _openingBalanceController.clear();
                          }
                        });
                      },
                      title: Text(
                        'Use last closing balance',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Manual Entry
            Text(
              'Manual Entry',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _openingBalanceController,
              keyboardType: TextInputType.number,
              enabled: !_useLastClosingBalance,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
              ],
              decoration: InputDecoration(
                labelText: 'Opening Balance',
                hintText: 'Enter amount',
                prefixText: 'Rs. ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.teal),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Denomination Counter (Optional)
            ExpansionTile(
              title: Text(
                'Count Denominations (Optional)',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Total: Rs. ${_calculatedTotal.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Notes
                      Text(
                        'Notes',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...CashDenominations.notes.map((denomination) {
                        return _buildDenominationRow(denomination, true);
                      }),

                      const SizedBox(height: 16),

                      // Coins
                      Text(
                        'Coins',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...CashDenominations.coins.map((denomination) {
                        return _buildDenominationRow(denomination, false);
                      }),

                      const SizedBox(height: 16),

                      // Total
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Rs. ${_calculatedTotal.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.teal[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Start Day Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startDay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Start Day',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDenominationRow(double denomination, bool isNote) {
    final controller = _denominationControllers[denomination.toString()]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              CashDenominations.getLabel(denomination),
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Rs. ${((int.tryParse(controller.text) ?? 0) * denomination).toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}