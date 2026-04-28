// CLI entry: `dart run tool/init.dart`. Parses args, picks plain vs rich
// mode, hands off to the wizard runner.
//
// Args:
//   --plain        force plain prompts (no colors / spinners)
//   --rich         force rich TUI even if stdin is not a TTY
//   --skip-firebase
//   --skip-keystore
//   --skip-smoke
//   --skip-pub-get
//
// Logic lives in tool/init/runner.dart + tool/init/prompter.dart so the
// validators / YAML renderers / step orchestration are all unit-testable
// without spawning a TUI.

// ignore_for_file: always_use_package_imports

import 'dart:io';

import 'init/prompter.dart';
import 'init/runner.dart';

Future<void> main(List<String> args) async {
  final forcePlain = args.contains('--plain');
  final forceRich = args.contains('--rich');

  final useRich = forceRich || (!forcePlain && _looksLikeTty());
  final Prompter prompter = useRich ? RichPrompter() : PlainPrompter();

  // Offer the user a chance to flip modes once at the top.
  Prompter active = prompter;
  if (!forcePlain && !forceRich && _looksLikeTty()) {
    final mode = active.chooseOne(
      'How would you like the wizard to look?',
      ['Rich (colors, spinners)', 'Plain (one prompt per line)'],
      defaultValue: 'Rich (colors, spinners)',
    );
    if (mode.startsWith('Plain') && useRich) {
      active = PlainPrompter();
    } else if (mode.startsWith('Rich') && !useRich) {
      active = RichPrompter();
    }
  }

  final opts = WizardOptions(
    projectRoot: Directory.current,
    skipFirebase: args.contains('--skip-firebase'),
    skipKeystore: args.contains('--skip-keystore'),
    skipSmoke: args.contains('--skip-smoke'),
    skipPubGet: args.contains('--skip-pub-get'),
  );

  try {
    final code = await runWizard(active, opts);
    exit(code);
  } catch (e, st) {
    active.error('Wizard failed: $e');
    if (args.contains('--verbose')) stderr.writeln(st);
    exit(1);
  } finally {
    active.close();
  }
}

bool _looksLikeTty() {
  try {
    return stdin.hasTerminal;
  } catch (_) {
    return false;
  }
}
