import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:billberrylite/domain/services/retail/retail_test_data_generator.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// DEBUG-ONLY: create a consistent set of Retail test data through the real
/// app services. Not reachable in release builds (the Settings tile is
/// hidden, this screen refuses to render, and the generator throws).
class RetailTestDataScreen extends StatefulWidget {
  const RetailTestDataScreen({super.key});

  @override
  State<RetailTestDataScreen> createState() => _RetailTestDataScreenState();
}

class _RetailTestDataScreenState extends State<RetailTestDataScreen> {
  RetailTestDataCheck? _check;
  bool _lowStock = false;
  bool _endOfDay = false;
  bool _acceptDuplicate = false;
  bool _running = false;
  String? _progress;
  RetailTestDataResult? _result;

  @override
  void initState() {
    super.initState();
    _refreshCheck();
  }

  Future<void> _refreshCheck() async {
    final c = await RetailTestDataGenerator.check();
    if (mounted) setState(() => _check = c);
  }

  Future<void> _toggleEndOfDay(bool on) async {
    if (!on) {
      setState(() => _endOfDay = false);
      return;
    }
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Close the day too?',
      message: 'End of Day will CLOSE the current day with the counted cash '
          '₹50 short. You will have to start a new day before selling again.\n\n'
          'It only runs if this generator opens the day itself (so the closed '
          'day holds test data only); otherwise that step is skipped.',
      confirmLabel: 'Include End of Day',
      accent: AppColors.warning,
      icon: Icons.nightlight_round,
    );
    if (mounted) setState(() => _endOfDay = ok);
  }

  Future<void> _generate() async {
    final check = _check;
    if (check == null) return;
    final ok = await showAppConfirmDialog(
      context: context,
      title: 'Add test data to this device?',
      message: 'Creates products, customers, suppliers, sales, credit, '
          'returns, purchasing, stock, cash and attendance named '
          '"${check.nextPrefix} …".\n\nThere is NO one-tap undo — each record '
          'stays like real data. Use a test install.',
      confirmLabel: 'Generate',
      accent: AppColors.warning,
      icon: Icons.science_outlined,
    );
    if (!ok || !mounted) return;

    setState(() {
      _running = true;
      _result = null;
    });
    final result = await RetailTestDataGenerator(
      onProgress: (step) {
        if (mounted) setState(() => _progress = step);
      },
    ).run(RetailTestDataOptions(
      lowStockVariants: _lowStock,
      endOfDayShort: _endOfDay,
    ));
    if (!mounted) return;
    setState(() {
      _running = false;
      _progress = null;
      _result = result;
      _acceptDuplicate = false;
    });
    _refreshCheck();
  }

  Widget _text(String s, {Color? color, FontWeight? weight}) => Text(
        s,
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.bodyFontSize(context),
          color: color ?? AppColors.textPrimary,
          fontWeight: weight,
        ),
      );

  Widget _notice(String text, Color color, IconData icon) => Container(
        width: double.infinity,
        padding: AppResponsive.cardPadding(context),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: AppResponsive.iconSize(context)),
            SizedBox(width: AppResponsive.smallSpacing(context)),
            Expanded(child: _text(text)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) {
      return Scaffold(
        appBar: buildPrimaryAppBar(title: 'Test Data'),
        body: const Center(child: Text('Not available in release builds')),
      );
    }

    final check = _check;
    final duplicates = check != null && check.existingRuns.isNotEmpty;
    final blocked = check != null && (check.cartInUse || check.staleDayOpen);
    final canRun = check != null &&
        !_running &&
        !blocked &&
        (!duplicates || _acceptDuplicate);
    final spacing = SizedBox(height: AppResponsive.mediumSpacing(context));

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(title: 'Retail Test Data (debug)'),
      body: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        child: ListView(
          padding: AppResponsive.cardPadding(context),
          children: [
            _notice(
              'Debug builds only. Data is created through the real Retail '
              'services and is dated today (attendance goes back to the 26th '
              'of last month). It never edits or removes existing data, and '
              'it cannot be undone with one action.',
              AppColors.warning,
              Icons.warning_amber_rounded,
            ),
            spacing,
            if (check == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (check.cartInUse)
                _notice('The current cart has items. Finish or clear that '
                    'sale first.', AppColors.danger, Icons.block),
              if (check.staleDayOpen)
                _notice('A day from an earlier date is still open. Complete '
                    'its End of Day first.', AppColors.danger, Icons.block),
              if (duplicates) ...[
                _notice(
                  'Test data already exists on this device: '
                  '${(check.existingRuns.toList()..sort()).join(', ')}. '
                  'Generating again adds a SECOND full set named '
                  '"${check.nextPrefix} …".',
                  AppColors.danger,
                  Icons.content_copy_rounded,
                ),
                CheckboxListTile(
                  value: _acceptDuplicate,
                  onChanged: _running
                      ? null
                      : (v) => setState(() => _acceptDuplicate = v ?? false),
                  title: _text('I understand — create another set'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
              spacing,
              SwitchListTile(
                value: _lowStock,
                onChanged: _running ? null : (v) => setState(() => _lowStock = v),
                title: _text('55 low-stock variants'),
                subtitle: _text('For the Low Stock "Current page" check',
                    color: AppColors.textSecondary),
              ),
              SwitchListTile(
                value: _endOfDay,
                onChanged: _running ? null : _toggleEndOfDay,
                title: _text('End of Day, ₹50 short'),
                subtitle: _text('Closes the day — off by default',
                    color: AppColors.textSecondary),
              ),
              spacing,
              ElevatedButton.icon(
                onPressed: canRun ? _generate : null,
                icon: const Icon(Icons.science_outlined),
                label: Text(
                  _running
                      ? 'Generating… ${_progress ?? ''}'
                      : 'Generate ${check.nextPrefix}',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                      vertical: AppResponsive.mediumSpacing(context)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
            if (_result != null) ...[
              spacing,
              _summary(_result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summary(RetailTestDataResult r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _notice(
          r.success
              ? 'Done: ${r.prefix}. Everything below was created.'
              : 'Stopped at "${r.failedStep}": ${r.error}\n'
                  'The steps marked Done before it WERE created and remain; '
                  'nothing was rolled back.',
          r.success ? AppColors.success : AppColors.danger,
          r.success ? Icons.check_circle_outline : Icons.error_outline,
        ),
        SizedBox(height: AppResponsive.smallSpacing(context)),
        for (final s in r.steps)
          ListTile(
            dense: true,
            title: _text(s.name, weight: FontWeight.w600),
            subtitle: _text(s.detail, color: AppColors.textSecondary),
            trailing: AppStatusPill(
              dense: true,
              label: s.ok ? 'Done' : 'Failed',
              color: s.ok ? AppColors.success : AppColors.danger,
            ),
          ),
      ],
    );
  }
}
