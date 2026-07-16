import 'package:flutter/widgets.dart';

/// Owns dialog-/sheet-scoped [ChangeNotifier]s (TextEditingControllers,
/// FocusNodes, …) and disposes them in its own [dispose] — which runs only when
/// the dialog subtree unmounts, i.e. AFTER the exit animation.
///
/// Use this instead of disposing controllers in `showDialog(...).then(...)`:
/// `.then` fires at pop-start, while the text fields are still mounted, so
/// disposing their controllers/focus nodes there throws the framework's
/// `_dependents.isEmpty` assertion when the dialog is closed without saving.
///
/// ```dart
/// showDialog(
///   context: context,
///   builder: (_) => DialogDisposeScope(
///     disposables: [nameController, nameFocus],
///     child: AppDialogShell(...),
///   ),
/// );
/// ```
class DialogDisposeScope extends StatefulWidget {
  final List<ChangeNotifier> disposables;
  final Widget child;

  const DialogDisposeScope({
    super.key,
    required this.disposables,
    required this.child,
  });

  @override
  State<DialogDisposeScope> createState() => _DialogDisposeScopeState();
}

class _DialogDisposeScopeState extends State<DialogDisposeScope> {
  @override
  void dispose() {
    for (final d in widget.disposables) {
      d.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
