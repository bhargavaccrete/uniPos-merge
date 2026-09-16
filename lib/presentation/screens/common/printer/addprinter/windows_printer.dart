import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/domain/services/common/windows_spooler/windows_spooler_service.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_dialog.dart';
import 'package:billberrylite/presentation/widget/componets/common/app_empty_state.dart';
import 'package:billberrylite/util/color.dart';
import 'package:billberrylite/util/common/app_responsive.dart';
import 'save_printer_dialog.dart';
import 'slot_row_actions.dart';

/// Windows spooler printer setup.
///
/// `flutter_thermal_printer` has no Windows implementation, so Bluetooth and
/// USB cannot reach a printer there. Windows itself can: any printer installed
/// in Windows Settings — over USB, Bluetooth SPP or the network — becomes a
/// print queue, and a RAW write to that queue delivers ESC/POS bytes untouched.
///
/// So this tab does not scan for hardware. It lists the queues Windows already
/// knows about and lets staff pick one.
class WindowsPrinterTab extends StatefulWidget {
  /// Slot to point at a newly saved printer — see [AddPrinter.assignToRole].
  final String? assignToRole;

  const WindowsPrinterTab({super.key, this.assignToRole});

  @override
  State<WindowsPrinterTab> createState() => _WindowsPrinterTabState();
}

class _WindowsPrinterTabState extends State<WindowsPrinterTab> {
  List<Printer> _queues = const [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    printerStore.loadSavedPrinters();
    _loadQueues();
  }

