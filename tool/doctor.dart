// `dart run tool/doctor.dart` — surveys toolchain + project state and
// prints a pass/warn/fail report. Exits 0 when all checks pass or only
// warnings, 1 if any hard fail (missing flutter, manifest mismatches,
// etc.). Use in CI as an early sanity check, or locally before a
// release build.

// ignore_for_file: always_use_package_imports

import 'dart:io';

import 'doctor_lib.dart';

Future<void> main(List<String> args) async {
  final useColor = !args.contains('--plain') && _looksLikeTty();
  final results = await runAllChecks(Directory.current);

  stdout.writeln(_paint('WebSight doctor', _bold, useColor));
  for (final r in results) {
    stdout.writeln(_format(r, useColor));
    if (r.fix != null && r.status != DoctorStatus.ok) {
      stdout.writeln('       fix: ${r.fix}');
    }
  }

  final fails = results.where((r) => r.isHardFail).length;
  final warns = results
      .where((r) => r.status == DoctorStatus.warn)
      .length;

  stdout.writeln('');
  stdout.writeln('Summary: '
      '${results.length - fails - warns} ok, $warns warn, $fails fail');
  exit(fails == 0 ? 0 : 1);
}

String _format(DoctorResult r, bool color) {
  final marker = switch (r.status) {
    DoctorStatus.ok => _paint('[ OK ]', _green, color),
    DoctorStatus.warn => _paint('[WARN]', _yellow, color),
    DoctorStatus.fail => _paint('[FAIL]', _red, color),
    DoctorStatus.info => _paint('[INFO]', _cyan, color),
  };
  return '$marker ${r.label.padRight(16)} ${r.detail}';
}

String _paint(String s, String code, bool useColor) {
  if (!useColor) return s;
  return '$code$s[0m';
}

bool _looksLikeTty() {
  try {
    return stdout.hasTerminal;
  } catch (_) {
    return false;
  }
}

const _bold = '[1m';
const _green = '[32m';
const _yellow = '[33m';
const _red = '[31m';
const _cyan = '[36m';
