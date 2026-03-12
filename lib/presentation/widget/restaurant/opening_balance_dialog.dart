
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unipos/domain/services/restaurant/day_management_service.dart';
import 'package:unipos/util/color.dart';


class OpeningBalanceDialog extends StatefulWidget {
  const OpeningBalanceDialog({super.key});

  @override
  State<OpeningBalanceDialog> createState() => _OpeningBalanceDialogState();
}

class _OpeningBalanceDialogState extends State<OpeningBalanceDialog> {
  final TextEditingController _openingBalanceController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingBalance = true;
  double _lastClosingBalance = 0.0;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadLastClosingBalance();
  }

  Future<void> _loadLastClosingBalance() async {
    final closing = await DayManagementService.getLastClosingBalance();
    if (mounted) {
      setState(() {
        _lastClosingBalance = closing;
        _isLoadingBalance = false;
        _openingBalanceController.text = closing > 0 ? closing.toStringAsFixed(2) : '0.00';
      });
    }
  }

  Future<void> _saveOpeningBalance() async {
    if (_openingBalanceController.text.isEmpty) {
      setState(() => _errorText = 'Please enter opening balance');
      return;
    }
    final balance = double.tryParse(_openingBalanceController.text);
    if (balance == null || balance < 0) {
      setState(() => _errorText = 'Please enter a valid amount');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final navigator = Navigator.of(context);
      if (mounted) navigator.pop(balance);
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
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.80),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Start New Day',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Set your opening cash balance',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter the cash amount currently in the drawer to start your day.',
                      style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),

                    // Last closing balance info
                    if (!_isLoadingBalance && _lastClosingBalance > 0) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.history_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Yesterday closed with ₹${_lastClosingBalance.toStringAsFixed(2)} in drawer',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Amount input card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _errorText != null
                              ? Colors.red
                              : AppColors.primary.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        children: [
                          Text(
                            'Cash in Drawer',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '₹',
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: IntrinsicWidth(
                                  child: TextField(
                                    controller: _openingBalanceController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                    ],
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    onChanged: (_) {
                                      if (_errorText != null) setState(() => _errorText = null);
                                    },
                                    decoration: InputDecoration(
                                      hintText: '0.00',
                                      hintStyle: GoogleFonts.poppins(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.divider,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_errorText != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              _errorText!,
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    Text(
                      'This amount will be used as the starting cash balance for today.',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary),
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        if (!_isLoading)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(0.0),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: AppColors.divider),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Start with ₹0',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        if (!_isLoading) const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveOpeningBalance,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
