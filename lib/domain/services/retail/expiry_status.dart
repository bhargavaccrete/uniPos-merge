/// Expiry classification for a retail variant — **the one rule**.
///
/// Deliberately dependency-light: no Hive, no GetIt, no MobX, so it is fully
/// unit-testable. Every screen, badge and alert routes through
/// [expiryStatusFor] so the inventory list, the product detail badge and the
/// Expiry Alerts screen can never disagree. (`StockAlertService._isCritical`
/// re-implementing `ProductStore.statusFor` is exactly the duplication this
/// avoids.)
///
/// Not batch tracking: one date per variant, no lots, no FEFO.
library;

import 'package:flutter/material.dart';

import 'package:billberrylite/util/color.dart';

/// Where a variant sits relative to its expiry date.
///
/// Top-level rather than nested on a store — `ProductStore` is a mixin
/// application (`= _ProductStore with _$ProductStore`), so members declared on
/// the private base class are unreachable through it.
enum RetailExpiryStatus {
  /// No expiry date set. The default for every pre-existing variant.
  noExpiry,

  /// Expiry date is in the past.
  expired,

  /// Expiry date is today. Still sellable — the stock has not gone off yet —
  /// but it is the last day, so it alerts.
  expiringToday,

  /// Expiry falls within [kExpiryWarningDays] of today.
  expiringSoon,

  /// Expiry is set and comfortably in the future.
  valid,
}

/// How many days before expiry a variant starts warning.
///
/// Deliberately ONE constant rather than a SharedPreferences key: retail
/// already carries a `stock_alerts_enabled` pref with zero consumers, and a
/// second dead switch would be worse than a plain constant. Every caller
/// routes through here, so making it configurable later is a one-line change
/// at this single site.
const int kExpiryWarningDays = 7;

/// Strips the time component so expiry behaves as a CALENDAR DAY.
///
/// Without this, "expires today" would flip to Expired at an arbitrary hour,
/// and a date picked at 14:00 would compare differently to one picked at 09:00.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Classifies [expiry] as of [asOf] (defaults to now).
///
/// Comparison is by calendar day, so the boundaries are exact: the day itself
/// is [RetailExpiryStatus.expiringToday], `asOf + warningDays` is still
/// [RetailExpiryStatus.expiringSoon], and one day beyond that is
/// [RetailExpiryStatus.valid].
RetailExpiryStatus expiryStatusFor(
  DateTime? expiry, {
  DateTime? asOf,
  int warningDays = kExpiryWarningDays,
}) {
  if (expiry == null) return RetailExpiryStatus.noExpiry;

  final today = dateOnly(asOf ?? DateTime.now());
  final day = dateOnly(expiry);

  if (day.isBefore(today)) return RetailExpiryStatus.expired;
  if (day.isAtSameMomentAs(today)) return RetailExpiryStatus.expiringToday;

  final warnUntil = today.add(Duration(days: warningDays));
  // `!isAfter` so the final warning day is inclusive.
  if (!day.isAfter(warnUntil)) return RetailExpiryStatus.expiringSoon;

  return RetailExpiryStatus.valid;
}

/// Whole days from [asOf] until [expiry]; negative once expired, 0 on the day.
/// Null when there is no expiry date.
int? daysUntilExpiry(DateTime? expiry, {DateTime? asOf}) {
  if (expiry == null) return null;
  final today = dateOnly(asOf ?? DateTime.now());
  return dateOnly(expiry).difference(today).inDays;
}

extension RetailExpiryStatusX on RetailExpiryStatus {
  /// True when this status belongs on the Expiry Alerts screen and in the
  /// dashboard badge count. The single definition of "is alerting".
  bool get isAlerting =>
      this == RetailExpiryStatus.expired ||
      this == RetailExpiryStatus.expiringToday ||
      this == RetailExpiryStatus.expiringSoon;

  /// True when the goods are past their date.
  bool get isExpired => this == RetailExpiryStatus.expired;

  /// Short label for pills and list badges.
  String get label {
    switch (this) {
      case RetailExpiryStatus.noExpiry:
        return 'No Expiry';
      case RetailExpiryStatus.expired:
        return 'Expired';
      case RetailExpiryStatus.expiringToday:
        return 'Expires Today';
      case RetailExpiryStatus.expiringSoon:
        return 'Expiring Soon';
      case RetailExpiryStatus.valid:
        return 'Valid';
    }
  }

  /// Severity colour, following the danger/warning/success convention the
  /// retail availability pill already uses.
  Color get color {
    switch (this) {
      case RetailExpiryStatus.expired:
        return AppColors.danger;
      case RetailExpiryStatus.expiringToday:
      case RetailExpiryStatus.expiringSoon:
        return AppColors.warning;
      case RetailExpiryStatus.valid:
        return AppColors.success;
      case RetailExpiryStatus.noExpiry:
        return AppColors.textSecondary;
    }
  }
}
