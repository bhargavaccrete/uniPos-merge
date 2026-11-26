import 'package:flutter/material.dart';

import 'package:billberrylite/domain/services/common/notification_service.dart';
import 'package:billberrylite/domain/services/retail/retail_day_gate.dart';
import 'package:billberrylite/presentation/widget/restaurant/opening_balance_dialog.dart';

/// Checked when a return, exchange or credit collection is submitted — the
/// same day rule billing uses ([RetailDayGate]), with the same handling:
/// an End of Day still pending stops it; no day open offers Start Day here
/// rather than bouncing the user out to Settings.
///
/// The services refuse these too; this is what lets the user act on it.
Future<bool> ensureRetailDayOpen(BuildContext context) async {
  final block = await RetailDayGate.check();
  if (block == null) return true;

  if (block == RetailDayBlock.dayNotStarted && context.mounted) {
    final started = await promptStartDay(context);
    if (started == true && await RetailDayGate.check() == null) return true;
  }

  NotificationService.instance.showError(RetailDayGate.messageFor(block));
  return false;
}
