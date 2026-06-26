
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/domain/services/restaurant/day_management_service.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/util/restaurant/restaurant_session.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'package:billberrylite/util/common/currency_helper.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';


/// Shows the opening-balance dialog and starts the day with the entered amount,
/// recording an opening adjustment if it differs from yesterday's closing.
/// Returns true once the day is started (false only if dismissed).
///
/// Single source of truth for "start the day" — used by the dashboard banner
/// and by the order screens (so the day starts the moment the first order is
/// placed, not forced on app open).
Future<bool> promptStartDay(BuildContext context) async {
  final balance = await showDialog<double>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const OpeningBalanceDialog(),
  );
  if (balance == null) return false;

  // Record an ADJUSTMENT if the opening differs from yesterday's closing.
  final lastClosing = await DayManagementService.getLastClosingBalance();
  final diff = balance - lastClosing;
  if (lastClosing > 0 && diff.abs() > 0.01) {
    final byName = RestaurantSession.staffName ??
        (RestaurantSession.isAdmin ? 'Admin' : 'Staff');
    await cashMovementStore.addAdjustment(
      signedAmount: diff,
      reason: 'Opening balance modified',
      note: 'Previous closing: Rs.${lastClosing.toStringAsFixed(2)}, '
          'Opened at: Rs.${balance.toStringAsFixed(2)}',
      staffName: byName,
    );
  }

  await DayManagementService.setOpeningBalance(balance); // marks day started
  NotificationService.instance.showSuccess(
    'Day started with opening balance: Rs. ${balance.toStringAsFixed(2)}',
  );
  return true;
}

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
    final isTablet = !AppResponsive.isMobile(context);

    return PopScope(
      canPop: true, // back gesture = cancel (returns null)
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isTablet ? 120 : 28,
          vertical: isTablet ? 60 : 40,
        ),
        child: Stack(
          children: [
            Container(
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
                padding: EdgeInsets.symmetric(
                  vertical: isTablet ? 32 : 28,
                  horizontal: isTablet ? 28 : 24,
                ),
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
                      padding: EdgeInsets.all(isTablet ? 16 : 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        size: isTablet ? 38 : 32,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: isTablet ? 14 : 12),
                    Text(
                      'Start New Day',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Set your opening cash balance',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 15 : 13,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ──────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 28 : 24,
                  isTablet ? 24 : 20,
                  isTablet ? 28 : 24,
                  isTablet ? 28 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter the cash amount currently in the drawer to start your day.',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 14 : 13,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // Last closing balance info
                    if (!_isLoadingBalance && _lastClosingBalance > 0) ...[
                      SizedBox(height: isTablet ? 16 : 14),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 14 : 12,
                          vertical: isTablet ? 12 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.history_rounded, size: isTablet ? 18 : 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Yesterday closed with ${CurrencyHelper.currentSymbol}${_lastClosingBalance.toStringAsFixed(2)} in drawer',
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 13 : 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: isTablet ? 24 : 20),

                    // Amount input
                    AppTextField(
                      controller: _openingBalanceController,
                      label: 'Cash in Drawer',
                      hint: '0.00',
                      icon: Icons.account_balance_wallet_outlined,
                      prefixWidget: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          CurrencyHelper.currentSymbol,
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      validator: (_) => _errorText,
                      onChanged: (_) {
                        if (_errorText != null) setState(() => _errorText = null);
                      },
                    ),

                    SizedBox(height: isTablet ? 10 : 8),
                    Text(
                      'This amount will be used as the starting cash balance for today.',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 12 : 11,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    SizedBox(height: isTablet ? 28 : 24),

                    // Single action — starts with whatever's in the field (0 is fine).
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveOpeningBalance,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(vertical: isTablet ? 16 : 14),
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
                                  fontSize: isTablet ? 16 : 14,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
            ),
            // Close (cancel) — returns null so promptStartDay reports "not started"
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 22),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Cancel',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
