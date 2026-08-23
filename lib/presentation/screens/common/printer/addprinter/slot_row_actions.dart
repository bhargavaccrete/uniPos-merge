import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:billberrylite/core/di/service_locator.dart';
import 'package:billberrylite/data/models/restaurant/db/saved_printer_model.dart';
import 'package:billberrylite/domain/services/restaurant/notification_service.dart';
import 'package:billberrylite/util/color.dart';

/// Saved-printer row helpers for the WiFi / Bluetooth / USB tabs when they are
/// running in "assign a slot" mode (retail, which has no Printer Management
/// screen to do it).
///
/// Saving auto-claims the slot, so without these a second saved printer would
/// silently take over with no way back — re-saving the first would just create
/// a duplicate record.

/// True when [printer] currently holds [role]. Read inside an `Observer`.
bool isActiveForSlot(SavedPrinterModel printer, String? role) {
  if (role == null) return false;
  final current = role == 'kot'
      ? printerStore.defaultKotPrinter
      : printerStore.defaultReceiptPrinter;
  return current?.id == printer.id;
}

/// "Active" pill for the row holding the slot, or null when it doesn't.
Widget? activeSlotBadge(SavedPrinterModel printer, String? role) {
  if (!isActiveForSlot(printer, role)) return null;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.success.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      'Active',
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.success,
      ),
    ),
  );
}

/// Point [role] at [printer]. No-op when the tab isn't in assign mode or the
/// printer already holds the slot.
Future<void> setActiveForSlot(SavedPrinterModel printer, String? role) async {
  if (role == null || isActiveForSlot(printer, role)) return;
  // 'both' keeps the record valid for whichever slot(s) point at it.
  await printerStore.savePrinter(printer.copyWith(role: 'both'));
  await printerStore.setDefaultForRole(printer.id, role);
  NotificationService.instance
      .showSuccess('${printer.name} is now the active printer');
}
