import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/pantry/presentation/pantry_screen.dart';
import 'features/planner/presentation/planner_screen.dart';
import 'features/recipes/presentation/recipe_detail_screen.dart';
import 'features/recipes/presentation/recipes_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/shopping/presentation/shopping_screen.dart';
import 'features/shell/app_shell.dart';

final appRouter = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/recipes', builder: (_, __) => const RecipesScreen()),
        GoRoute(
          path: '/recipes/:id',
          builder: (_, state) => RecipeDetailScreen(recipeId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/planner', builder: (_, __) => const PlannerScreen()),
        GoRoute(path: '/shopping', builder: (_, __) => const ShoppingScreen()),
        GoRoute(path: '/pantry', builder: (_, __) => const PantryScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    ),
  ],
);

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(themeModeProvider);
    final mode = themeAsync.value ?? AppThemeMode.light;
    final platform = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final resolved = resolveAppTheme(mode, platform);

    return MaterialApp.router(
      title: 'Yemek Planlayıcı',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: resolved.mode,
      routerConfig: appRouter,
    );
  }
}
