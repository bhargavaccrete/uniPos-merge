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
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';

/// Shows the opening-balance dialog and starts the day with the entered amount,
/// recording an opening adjustment if it differs from yesterday's closing.
/// Returns true once the day is started (false only if dismissed).
///
/// Single source of truth for "start the day" — used by the dashboard banner
/// and by the order screens (so the day starts the moment the first order is
/// placed, not forced on app open).
Future<bool> promptStartDay(BuildContext context) async {
  // A session is already open — never start a second one.
  //
  // `setOpeningBalance` below routes to `startSession`, which mints a NEW
  // sessionId, repoints the current-session key (orphaning the live session as
  // permanently un-closed), moves `dayStartTimestamp` to now — dropping every
  // sale already rung up out of the EOD, since `generateRetailEODReport`
  // filters from that timestamp — and resets the daily bill number.
  //
  // Ten of the eleven call sites checked `isDayStarted()` first; the retail
  // Settings screen did not, so tapping "Start Day" mid-day silently lost the
  // day's takings. Guarding here means no caller can do it.
  //
  // Returns true: the contract is "is a day now open?", and one already is.
  if (await DayManagementService.isDayStarted()) return true;
  if (!context.mounted) return false;

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
    final byName =
        RestaurantSession.staffName ??
        (RestaurantSession.isAdmin ? 'Admin' : 'Staff');
    await cashMovementStore.addAdjustment(
      signedAmount: diff,
      reason: 'Opening balance modified',
      note:
          'Previous closing: ${CurrencyHelper.currentSymbol}${lastClosing.toStringAsFixed(2)}, '
          'Opened at: ${CurrencyHelper.currentSymbol}${balance.toStringAsFixed(2)}',
      staffName: byName,
    );
  }

  await DayManagementService.setOpeningBalance(balance); // marks day started
  NotificationService.instance.showSuccess(
    'Day started with opening balance: ${CurrencyHelper.currentSymbol}${balance.toStringAsFixed(2)}',
  );
  return true;
}

class OpeningBalanceDialog extends StatefulWidget {
  const OpeningBalanceDialog({super.key});

  @override
  State<OpeningBalanceDialog> createState() => _OpeningBalanceDialogState();
}

class _OpeningBalanceDialogState extends State<OpeningBalanceDialog> {
  final TextEditingController _openingBalanceController =
      TextEditingController();
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
        _openingBalanceController.text = closing > 0
            ? closing.toStringAsFixed(2)
            : '0.00';
      });
    }
  }

  Future<void> _saveOpeningBalance() async {
    // Double-tap guard. The shared primary button has no disabled state, so the
    // guard lives here rather than on the button.
    if (_isLoading) return;
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
    // AppDialogShell, like the other 100+ dialogs in the app. This used to be a
    // bespoke Dialog with a gradient header and `insetPadding: isTablet ? 120`
    // — a FIXED inset, so on a 1600px desktop it rendered ~1360px wide while
    // every shared dialog caps at dialogWidth (500 tablet / 600 desktop).
    // The floating close X is now the standard Cancel button; it pops with no
    // result, which promptStartDay already reads as "not started".
    return PopScope(
      canPop: true, // back gesture = cancel (returns null)
      child: AppDialogShell(
        title: 'Start New Day',
        subtitle: 'Set your opening cash balance',
        accent: AppColors.primary,
        icon: Icons.account_balance_wallet_rounded,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the cash amount currently in the drawer to start your day.',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.bodyFontSize(context),
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            if (!_isLoadingBalance && _lastClosingBalance > 0) ...[
              AppResponsive.verticalSpace(context, size: SpacingSize.small),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppResponsive.mediumSpacing(context),
                  vertical: AppResponsive.smallSpacing(context),
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: AppResponsive.smallIconSize(context),
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Yesterday closed with ${CurrencyHelper.currentSymbol}${_lastClosingBalance.toStringAsFixed(2)} in drawer',
                        style: GoogleFonts.poppins(
                          fontSize: AppResponsive.smallFontSize(context),
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            AppResponsive.verticalSpace(context),
            AppTextField(
              controller: _openingBalanceController,
              autofocus: true,
              label: 'Cash in Drawer',
              hint: '0.00',
              icon: Icons.account_balance_wallet_outlined,
              prefixWidget: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  CurrencyHelper.currentSymbol,
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _saveOpeningBalance(),
              validator: (_) => _errorText,
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            Text(
              'This amount will be used as the starting cash balance for today.',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          appDialogCancelButton(context),
          const SizedBox(width: 12),
          // Starts with whatever is in the field (0 is fine).
          appDialogPrimaryButton(
            label: 'Start Day',
            onPressed: _saveOpeningBalance,
          ),
        ],
      ),
    );
  }
}
