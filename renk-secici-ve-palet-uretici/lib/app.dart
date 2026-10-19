import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'presentation/palette_screen.dart';

class PaletteApp extends StatelessWidget {
  const PaletteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Palet Üretici',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const PaletteScreen(),
    );
  }
}
