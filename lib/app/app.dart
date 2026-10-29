import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/app/audio/music_controller.dart';
import 'package:up_tower_defense/app/audio/music_host.dart';
import 'package:up_tower_defense/app/router.dart';
import 'package:up_tower_defense/app/theme/app_theme.dart';
import 'package:up_tower_defense/core/constants/app_info.dart';

/// Root widget of the application shell.
///
/// Navigation, theming and localisation entry points are owned here; gameplay
/// state is never held by this widget. [MusicHost] wraps the tree so the one
/// background loop follows the music switch across every screen.
class UpTowerDefenseApp extends ConsumerWidget {
  const UpTowerDefenseApp({super.key, this.musicSink});

  /// Playback target for the background loop; null means `flame_audio`.
  /// Tests pass a recording fake so the shell never touches an audio platform.
  final MusicSink? musicSink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MusicHost(
      sink: musicSink ?? const FlameAudioMusicSink(),
      child: MaterialApp.router(
        title: AppInfo.name,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        routerConfig: router,
      ),
    );
  }
}
