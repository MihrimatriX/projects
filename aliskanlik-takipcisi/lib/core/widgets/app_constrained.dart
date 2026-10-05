import 'package:flutter/material.dart';

class AppConstrained extends StatelessWidget {
  const AppConstrained({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width >= 1024 ? 960.0 : width >= 768 ? 720.0 : 480.0;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
