import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import 'package:billberrylite/core/config/fiscal_year_rule.dart';
import 'package:billberrylite/domain/services/common/document_number_service.dart';
import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_text_field.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Configures the invoice series: what it is called and where it resumes.
///
/// A shop migrating from another system is mid-series — it may already have
/// issued up to `INV-01249` and cannot restart at 1 without duplicating numbers
/// on paper. Setting the next number is the whole point of this screen.
///
/// The prefix override is stored beside the counter rather than replacing it,
/// so renaming `INV` to `BILL` re-labels the series without restarting it.
class InvoiceNumberingScreen extends StatefulWidget {
  const InvoiceNumberingScreen({super.key});

  @override
  State<InvoiceNumberingScreen> createState() => _InvoiceNumberingScreenState();
}

class _InvoiceNumberingScreenState extends State<InvoiceNumberingScreen> {
  final DocumentNumberService _numbers = DocumentNumberService();
  final TextEditingController _prefixController = TextEditingController();
  final TextEditingController _nextController = TextEditingController();

  static const String _prefix = DocumentNumberService.invoice;

  @override
  void initState() {
    super.initState();
    _prefixController.text = _numbers.displayPrefix(_prefix);
    _nextController.text = _numbers.peekNext(_prefix).toString();
    // Both fields feed the live preview below.
    _prefixController.addListener(_refresh);
    _nextController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _prefixController.removeListener(_refresh);
    _nextController.removeListener(_refresh);
    _prefixController.dispose();
    _nextController.dispose();
    super.dispose();
  }

  /// What the next sale would print, given what is currently typed.
  String get _preview {
    final prefix = _prefixController.text.trim().toUpperCase();
    final seq = int.tryParse(_nextController.text.trim()) ?? 1;
    final label = prefix.isEmpty ? _prefix : prefix;
    return '$label-${(seq < 1 ? 1 : seq).toString().padLeft(DocumentNumberService.sequenceWidth, '0')}';
  }

  Future<void> _save() async {
    final prefix = _prefixController.text.trim().toUpperCase();
    if (prefix.isEmpty) {
      NotificationService.instance.showError('Enter a prefix');
      return;
    }
    // Letters and digits only. Rule 46(b) permits a hyphen and a slash too, but
    // the hyphen is already the separator this format uses, and allowing a
    // second one would make the number ambiguous to read.
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(prefix)) {
      NotificationService.instance.showError(
        'Prefix can use letters and numbers only',
      );
      return;
    }

    final seq = int.tryParse(_nextController.text.trim());
    if (seq == null || seq < 1) {
      NotificationService.instance.showError('Next number must be 1 or more');
      return;
    }

    await _numbers.setPrefix(_prefix, prefix);
    await _numbers.setNext(_prefix, seq);

    if (!mounted) return;
    NotificationService.instance.showSuccess('Invoice numbering saved');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Invoice Numbering',
        titleFontSize: AppResponsive.subheadingFontSize(context),
      ),
      body: SingleChildScrollView(
        padding: AppResponsive.padding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: AppResponsive.mediumSpacing(context)),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prefix',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppResponsive.smallSpacing(context)),
                  AppTextField(
                    controller: _prefixController,
                    hint: 'INV',
                    maxLength: DocumentNumberService.maxPrefixLength,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    ],
                  ),
                  Text(
                    'Up to ${DocumentNumberService.maxPrefixLength} letters or '
                    'numbers, so the whole invoice number stays within the 16 '
                    'characters the tax rules allow.',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppResponsive.largeSpacing(context)),
                  Text(
                    'Next number',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppResponsive.smallSpacing(context)),
                  AppTextField(
                    controller: _nextController,
                    hint: '1',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  Text(
                    'Set this to continue a series you already issue elsewhere. '
                    'It only moves the series forward from the next sale on — '
                    'invoices already recorded keep their numbers.',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppResponsive.largeSpacing(context)),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(context, 'Next invoice', _preview, emphasise: true),
                  const Divider(height: 24, thickness: 0.5),
                  _row(context, 'Restarts at 1 on', FiscalYearRule.resetLabel),
                  SizedBox(height: AppResponsive.smallSpacing(context)),
                  Text(
                    'The series restarts each financial year. Last year\'s '
                    '$_preview and this year\'s are different sales — each keeps '
                    'its own record.',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.captionFontSize(context),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppResponsive.extraLargeSpacing(context)),
            SizedBox(
              width: double.infinity,
              height: AppResponsive.buttonHeight(context),
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Save',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    padding: AppResponsive.cardPadding(context),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
      border: Border.all(color: AppColors.divider, width: 0.5),
    ),
    child: child,
  );

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool emphasise = false,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.bodyFontSize(context),
          color: AppColors.textSecondary,
        ),
      ),
      Text(
        value,
        style: GoogleFonts.poppins(
          fontSize: emphasise
              ? AppResponsive.subheadingFontSize(context)
              : AppResponsive.bodyFontSize(context),
          fontWeight: FontWeight.w700,
          color: emphasise ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
    ],
  );
}
