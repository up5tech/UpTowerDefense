import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/features/save/application/save_providers.dart';

/// The player's best endless run, measured in fully cleared waves (D62).
///
/// Seeded from the save loaded at bootstrap, so a relaunch picks up the last
/// record; the endless result panel reads it through this provider, exactly
/// the way the campaign picker reads progress.
final NotifierProvider<EndlessBestNotifier, int> endlessBestProvider =
    NotifierProvider<EndlessBestNotifier, int>(EndlessBestNotifier.new);

/// Owns the best-run score and persists each new record.
class EndlessBestNotifier extends Notifier<int> {
  @override
  int build() => ref.watch(initialSaveProvider).endlessBest;

  /// Records [waves] when it beats the stored best.
  ///
  /// A worse run leaves the state untouched, so listeners are not notified
  /// for a score that changes nothing and nothing is written — the same
  /// "saves never touch the frame loop" rule the campaign progress follows.
  void recordBest(int waves) {
    if (waves <= state) {
      return;
    }
    state = waves;
    _persist();
  }

  /// Writes the new record through the save repository.
  ///
  /// A failed write is logged rather than surfaced: a score that could not be
  /// stored must still stand for the rest of the session.
  void _persist() {
    try {
      unawaited(ref.read(saveRepositoryProvider).saveEndlessBest(state));
    } on Object catch (error) {
      debugPrint('Failed to save the endless best: $error');
    }
  }
}
