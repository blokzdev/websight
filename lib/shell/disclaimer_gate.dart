import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:websight/lifecycle/disclaimer_controller.dart';

/// Wraps [child] with a first-launch unofficial-app disclaimer when
/// `legal.unofficial_disclaimer.enabled` is true. The dialog is modal
/// (non-dismissable) and either records the user's acceptance or, if
/// `require_accept` is set and the user declines, exits the app via
/// `SystemNavigator.pop()`.
///
/// When the feature is disabled, this widget is a transparent passthrough.
class DisclaimerGate extends StatefulWidget {
  const DisclaimerGate({super.key, required this.child});

  final Widget child;

  @override
  State<DisclaimerGate> createState() => _DisclaimerGateState();
}

class _DisclaimerGateState extends State<DisclaimerGate> {
  bool _dialogShown = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DisclaimerController>();
    final feature = controller.feature;

    // Disabled or already accepted -> render the app normally.
    if (!feature.enabled || controller.accepted) {
      return widget.child;
    }

    // Still loading SharedPreferences -> show a themed placeholder so we
    // never flash the WebView before deciding.
    if (!controller.loaded) {
      return _Placeholder();
    }

    // Show the dialog once the app's MaterialApp has had a chance to
    // mount its Navigator. Subsequent rebuilds (theme change, etc.) do
    // not re-trigger because _dialogShown is latched.
    if (!_dialogShown) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showDisclaimer(context, controller);
      });
    }

    // Render the placeholder under the dialog so the WebView doesn't
    // briefly leak through while the dialog is opening.
    return _Placeholder();
  }

  Future<void> _showDisclaimer(
    BuildContext context,
    DisclaimerController controller,
  ) async {
    final feature = controller.feature;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(feature.title),
            content: SingleChildScrollView(
              child: Text(
                feature.body,
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(feature.declineLabel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(feature.acceptLabel),
              ),
            ],
          ),
        );
      },
    );

    if (accepted == true) {
      await controller.markAccepted();
      return;
    }
    if (feature.requireAccept) {
      // Decline-then-exit. Re-launching the app re-prompts.
      await SystemNavigator.pop();
    } else {
      // Reset the latch so a subsequent rebuild re-prompts; this branch
      // is only reachable when require_accept is false (advisory mode).
      if (mounted) setState(() => _dialogShown = false);
    }
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
