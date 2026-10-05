import 'package:flutter/material.dart';

import 'create_screen.dart';

/// Geriye dönük rota: `/qr` → oluştur ekranı.
class QrScreen extends StatelessWidget {
  const QrScreen({super.key, this.initialText});

  final String? initialText;

  @override
  Widget build(BuildContext context) {
    return CreateScreen(
      initialText: initialText,
      initialTab: 0,
      showBackButton: true,
    );
  }
}