  /// One-shot enumeration. `Printing.listPrinters()` reports `canListPrinters:
  /// true` on Windows and returns the queue name in both `url` and `name`, so
  /// no FFI is needed to discover printers — only to write to them.
  Future<void> _loadQueues() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final found = await Printing.listPrinters();
      final sorted = [...found]..sort(_byUsefulness);
      if (!mounted) return;
      setState(() {
        _queues = sorted;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _isLoading = false;
      });
    }
  }

  /// Real printers first, then the Windows default, then by name. Virtual
  /// queues (XPS, Fax, Print to PDF) sink to the bottom — a cashier picking one
  /// gets a silent file instead of paper.
  int _byUsefulness(Printer a, Printer b) {
    final aVirtual = isLikelyVirtualQueue(a.name, a.model);
    final bVirtual = isLikelyVirtualQueue(b.name, b.model);
    if (aVirtual != bVirtual) return aVirtual ? 1 : -1;
    if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: AppResponsive.constrainedContent(
        context: context,
        child: SingleChildScrollView(
          padding: AppResponsive.cardPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQueueSection(context),
              SizedBox(height: AppResponsive.mediumSpacing(context) * 1.5),
              _buildSavedPrintersList(context),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // SECTION 1: Windows print queues
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildQueueSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius:
            BorderRadius.circular(AppResponsive.borderRadius(context) + 4),
        border: Border.all(color: AppColors.divider),
      ),
      padding: AppResponsive.cardPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppResponsive.smallSpacing(context)),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppResponsive.borderRadius(context)),
                ),
                child: Icon(
                  Icons.desktop_windows_outlined,
                  color: AppColors.primary,
                  size: AppResponsive.smallIconSize(context),
                ),
              ),
              SizedBox(width: AppResponsive.smallSpacing(context)),
              Expanded(
                child: Text(
                  'Windows Printers',
                  style: GoogleFonts.poppins(
                    fontSize: AppResponsive.subheadingFontSize(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh,
                    size: AppResponsive.smallIconSize(context)),
                tooltip: 'Refresh',
                onPressed: _isLoading ? null : _loadQueues,
              ),
            ],
          ),
          SizedBox(height: AppResponsive.smallSpacing(context)),
          Text(
            'Printers installed in Windows. Connect the printer in Windows '
            'Settings first — USB, Bluetooth or network all appear here.',
            style: GoogleFonts.poppins(
              fontSize: AppResponsive.smallFontSize(context),
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: AppResponsive.mediumSpacing(context)),
          _buildQueueBody(context),
        ],
      ),
    );
  }

  Widget _buildQueueBody(BuildContext context) {
    if (_isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(
            vertical: AppResponsive.mediumSpacing(context) * 1.5),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return _notice(
        context,
        icon: Icons.error_outline,
        color: AppColors.danger,
        text: 'Could not read the Windows printer list.\n$_loadError',
      );
    }

    if (_queues.isEmpty) {
      return _notice(
        context,
        icon: Icons.print_disabled_outlined,
        color: AppColors.textSecondary,
        text: 'No printers installed in Windows. Add one in '
            'Settings → Bluetooth & devices → Printers & scanners, then refresh.',
      );
    }

    return Column(children: _queues.map((q) => _queueRow(context, q)).toList());
  }

  Widget _queueRow(BuildContext context, Printer queue) {
    final virtual = isLikelyVirtualQueue(queue.name, queue.model);
    final details = <String>[
      if (queue.model != null && queue.model!.isNotEmpty) queue.model!,
      if (!queue.isAvailable) 'Offline',
      if (virtual) 'Not a physical printer',
    ].join(' · ');

    return Container(
      margin: EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppResponsive.borderRadius(context)),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        onTap: () => _showSaveDialog(queue),
        leading: Icon(
          virtual ? Icons.description_outlined : Icons.print_outlined,
          color: virtual ? AppColors.textSecondary : AppColors.info,
          size: AppResponsive.iconSize(context),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                queue.name,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.bodyFontSize(context),
                  fontWeight: FontWeight.w600,
                  color: virtual ? AppColors.textSecondary : null,
                ),
              ),
            ),
            if (queue.isDefault) ...[
              SizedBox(width: AppResponsive.smallSpacing(context)),
              Text(
                'Default',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        subtitle: details.isEmpty
            ? null
            : Text(
                details,
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(context),
                  color: AppColors.textSecondary,
                ),
              ),
        trailing: Icon(Icons.add_circle_outline,
            size: AppResponsive.smallIconSize(context),
            color: AppColors.primary),
      ),
    );
  }

  Widget _notice(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: AppResponsive.mediumSpacing(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: AppResponsive.smallIconSize(context)),
          SizedBox(width: AppResponsive.smallSpacing(context)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.smallFontSize(context),
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // SECTION 2: Saved Windows printers
  // ════════════════════════════════════════════════════════════════════════

  Widget _buildSavedPrintersList(BuildContext context) {
    return Observer(
      builder: (_) {
        final saved = printerStore.windowsPrinters;

        if (saved.isEmpty) {
          return AppEmptyState(
            icon: Icons.print_outlined,
            title: 'No Windows printers saved',
            message: 'Pick one from the list above to use it for printing.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved Windows Printers',
              style: GoogleFonts.poppins(
                fontSize: AppResponsive.subheadingFontSize(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppResponsive.smallSpacing(context)),
            ...saved.map((printer) => Container(
                  margin:
                      EdgeInsets.only(bottom: AppResponsive.smallSpacing(context)),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(
                        AppResponsive.borderRadius(context)),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: ListTile(
                    // In assign mode, tapping a row makes it the active printer.
                    onTap: () => setActiveForSlot(printer, widget.assignToRole),
                    leading: Icon(
                        printer.isWindowsPdf
                            ? Icons.picture_as_pdf_outlined
                            : Icons.desktop_windows_outlined,
                        color: AppColors.info,
                        size: AppResponsive.iconSize(context)),
                    title: Text(
                      printer.name,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${printer.address} | ${printer.paperSize}mm',
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(context),
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...[activeSlotBadge(printer, widget.assignToRole)]
                            .whereType<Widget>(),
                        IconButton(
                          icon: Icon(Icons.print_outlined,
                              size: AppResponsive.smallIconSize(context)),
                          tooltip: 'Test Print',
                          onPressed: () => _testPrint(printer.id),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: AppResponsive.smallIconSize(context),
                              color: AppColors.danger),
                          tooltip: 'Delete',
                          onPressed: () =>
                              _confirmDelete(printer.id, printer.name),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ════════════════════════════════════════════════════════════════════════

  /// `queue.url` is the Windows queue name (the plugin puts `pPrinterName` in
  /// both `url` and `name`), and it is what `OpenPrinter` needs. Stored whole —
  /// a queue name may contain a colon.
  Future<void> _showSaveDialog(Printer queue) async {
    // The output mode is an EXPLICIT choice, never inferred from the printer's
    // name — the saved type is what decides the print path. The hint below only
    // informs the decision; it does not make it.
    final asPdf = await _askOutputMode(queue);
    if (asPdf == null) return;

    final result = await showDialog<SavePrinterResult>(
      context: context,
      builder: (ctx) => SavePrinterDialog(
        title: asPdf ? 'Save PDF Printer' : 'Save Thermal Printer',
        icon: asPdf ? Icons.picture_as_pdf_outlined : Icons.print_outlined,
        subtitle: queue.url,
        initialName: queue.name,
      ),
    );
    if (result == null) return;

    await printerStore.saveWindowsPrinter(
      name: result.name,
      queueName: queue.url,
      paperSize: result.paperSize,
      role: 'receipt',
      assignRole: widget.assignToRole,
      asPdfPrinter: asPdf,
    );
    if (mounted) {
      NotificationService.instance.showSuccess('Printer "${result.name}" saved');
    }
  }

  /// Ask how this queue should be driven. Returns true for a PDF/document
  /// printer, false for a RAW ESC/POS thermal printer, null if cancelled.
  Future<bool?> _askOutputMode(Printer queue) {
    final looksVirtual = isLikelyVirtualQueue(queue.name, queue.model);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialogShell(
        title: 'How should we print?',
        subtitle: queue.name,
        accent: AppColors.primary,
        icon: Icons.tune,
        actions: [appDialogCancelButton(ctx)],
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (looksVirtual) ...[
              Text(
                'This looks like a PDF writer rather than a thermal printer.',
                style: GoogleFonts.poppins(
                  fontSize: AppResponsive.smallFontSize(ctx),
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: AppResponsive.mediumSpacing(ctx)),
            ],
            _modeTile(
              ctx,
              icon: Icons.print_outlined,
              title: 'Thermal printer',
              subtitle: 'Sends ESC/POS directly. Use for receipt printers.',
              onTap: () => Navigator.pop(ctx, false),
            ),
            SizedBox(height: AppResponsive.smallSpacing(ctx)),
            _modeTile(
              ctx,
              icon: Icons.picture_as_pdf_outlined,
              title: 'PDF / document printer',
              subtitle:
                  'Sends the rendered receipt. Use for doPDF, Print to PDF.',
              onTap: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeTile(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppResponsive.borderRadius(ctx)),
      child: Container(
        padding: EdgeInsets.all(AppResponsive.mediumSpacing(ctx)),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(AppResponsive.borderRadius(ctx)),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: AppColors.primary,
                size: AppResponsive.smallIconSize(ctx)),
            SizedBox(width: AppResponsive.smallSpacing(ctx)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.bodyFontSize(ctx),
                        fontWeight: FontWeight.w600,
                      )),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: AppResponsive.smallFontSize(ctx),
                        color: AppColors.textSecondary,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testPrint(String id) async {
    final printer = printerStore.savedPrinters.firstWhere((p) => p.id == id);
    final success = await printerStore.testPrint(printer);
    if (!mounted) return;
    if (success) {
      NotificationService.instance.showSuccess('Test print sent!');
    } else {
      NotificationService.instance
          .showError(printerStore.errorMessage ?? 'Test print failed');
    }
  }

  Future<void> _confirmDelete(String id, String name) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete Printer',
      message: 'Remove "$name" from saved printers?',
      confirmLabel: 'Delete',
      accent: AppColors.danger,
      icon: Icons.delete_rounded,
    );

    if (confirmed == true) {
      await printerStore.deletePrinter(id);
      if (mounted) {
        NotificationService.instance.showSuccess('Printer removed');
      }
    }
  }
}
