import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/notes/models/editor_args.dart';
import 'features/notes/models/note.dart';
import 'features/notes/presentation/editor_screen.dart';
import 'features/notes/presentation/notes_screen.dart';
import 'features/settings/presentation/settings_screen.dart';

// Router bir kez kurulur: tema değişince build yeniden çalışır; router her seferinde
// yaratılırsa kullanıcı (ör. Ayarlar ekranından) ana sayfaya atılırdı.
GoRouter? _router;

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePref = ref.watch(themePreferenceProvider);

    final router = _router ??= GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/notes', builder: (_, __) => const NotesScreen()),
        GoRoute(
          path: '/notes/edit',
          builder: (_, state) {
            final extra = state.extra;
            if (extra is Note) {
              return NoteEditorScreen(note: extra);
            }
            if (extra is EditorArgs) {
              return NoteEditorScreen.fromArgs(extra);
            }
            return const NoteEditorScreen();
          },
        ),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    );

    return MaterialApp.router(
      title: 'Markdown Not Defteri',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeModeFromPreference(themePref),
      routerConfig: router,
    );
  }
}
