// Two prompter implementations behind one interface so the wizard logic
// in `runner.dart` doesn't care whether stdout is a TTY:
//
//   * `PlainPrompter` — bare stdin/stdout, no colors, no spinners. Works
//     in CI logs, dumb terminals, and Windows cmd.
//   * `RichPrompter` — wraps `mason_logger` for colored prompts and
//     spinner-driven progress reporting. Used when the user has a TTY
//     and didn't pass `--plain`.
//
// `tool/init.dart` picks one based on stdin.hasTerminal + flags.

// ignore_for_file: always_use_package_imports

import 'dart:async';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

abstract class Prompter {
  /// Free-text input. [validator] returns null on success, an error
  /// message on failure; the prompter loops until valid.
  String text(
    String label, {
    String? defaultValue,
    String? Function(String)? validator,
  });

  /// Yes/no.
  bool confirm(String label, {required bool defaultValue});

  /// Single choice from [choices]. Default is the first item unless
  /// [defaultValue] is set.
  String chooseOne(
    String label,
    List<String> choices, {
    String? defaultValue,
  });

  /// Password / secret input. Echo is suppressed.
  String password(String label);

  // --- Output ---
  void info(String message);
  void success(String message);
  void warn(String message);
  void error(String message);

  /// A visually-distinct section header.
  void section(String title);

  /// Wraps an async [task] in a progress indicator. The plain prompter
  /// just prints `... <label>` and `done` on success.
  Future<T> progress<T>(String label, Future<T> Function() task);

  /// Final flush / cleanup hook.
  void close() {}
}

class PlainPrompter extends Prompter {
  PlainPrompter({this.stdin_, this.stdout_});

  final Stdin? stdin_;
  final Stdout? stdout_;

  Stdin get _in => stdin_ ?? stdin;
  IOSink get _out => stdout_ ?? stdout;

  @override
  String text(
    String label, {
    String? defaultValue,
    String? Function(String)? validator,
  }) {
    while (true) {
      final defaultPart = (defaultValue == null || defaultValue.isEmpty)
          ? ''
          : ' [$defaultValue]';
      _out.write('$label$defaultPart: ');
      final raw = _in.readLineSync()?.trim() ?? '';
      final value = raw.isEmpty ? (defaultValue ?? '') : raw;
      final err = validator?.call(value);
      if (err == null) return value;
      _out.writeln('  ! $err');
    }
  }

  @override
  bool confirm(String label, {required bool defaultValue}) {
    final hint = defaultValue ? '[Y/n]' : '[y/N]';
    while (true) {
      _out.write('$label $hint ');
      final raw = (_in.readLineSync() ?? '').trim().toLowerCase();
      if (raw.isEmpty) return defaultValue;
      if (raw == 'y' || raw == 'yes') return true;
      if (raw == 'n' || raw == 'no') return false;
      _out.writeln('  ! please answer y or n');
    }
  }

  @override
  String chooseOne(
    String label,
    List<String> choices, {
    String? defaultValue,
  }) {
    if (choices.isEmpty) {
      throw ArgumentError('chooseOne: choices must be non-empty');
    }
    final fallback = defaultValue ?? choices.first;
    while (true) {
      _out.writeln(label);
      for (var i = 0; i < choices.length; i++) {
        final mark = choices[i] == fallback ? '*' : ' ';
        _out.writeln('  $mark ${i + 1}. ${choices[i]}');
      }
      _out.write('Choice [${choices.indexOf(fallback) + 1}]: ');
      final raw = (_in.readLineSync() ?? '').trim();
      if (raw.isEmpty) return fallback;
      final n = int.tryParse(raw);
      if (n != null && n >= 1 && n <= choices.length) return choices[n - 1];
      _out.writeln('  ! enter a number between 1 and ${choices.length}');
    }
  }

  @override
  String password(String label) {
    _out.write('$label: ');
    // Suppress echo on POSIX-y terminals via stdin.echoMode.
    final wasEcho = _in.echoMode;
    try {
      _in.echoMode = false;
    } catch (_) {
      // Some terminals don't support it; fall through with echo.
    }
    final raw = _in.readLineSync() ?? '';
    try {
      _in.echoMode = wasEcho;
    } catch (_) {/* ignore */}
    _out.writeln();
    return raw;
  }

  @override
  void info(String message) => _out.writeln(message);

  @override
  void success(String message) => _out.writeln('OK $message');

  @override
  void warn(String message) => _out.writeln('!! $message');

  @override
  void error(String message) => _out.writeln('xx $message');

  @override
  void section(String title) {
    _out.writeln();
    _out.writeln('== $title ==');
  }

  @override
  Future<T> progress<T>(String label, Future<T> Function() task) async {
    _out.writeln('... $label');
    final result = await task();
    _out.writeln('OK $label');
    return result;
  }
}

class RichPrompter extends Prompter {
  RichPrompter() : _logger = Logger();

  final Logger _logger;

  @override
  String text(
    String label, {
    String? defaultValue,
    String? Function(String)? validator,
  }) {
    while (true) {
      final raw = _logger
          .prompt(
            label,
            defaultValue: defaultValue,
          )
          .trim();
      final value = raw.isEmpty ? (defaultValue ?? '') : raw;
      final err = validator?.call(value);
      if (err == null) return value;
      _logger.err(err);
    }
  }

  @override
  bool confirm(String label, {required bool defaultValue}) {
    return _logger.confirm(label, defaultValue: defaultValue);
  }

  @override
  String chooseOne(
    String label,
    List<String> choices, {
    String? defaultValue,
  }) {
    return _logger.chooseOne<String>(
      label,
      choices: choices,
      defaultValue: defaultValue ?? choices.first,
    );
  }

  @override
  String password(String label) {
    return _logger.prompt(label, hidden: true);
  }

  @override
  void info(String message) => _logger.info(message);

  @override
  void success(String message) => _logger.success(message);

  @override
  void warn(String message) => _logger.warn(message);

  @override
  void error(String message) => _logger.err(message);

  @override
  void section(String title) {
    _logger
      ..info('')
      ..info(styleBold.wrap(styleUnderlined.wrap(title)) ?? title);
  }

  @override
  Future<T> progress<T>(String label, Future<T> Function() task) async {
    final p = _logger.progress(label);
    try {
      final result = await task();
      p.complete(label);
      return result;
    } catch (e) {
      p.fail(label);
      rethrow;
    }
  }
}
