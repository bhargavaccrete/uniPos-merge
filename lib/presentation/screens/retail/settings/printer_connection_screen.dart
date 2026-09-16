import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/saved_printer_model.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/screens/common/printer/addprinter/addprinter.dart';
import 'package:billberrylite/presentation/screens/common/printer/addprinter/slot_row_actions.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_status_pill.dart';
import 'package:billberrylite/presentation/widget/componets/common/primary_app_bar.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';

/// Retail printer connection — answers "which printer am I using?" on one page,
/// with the WiFi/Bluetooth/USB tabs a tap away on the button.
///
/// This page exists because the tabs alone can't answer that question: each tab
/// filters saved printers to its OWN transport and [AddPrinter] opens on WiFi,
/// so a shop using a Bluetooth printer would land on an empty WiFi form while a
/// printer was connected and working. The active printer is a single global
/// value, so it needs a single place to live.
///
/// Retail has one slot (Billing) and no KOT, so "active" here always means
/// `role: 'receipt'`.
class RetailPrinterConnectionScreen extends StatefulWidget {
  const RetailPrinterConnectionScreen({super.key});

  @override
  State<RetailPrinterConnectionScreen> createState() =>
      _RetailPrinterConnectionScreenState();
}

class _RetailPrinterConnectionScreenState
    extends State<RetailPrinterConnectionScreen> {
  static const _role = 'receipt';

  @override
  void initState() {
    super.initState();
    printerStore.loadSavedPrinters();
  }

  void _openAddPrinter() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPrinter(assignToRole: _role)),
    ).then((_) => printerStore.loadSavedPrinters());
  }

  // WiFi is the fallback, so any new transport must be named explicitly here
  // or it silently renders as a WiFi printer.
  IconData _iconFor(SavedPrinterModel p) => p.isBluetooth
      ? Icons.bluetooth
      : p.isUsb
      ? Icons.usb
      : p.isWindowsPdf
      ? Icons.picture_as_pdf_outlined
      : p.isWindows
      ? Icons.desktop_windows_outlined
      : Icons.wifi;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: buildPrimaryAppBar(
        title: 'Connect Printer',
        titleFontSize: AppResponsive.headingFontSize(context),
      ),
      // Rectangular, not the default pill — house button convention.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPrinter,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        icon: Icon(Icons.add),
        label: Text(
          'Add Printer',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      body: AppResponsive.constrainedContent(
        context: context,
        alignment: Alignment.topCenter,
        child: Observer(
          builder: (_) {
            final active = printerStore.defaultReceiptPrinter;
            // Every transport in one list — the tabs can only show their own.
            final others = printerStore.savedPrinters
                .where((p) => p.id != active?.id)
                .toList();

            if (active == null && others.isEmpty) {
              // No inline action button — the floating "Add Printer" is the one
              // way in, from both this state and the populated list.
              return const AppEmptyState(
                icon: Icons.print_disabled_rounded,
                title: 'No printer connected',
                message:
                    'Pair a thermal printer over WiFi, Bluetooth or USB '
                    'to print receipts directly.\n\nWithout one, receipts fall '
                    'back to the PDF preview.',
              );
            }

            return ListView(
              // Bottom padding clears the floating button.
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _sectionHeader('ACTIVE PRINTER'),
                if (active != null) _activeCard(active) else _noActiveCard(),
                if (others.isNotEmpty) ...[
                  SizedBox(height: AppResponsive.smallSpacing(context)),
                  _sectionHeader('OTHER SAVED PRINTERS'),
                  ...others.map(_otherRow),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Active printer ─────────────────────────────────────────────────────────
  Widget _activeCard(SavedPrinterModel p) {
    return Container(
      padding: AppResponsive.cardPadding(context),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconFor(p), color: AppColors.success, size: 22),
              ),
              SizedBox(width: AppResponsive.mediumSpacing(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.subheadingFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${p.type.toUpperCase()} · ${p.paperSize}mm · ${p.address}',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AppStatusPill(
                label: 'Active',
                color: AppColors.success,
                icon: Icons.check_circle,
              ),
            ],
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _testPrint(p),
                  icon: Icon(
                    Icons.print_outlined,
                    size: AppResponsive.smallIconSize(context),
                  ),
                  label: Text(
                    'Test Print',
                    style: GoogleFonts.poppins(
                      fontSize: AppResponsive.bodyFontSize(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    padding: EdgeInsets.symmetric(
                      vertical: AppResponsive.mediumSpacing(context),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(p),
                icon: Icon(
                  Icons.delete_outline,
                  size: AppResponsive.smallIconSize(context),
                ),
                label: Text(
                  'Remove',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.bodyFontSize(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Saved printers exist but none holds the slot — reachable if the active one
  /// was deleted from inside a tab.
  Widget _noActiveCard() {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: AppResponsive.smallIconSize(context),
            color: AppColors.warning,
          ),
          SizedBox(width: AppResponsive.smallSpacing(context)),
          Expanded(
            child: Text(
              'No printer selected — tap one below to make it active.',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Other saved printers ───────────────────────────────────────────────────
  Widget _otherRow(SavedPrinterModel p) {
    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(
          AppResponsive.borderRadius(context),
        ),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        onTap: () => setActiveForSlot(p, _role),
        leading: Icon(_iconFor(p), color: AppColors.info),
        title: Text(
          p.name,
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.bodyFontSize(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '${p.type.toUpperCase()} · ${p.paperSize}mm',
          style: GoogleFonts.poppins(
            fontSize: AppResponsive.captionFontSize(context),
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Set active',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.captionFontSize(context),
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: AppResponsive.iconSize(context),
                color: AppColors.danger,
              ),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(p),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: AppResponsive.captionFontSize(context),
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _testPrint(SavedPrinterModel printer) async {
    final success = await printerStore.testPrint(printer);
    if (!mounted) return;
    if (success) {
      NotificationService.instance.showSuccess('Test print sent!');
    } else {
      NotificationService.instance.showError(
        printerStore.errorMessage ?? 'Test print failed',
      );
    }
  }

  Future<void> _confirmDelete(SavedPrinterModel printer) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Remove Printer',
      message: 'Remove "${printer.name}" from saved printers?',
      confirmLabel: 'Remove',
      accent: AppColors.danger,
      icon: Icons.delete_rounded,
    );
    if (confirmed != true) return;

    await printerStore.deletePrinter(printer.id);
    if (mounted) {
      NotificationService.instance.showSuccess('Printer removed');
    }
  }
}
