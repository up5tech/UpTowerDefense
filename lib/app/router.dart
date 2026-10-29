import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_tower_defense/app/routes.dart';
import 'package:up_tower_defense/features/codex/presentation/codex_screen.dart';
import 'package:up_tower_defense/features/credits/presentation/credits_screen.dart';
import 'package:up_tower_defense/features/gameplay/presentation/gameplay_screen.dart';
import 'package:up_tower_defense/features/level_select/presentation/level_select_screen.dart';
import 'package:up_tower_defense/features/main_menu/presentation/main_menu_screen.dart';
import 'package:up_tower_defense/features/settings/presentation/settings_screen.dart';

/// Builds one router instance.
///
/// Every screen is a child of the main menu, so the menu is always the root of
/// the stack: back from any screen returns to it, and going to a screen with
/// `context.go` keeps exactly one level of history.
GoRouter createAppRouter({String initialLocation = AppRoutes.mainMenu}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.mainMenu,
        builder: (context, state) => const MainMenuScreen(),
        routes: [
          GoRoute(
            path: 'play',
            builder: (context, state) => const GameplayScreen(),
          ),
          // The endless challenge: its own route so back always returns to
          // the menu, and its own key so it remounts as a fresh run each time
          // (D62).
          GoRoute(
            path: 'endless',
            builder: (context, state) => const GameplayScreen(
              key: ValueKey('endless'),
              endless: true,
            ),
          ),
          // A sibling of `play`, not a child: opening a level must replace the
          // gameplay entry rather than stack a second gameplay screen behind it,
          // so back from a level returns to the menu in one step.
          GoRoute(
            path: 'play/:levelId',
            builder: (context, state) {
              final levelId = state.pathParameters['levelId']!;
              // A key per level: moving from one level to the next must
              // remount the screen, so a finished attempt's game and its
              // overlays never survive into the level that follows it.
              return GameplayScreen(key: ValueKey(levelId), levelId: levelId);
            },
          ),
          GoRoute(
            path: 'levels',
            builder: (context, state) => const LevelSelectScreen(),
          ),
          GoRoute(
            path: 'codex',
            builder: (context, state) => const CodexScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: 'credits',
            builder: (context, state) => const CreditsScreen(),
          ),
        ],
      ),
    ],
  );
}

/// Router for the running app.
///
/// Created once per provider container so widget tests get an isolated
/// navigation stack, and disposed with the container.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter();
  ref.onDispose(router.dispose);
  return router;
});
