import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/home_widget_service.dart';
import 'core/notification_service.dart';

Future<void> main() async {
  await bootstrap();
  await NotificationService.init();
  await HomeWidgetService.init();
  runApp(const ProviderScope(child: MyApp()));
}
