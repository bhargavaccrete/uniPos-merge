import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/util/color.dart';

import '../../../constants/restaurant/color.dart';
import '../../../domain/services/restaurant/day_management_service.dart';

class OpeningBalanceDialog extends StatefulWidget {
  const OpeningBalanceDialog({super.key});

  @override
  State<OpeningBalanceDialog> createState() => _OpeningBalanceDialogState();
}

class _OpeningBalanceDialogState extends State<OpeningBalanceDialog> {
  final TextEditingController _openingBalanceController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadLastClosingBalance();
  }

  Future<void> _loadLastClosingBalance() async {
    // You can optionally load the last closing balance here as a suggestion
    // For now, we'll start with 0
    _openingBalanceController.text = '0.00';
  }

  Future<void> _saveOpeningBalance() async {
    if (_openingBalanceController.text.isEmpty) {
      setState(() {
        _errorText = 'Please enter opening balance';
      });
      return;
    }

    final balance = double.tryParse(_openingBalanceController.text);
    if (balance == null || balance < 0) {
      setState(() {
        _errorText = 'Please enter a valid amount';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // Save reference to navigator before async call
      final navigator = Navigator.of(context);

      await DayManagementService.setOpeningBalance(balance);

      if (mounted) {
        // Use the saved navigator reference instead of context
        navigator.pop(balance);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = 'Error saving opening balance: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _openingBalanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent closing without setting balance
      child: AlertDialog(
        title: Column(
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 50,
              color: AppColors.primary,
            ),
            SizedBox(height: 10),
            Text(
              'Start New Day',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please enter the opening balance to start your day.',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Text(
                'Opening Balance (Rs.)',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _openingBalanceController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixText: 'Rs. ',
                  errorText: _errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              SizedBox(height: 10),
              Text(
                'This amount will be used as the starting cash balance for today.',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: () async {
                // Save reference to navigator before async call
                final navigator = Navigator.of(context);

                // Set opening balance to 0 and continue
                await DayManagementService.setOpeningBalance(0.0);
                if (mounted) {
                  navigator.pop(0.0);
                }
              },
              child: Text(
                'Start with Rs. 0',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveOpeningBalance,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: _isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Start Day',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }
}