import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:websight/utils/helpers.dart';

void main() {
  group('iconForString', () {
    test('returns fallback for null / empty / unknown', () {
      expect(iconForString(null), Icons.circle_outlined);
      expect(iconForString(''), Icons.circle_outlined);
      expect(iconForString('definitely_not_an_icon'), Icons.circle_outlined);
    });

    test('strips Icons. prefix and is case-insensitive', () {
      expect(iconForString('Icons.home_outlined'), Icons.home_outlined);
      expect(iconForString('HOME'), Icons.home_outlined);
    });

    test('maps common navigation/app icons', () {
      expect(iconForString('refresh'), Icons.refresh);
      expect(iconForString('search'), Icons.search);
      expect(iconForString('qr_code_scanner'), Icons.qr_code_scanner);
      expect(iconForString('settings_outlined'), Icons.settings_outlined);
    });
  });

  group('parseColor', () {
    test('returns fallback for null and malformed input', () {
      expect(parseColor(null), const Color(0x00000000));
      expect(parseColor('zzzzzz'), const Color(0x00000000));
    });

    test('parses 6-char hex with implicit alpha', () {
      expect(parseColor('#16A34A').value, 0xFF16A34A);
      expect(parseColor('16A34A').value, 0xFF16A34A);
    });

    test('parses 3-char shorthand hex', () {
      expect(parseColor('#0F0').value, 0xFF00FF00);
    });

    test('parses 8-char hex with explicit alpha', () {
      expect(parseColor('#8016A34A').value, 0x8016A34A);
    });
  });
}
