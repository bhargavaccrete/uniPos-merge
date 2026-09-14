import 'package:flutter/material.dart';

/// Pushes [page] onto the NEAREST enclosing [Navigator] rather than the root.
///
/// This is what keeps a pushed screen inside the surface that opened it. The
/// setup wizard installs its own `Navigator` around the desktop content pane,
/// so a screen opened from a step (Added Items, Category Selection, Bulk
/// Import…) renders beside the sidebar instead of covering the whole window.
/// On mobile and tablet there is no such pane, so the nearest navigator IS the
/// root and the page opens full-screen — which is what you want there.
///
/// `Navigator.push(context, ...)` already resolves to the nearest navigator;
/// this wrapper exists so call sites don't hand-roll a [MaterialPageRoute],
/// and so the reason the containment works is documented in one place.
///
/// The page needs no changes either way: it keeps its own `Scaffold`/`AppBar`,
/// and `Navigator.pop(context, result)` returns through [T] as usual.
///
/// Dialogs and sheets opened from inside a pane should pass
/// `useRootNavigator: false` so they land on the pane too — otherwise they
/// cover the surrounding chrome and centre on the whole window rather than on
/// the content. The `showApp*Dialog` helpers in `app_dialog.dart` already do
/// this; raw `showDialog`/`showModalBottomSheet` calls must opt in. It is a
/// no-op wherever there is no nested navigator.
///
/// Once a modal is on the pane navigator, a plain `Navigator.pop(context)`
/// from a widget inside that pane closes it — no `rootNavigator: true`. Guard
/// deferred pops (a loading spinner dismissed after an await) with
/// `Navigator.of(context).canPop()`, since the route may already be gone.
Future<T?> pushResponsive<T>(BuildContext context, Widget page) {
  return Navigator.push<T>(
    context,
    MaterialPageRoute<T>(builder: (_) => page),
  );
}
