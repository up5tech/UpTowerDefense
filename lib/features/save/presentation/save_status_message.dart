import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/features/save/application/save_providers.dart';
import 'package:up_tower_defense/features/save/data/save_repository.dart';

/// The outcome of the last save load, as one line of player-facing text.
///
/// A normal launch says where progress lives; a load that had to fall back says
/// exactly what was preserved instead. The menu and the settings screen share
/// this widget so the two can never describe the same load differently, and
/// both watch the provider rather than a copy of it.
class SaveStatusMessage extends ConsumerWidget {
  const SaveStatusMessage({super.key, this.onlyWhenDegraded = false});

  /// Whether to render nothing at all when the load was healthy.
  ///
  /// The menu passes this: a warning belongs on the first screen the player
  /// sees, but a routine "saved on this device" line there is noise. Settings
  /// shows the line either way, because the player opened it to look at
  /// storage on purpose.
  final bool onlyWhenDegraded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(saveStatusProvider);
    final theme = Theme.of(context);
    final healthy = status.problem == null;
    if (onlyWhenDegraded && healthy) {
      return const SizedBox.shrink();
    }

    return Text(
      messageFor(status),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: healthy
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.error,
      ),
    );
  }

  /// Player-facing wording for one load result.
  static String messageFor(SaveLoadReport status) {
    final problem = status.problem;
    if (problem == null) {
      return 'Progress is saved on this device.';
    }
    switch (status.origin) {
      case SaveOrigin.backup:
        return 'Your newest save could not be read, so progress was restored '
            'from an earlier copy. ($problem)';
      case SaveOrigin.empty:
        return 'Your save could not be read, so this session started fresh. '
            'The unreadable data was kept. ($problem)';
      case SaveOrigin.fresh:
      case SaveOrigin.current:
        return 'Progress could not be saved: $problem';
    }
  }
}
