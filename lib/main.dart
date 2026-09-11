import 'package:flutter/material.dart';

import 'state/design_state.dart';
import 'ui/home_page.dart';

void main() {
  runApp(PrecastProApp(design: DesignState()));
}

class PrecastProApp extends StatelessWidget {
  const PrecastProApp({super.key, required this.design});

  final DesignState design;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrecastPro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B3A57)),
        useMaterial3: true,
        cardTheme: const CardThemeData(elevation: 1, margin: EdgeInsets.zero),
        inputDecorationTheme: const InputDecorationTheme(filled: false),
      ),
      home: HomePage(design: design),
    );
  }
}
