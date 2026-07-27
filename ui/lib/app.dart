import 'package:flutter/material.dart';

import 'features/editor/editor_screen.dart';

class ProShottrApp extends StatelessWidget {
  const ProShottrApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF0B0E13);
    const surface = Color(0xFF161B23);
    const accent = Color(0xFFFF4D67);

    return MaterialApp(
      title: 'ProShottr',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: surface,
        ),
        fontFamily: 'Segoe UI',
        tooltipTheme: const TooltipThemeData(
          waitDuration: Duration(milliseconds: 450),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const EditorScreen(),
    );
  }
}
