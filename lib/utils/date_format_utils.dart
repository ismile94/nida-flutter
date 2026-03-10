import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import '../l10n/app_localizations.dart';

/// Utility for formatting Gregorian and Hijri dates in the app's active locale.
/// Hijri conversion uses the Umm al-Qura algorithm via the `hijri` package.
class DateFormatUtils {
  /// Returns the localized Hijri date string for [date].
  /// Example: "4 Ramazan 1447" (TR) · "٤ رمضان ١٤٤٧" (AR) · "4 Ramadan 1447" (EN)
  static String formatHijriDate(DateTime date, BuildContext context) {
    final h = HijriCalendar.fromDate(date);
    final months = AppLocalizations.t(context, 'hijriMonths').split(';');
    final monthName = months[(h.hMonth - 1).clamp(0, 11)];
    return '${h.hDay} $monthName ${h.hYear}';
  }

  /// Returns the localized Gregorian date string for [date].
  /// Example: "4 Mar 2026" (EN) · "4 Mar 2026" (TR) · "4 مارس 2026" (AR)
  static String formatGregorianDate(DateTime date, BuildContext context) {
    final months = AppLocalizations.t(context, 'gregorianMonths').split(';');
    final monthName = months[(date.month - 1).clamp(0, 11)];
    return '${date.day} $monthName ${date.year}';
  }
}
