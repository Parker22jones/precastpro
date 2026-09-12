import 'package:flutter/material.dart';

import 'state/app_state.dart';
import 'ui/app_scope.dart';
import 'ui/app_shell.dart';
import 'ui/mh_theme.dart';

void main() {
  runApp(PrecastProApp(state: AppState()));
}

class PrecastProApp extends StatelessWidget {
  const PrecastProApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'PrecastPro',
        debugShowCheckedModeBanner: false,
        theme: Mh.themeData(),
        home: const AppShell(),
      ),
    );
  }
}
