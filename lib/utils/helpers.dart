import 'package:flutter/material.dart';

/// A utility function to map string icon names from the configuration
/// to the actual `IconData` from the Material Icons library.
IconData iconForString(String iconName) {
  // Normalize the input to be safe.
  final String normalizedIconName =
      iconName.toLowerCase().replaceAll('icons.', '');

  switch (normalizedIconName) {
    // General & Navigation
    case 'home':
    case 'home_outlined':
      return Icons.home_outlined;
    case 'settings':
    case 'settings_outlined':
      return Icons.settings_outlined;
    case 'search':
      return Icons.search;
    case 'refresh':
      return Icons.refresh;
    case 'add':
      return Icons.add;
    case 'menu':
      return Icons.menu;
    case 'close':
      return Icons.close;
    case 'back':
      return Icons.arrow_back;
    case 'forward':
      return Icons.arrow_forward;

    // User & Account
    case 'person':
    case 'account_circle':
      return Icons.account_circle;
    case 'account_balance_wallet':
    case 'account_balance_wallet_outlined':
      return Icons.account_balance_wallet_outlined;

    // App Features
    case 'star':
    case 'star_border':
      return Icons.star_border;
    case 'work':
      return Icons.work;
    case 'notifications':
    case 'notifications_none':
      return Icons.notifications_none;
    case 'alerts':
    case 'add_alert':
      return Icons.add_alert;
    case 'qr_code_scanner':
      return Icons.qr_code_scanner;
    case 'public':
      return Icons.public;

    // Feedback & Info
    case 'thumb_up':
    case 'thumb_up_off_alt':
      return Icons.thumb_up_off_alt;
    case 'privacy_tip':
    case 'privacy_tip_outlined':
      return Icons.privacy_tip_outlined;
    case 'info':
      return Icons.info_outline;

    // Default fallback icon
    default:
      return Icons.web_asset;
  }
}

/// Parses a hex color string (e.g., "#RRGGBB" or "RRGGBB") into a `Color` object.
Color parseColor(String hexColor) {
  hexColor = hexColor.toUpperCase().replaceAll("#", "");
  if (hexColor.length == 6) {
    // Add the alpha channel.
    hexColor = "FF$hexColor";
  }
  // `int.parse` with radix 16 is used to convert the hex string to an integer.
  return Color(int.parse(hexColor, radix: 16));
}
