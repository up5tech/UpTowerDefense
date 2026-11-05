import 'package:flutter/material.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/difficulty.dart';

/// Normal / Hard switch for the campaign picker (D65).
///
/// Hard is disabled rather than hidden until it is earned: a greyed segment with
/// its reason teaches that a second pass exists, where a missing control would
/// leave a player wondering whether the game has one. The labels come from
/// [Difficulty], so the picker, the HUD chip and the result row spell the modes
/// identically.
class DifficultySelector extends StatelessWidget {
  const DifficultySelector({
    required this.difficulty,
    required this.hardAvailable,
    required this.onChanged,
    super.key,
  });

  /// The mode currently shown.
  final Difficulty difficulty;

  /// Whether Hard has been earned (one region cleared on Normal).
  final bool hardAvailable;

  /// Called with the chosen mode; never called for a disabled option.
  final ValueChanged<Difficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<Difficulty>(
          segments: [
            for (final option in Difficulty.values)
              ButtonSegment<Difficulty>(
                value: option,
                label: Text(option.label),
                enabled: option == Difficulty.normal || hardAvailable,
                tooltip: option == Difficulty.hard
                    ? 'Clear a region on Normal to open Hard'
                    : null,
              ),
          ],
          selected: {difficulty},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            final chosen = selection.firstOrNull;
            if (chosen != null && chosen != difficulty) {
              onChanged(chosen);
            }
          },
        ),
        if (!hardAvailable)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Hard opens for each region once that region is cleared on '
              'Normal.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
