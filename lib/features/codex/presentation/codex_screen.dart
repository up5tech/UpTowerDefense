import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/features/codex/application/codex_providers.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_level_stats.dart';
import 'package:up_tower_defense/shared/layout/menu_layout.dart';

/// The codex: every tower and enemy the campaign ships, explained from the
/// catalogs the simulation itself reads.
///
/// Each entry shows the authored numbers and turns the traits that are not
/// plain numbers (splash, slow, leak damage) into a sentence, so a player can
/// learn why a tower or enemy behaves the way it does without opening a level.
/// Nothing here is computed balance: the screen only reads definitions, so it
/// can never drift from what a session builds with (PLAN Phase 11).
class CodexScreen extends ConsumerStatefulWidget {
  const CodexScreen({super.key});

  @override
  ConsumerState<CodexScreen> createState() => _CodexScreenState();
}

class _CodexScreenState extends ConsumerState<CodexScreen> {
  _Section _section = _Section.towers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = ref.watch(codexContentProvider);

    // A toggle rather than a TabBar: the menu frame scrolls one column, and a
    // TabBarView would need a bounded height inside it.
    return MenuLayout(
      title: 'Codex',
      children: [
        Text(
          'What each tower and enemy does, read from the same data the game '
          'plays with.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        SegmentedButton<_Section>(
          segments: const [
            ButtonSegment(
              value: _Section.towers,
              label: Text('Towers'),
              icon: Icon(Icons.castle),
            ),
            ButtonSegment(
              value: _Section.enemies,
              label: Text('Enemies'),
              icon: Icon(Icons.directions_run),
            ),
          ],
          selected: {_section},
          onSelectionChanged: (selection) {
            setState(() => _section = selection.first);
          },
        ),
        const SizedBox(height: 12),
        ...content.when(
          loading: () => [
            Text(
              'Loading codex…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          error: (error, stackTrace) => [
            Text(
              'The codex could not be read: $error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          data: (codex) => [
            if (_section == _Section.towers) ...[
              for (final tower in codex.towers.all) _TowerEntry(tower: tower),
            ] else ...[
              Text(
                'Speeds are world units per second against routes of roughly '
                '1,500–2,000 units.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final enemy in codex.enemies.all) _EnemyEntry(enemy: enemy),
            ],
          ],
        ),
      ],
    );
  }
}

enum _Section { towers, enemies }

/// One tower: identity, base stats and the upgrade path, all from the
/// definition.
class _TowerEntry extends StatelessWidget {
  const _TowerEntry({required this.tower});

  final TowerDefinition tower;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = tower.baseStats;
    final slow = stats.slow;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tower.displayName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _Chip(label: 'Cost ${tower.buildCost} g'),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              tower.role,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(tower.description, style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(label: 'Damage ${_formatStat(stats.damage)}'),
                _Chip(label: 'Range ${_formatStat(stats.range)}'),
                _Chip(
                  label: 'Fire ${_formatStat(stats.fireCooldownSeconds)}s',
                ),
                if (stats.splashRadius > 0)
                  _Chip(label: 'Blast ${_formatStat(stats.splashRadius)}'),
                if (slow != null) _Chip(label: _slowLabel(slow)),
                _Chip(
                  label: 'Sell ${(tower.sellRefundRate * 100).round()}% back',
                ),
              ],
            ),
            if (stats.splashRadius > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Shells explode, damaging every enemy within '
                '${_formatStat(stats.splashRadius)} units of the impact.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (slow != null) ...[
              const SizedBox(height: 8),
              Text(
                _slowTraitLine(slow),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _upgradePath(tower),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One enemy: identity, the numbers a wave is tuned by, and what leaking one
/// costs the player.
class _EnemyEntry extends StatelessWidget {
  const _EnemyEntry({required this.enemy});

  final EnemyDefinition enemy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leak =
        'Reaching the core costs ${enemy.coreDamageOnLeak} core '
        '${enemy.coreDamageOnLeak == 1 ? 'health' : 'health points'}.';
    final reward = enemy.rewardGold > 0
        ? 'A kill pays ${enemy.rewardGold} g; a leak pays nothing.'
        : 'It pays nothing when killed, and a leak pays nothing either. ';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(enemy.displayName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(label: 'Health ${_formatStat(enemy.maxHealth)}'),
                _Chip(label: 'Speed ${_formatStat(enemy.speed)}/s'),
                _Chip(label: 'Size ${_formatStat(enemy.radius)}'),
                _Chip(label: 'Core damage ${enemy.coreDamageOnLeak}'),
                _Chip(label: 'Kill reward ${enemy.rewardGold} g'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$leak $reward',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label, style: theme.textTheme.labelMedium),
      ),
    );
  }
}

/// Whole numbers print without a trailing `.0`; everything else keeps one
/// decimal, which is all the authored balance uses.
String _formatStat(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

/// The slow chip: magnitude and duration together, matching the tower panel.
String _slowLabel(SlowSpec slow) {
  final percent = (slow.magnitude * 100).round();
  return 'Slow $percent% / ${_formatStat(slow.durationSeconds)}s';
}

/// The slow trait sentence: what the chill does to movement, its damage
/// amplifier when the level has one, and the speed floor the design promises.
///
/// Every number is read from the spec, so the codex cannot describe a slow the
/// simulation would not apply.
String _slowTraitLine(SlowSpec slow) {
  final amp = slow.damageAmp > 0
      ? ', and the chill makes them take '
            '${(slow.damageAmp * 100).round()}% more damage from every tower'
      : '';
  return 'Each hit slows by ${(slow.magnitude * 100).round()}% for '
      '${_formatStat(slow.durationSeconds)}s$amp; enemies never drop below '
      '${(slow.minSpeedRatio * 100).round()}% of their speed.';
}

/// The upgrade line under a tower's stats.
///
/// Every later level is listed with its damage and its cost, so the codex
/// shows the whole curve instead of only the base — a player can see whether a
/// tower is worth investing in before spending a single gold piece.
String _upgradePath(TowerDefinition tower) {
  if (tower.maxLevel == 1) {
    return 'Single level — this tower has no upgrades.';
  }

  final steps = <String>[];
  for (var level = 1; level < tower.levels.length; level++) {
    final stats = tower.levelAt(level + 1);
    final cost = tower.upgradeCostFor(level);
    steps.add(
      'Lv${level + 1}: ${_formatStat(stats.damage)} dmg'
      '${cost == null ? '' : ' for $cost g'}',
    );
  }
  return 'Upgrades — ${steps.join(' · ')}';
}
