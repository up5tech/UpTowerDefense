import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/app/audio/music_controller.dart';
import 'package:up_tower_defense/features/settings/application/settings_providers.dart';

/// Runs the background loop for the whole shell.
///
/// Wraps the app's root so one instance covers menus and gameplay: the loop
/// starts from the saved switch on the first frame, and a toggle in Settings
/// mutes or resumes it live through the same controller.
class MusicHost extends ConsumerStatefulWidget {
  const MusicHost({
    required this.child,
    super.key,
    this.sink = const FlameAudioMusicSink(),
  });

  final Widget child;

  /// Playback target; tests pass a recording fake so the shell never touches
  /// an audio platform.
  final MusicSink sink;

  @override
  ConsumerState<MusicHost> createState() => _MusicHostState();
}

class _MusicHostState extends ConsumerState<MusicHost> {
  /// Injectable for tests through [MusicHost.sink]; production uses
  /// `flame_audio`.
  late final MusicController _music = MusicController(sink: widget.sink);

  @override
  void initState() {
    super.initState();
    // The persisted switch decides on the first frame whether the loop starts
    // at all — a player who turned music off never hears a blip at boot — and
    // the saved volume is in place before that first start.
    final settings = ref.read(settingsProvider);
    _music.setVolume(settings.musicVolume);
    _music.setEnabled(enabled: settings.musicEnabled);
  }

  @override
  Widget build(BuildContext context) {
    // Only a real change reaches the controller, and it ignores repeats, so
    // unrelated rebuilds cost nothing.
    ref.listen(
      settingsProvider.select((settings) => settings.musicEnabled),
      (previous, next) => _music.setEnabled(enabled: next),
    );
    // Loudness follows the slider live, playing or not: a stopped loop simply
    // remembers the new value until it starts.
    ref.listen(
      settingsProvider.select((settings) => settings.musicVolume),
      (previous, next) => _music.setVolume(next),
    );
    return widget.child;
  }

  @override
  void dispose() {
    // The host unmounts only when the app itself goes away; leaving a global
    // player running past that would outlive the shell that chose it.
    _music.setEnabled(enabled: false);
    super.dispose();
  }
}
