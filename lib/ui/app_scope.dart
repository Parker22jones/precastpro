import 'package:flutter/widgets.dart';

import '../state/app_state.dart';

/// Makes the single [AppState] store available to the whole widget tree and
/// rebuilds dependents whenever engineering, logistics or inventory changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope?.notifier != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }
}
