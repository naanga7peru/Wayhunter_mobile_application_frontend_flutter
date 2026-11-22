import 'package:flutter/widgets.dart';

/// Small shared label catalog. Features provide their own copy to widgets.
class WayhunterStrings {
  const WayhunterStrings._({
    required this.retry,
    required this.cancel,
    required this.confirm,
    required this.loading,
    required this.unavailable,
  });

  final String retry;
  final String cancel;
  final String confirm;
  final String loading;
  final String unavailable;

  static const supportedLocales = [Locale('en'), Locale('ta'), Locale('si')];

  static WayhunterStrings of(BuildContext context) =>
      forLocale(Localizations.maybeLocaleOf(context) ?? const Locale('en'));

  static WayhunterStrings forLocale(Locale locale) =>
      _catalog[locale.languageCode] ?? _catalog['en']!;

  static const _catalog = {
    'en': WayhunterStrings._(
      retry: 'Retry',
      cancel: 'Cancel',
      confirm: 'Confirm',
      loading: 'Loading',
      unavailable: 'This destination is unavailable.',
    ),
    'ta': WayhunterStrings._(
      retry: 'மீண்டும் முயலவும்',
      cancel: 'ரத்துசெய்',
      confirm: 'உறுதிசெய்',
      loading: 'ஏற்றுகிறது',
      unavailable: 'இந்தப் பகுதி கிடைக்கவில்லை.',
    ),
    'si': WayhunterStrings._(
      retry: 'නැවත උත්සාහ කරන්න',
      cancel: 'අවලංගු කරන්න',
      confirm: 'තහවුරු කරන්න',
      loading: 'පූරණය වෙමින්',
      unavailable: 'මෙම කොටස ලබා ගත නොහැක.',
    ),
  };
}
