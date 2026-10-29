import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';

/// Everything the codex can explain: the two shared catalogs, loaded once.
///
/// The codex opens from the menu, where no level exists yet, so it reads the
/// same catalogs a level would resolve — the screen can therefore never show
/// stats that differ from what a session builds with.
@immutable
class CodexContent {
  const CodexContent({required this.towers, required this.enemies});

  /// Every tower the player may build, ordered by build cost.
  final TowerCatalog towers;

  /// Every enemy the campaign can spawn, ordered by id.
  final EnemyCatalog enemies;
}
