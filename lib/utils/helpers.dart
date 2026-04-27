import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Maps a YAML icon string (e.g. "Icons.home_outlined" or "home") into a real
/// [IconData]. Falls back to [Icons.circle_outlined] when no mapping exists,
/// which is more visually obvious than [Icons.web_asset] when something is
/// misconfigured.
IconData iconForString(String? iconName) {
  if (iconName == null || iconName.isEmpty) return Icons.circle_outlined;
  final normalized = iconName.toLowerCase().replaceAll('icons.', '').trim();
  return _iconLookup[normalized] ?? Icons.circle_outlined;
}

const Map<String, IconData> _iconLookup = <String, IconData>{
  // navigation
  'home': Icons.home_outlined,
  'home_outlined': Icons.home_outlined,
  'home_filled': Icons.home,
  'menu': Icons.menu,
  'close': Icons.close,
  'arrow_back': Icons.arrow_back,
  'back': Icons.arrow_back,
  'arrow_forward': Icons.arrow_forward,
  'forward': Icons.arrow_forward,
  'more_vert': Icons.more_vert,
  'more_horiz': Icons.more_horiz,
  // actions
  'search': Icons.search,
  'refresh': Icons.refresh,
  'add': Icons.add,
  'remove': Icons.remove,
  'edit': Icons.edit,
  'delete': Icons.delete_outline,
  'share': Icons.share,
  'download': Icons.download,
  'upload': Icons.upload,
  'qr_code_scanner': Icons.qr_code_scanner,
  'camera': Icons.camera_alt_outlined,
  // status
  'check': Icons.check,
  'error': Icons.error_outline,
  'info': Icons.info_outline,
  'warning': Icons.warning_amber_outlined,
  // user
  'person': Icons.person_outline,
  'account_circle': Icons.account_circle,
  'account_balance_wallet': Icons.account_balance_wallet_outlined,
  'account_balance_wallet_outlined': Icons.account_balance_wallet_outlined,
  // app
  'settings': Icons.settings_outlined,
  'settings_outlined': Icons.settings_outlined,
  'star': Icons.star_border,
  'star_border': Icons.star_border,
  'star_filled': Icons.star,
  'work': Icons.work_outline,
  'notifications': Icons.notifications_none,
  'notifications_none': Icons.notifications_none,
  'add_alert': Icons.add_alert,
  'public': Icons.public,
  // feedback / info
  'thumb_up': Icons.thumb_up_off_alt,
  'thumb_up_off_alt': Icons.thumb_up_off_alt,
  'privacy_tip': Icons.privacy_tip_outlined,
  'privacy_tip_outlined': Icons.privacy_tip_outlined,
  'help': Icons.help_outline,
  'feedback': Icons.feedback_outlined,
};

/// Parses a hex color (with or without leading `#`) into a [Color]. Supports
/// 3, 6 and 8 hex characters; 8-char form encodes alpha first. Returns
/// [fallback] (defaults to fully-transparent) on parse failure and emits a
/// debug-only warning so a typo in YAML doesn't silently render invisible
/// surfaces in production but also doesn't spam release logs.
Color parseColor(String? hex, {Color fallback = const Color(0x00000000)}) {
  if (hex == null) return fallback;
  var v = hex.trim().toUpperCase().replaceAll('#', '');
  if (v.isEmpty) {
    if (kDebugMode) debugPrint('parseColor: empty value; using fallback');
    return fallback;
  }
  if (v.length == 3) {
    v = v.split('').map((c) => '$c$c').join();
  }
  if (v.length == 6) v = 'FF$v';
  final parsed = int.tryParse(v, radix: 16);
  if (parsed == null) {
    if (kDebugMode) {
      debugPrint('parseColor: could not parse "$hex"; using fallback');
    }
    return fallback;
  }
  return Color(parsed);
}
