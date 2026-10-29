import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/save/presentation/save_status_message.dart';
import 'package:up_tower_defense/features/settings/application/settings_providers.dart';
import 'package:up_tower_defense/shared/layout/menu_layout.dart';

/// Local preferences: audio, haptics and motion.
///
/// Every change is applied and saved immediately, so there is no save button
/// and nothing to lose if the app is closed from this screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return MenuLayout(
      title: 'Settings',
      children: [
        _SectionHeader(label: 'Audio', theme: theme),
        SwitchListTile(
          title: const Text('Music'),
          subtitle: const Text('Background music during menus and levels'),
          value: settings.musicEnabled,
          onChanged: (value) => controller.setMusicEnabled(enabled: value),
        ),
        _VolumeSlider(
          label: 'Music',
          value: settings.musicVolume,
          enabled: settings.musicEnabled,
          onChanged: controller.setMusicVolume,
        ),
        SwitchListTile(
          title: const Text('Sound effects'),
          subtitle: const Text('Builds, attacks, impacts and wave alerts'),
          value: settings.sfxEnabled,
          onChanged: (value) => controller.setSfxEnabled(enabled: value),
        ),
        _VolumeSlider(
          label: 'SFX',
          value: settings.sfxVolume,
          enabled: settings.sfxEnabled,
          onChanged: controller.setSfxVolume,
        ),
        const SizedBox(height: 8),
        _SectionHeader(label: 'Accessibility', theme: theme),
        SwitchListTile(
          title: const Text('Haptics'),
          subtitle: const Text('Short vibration on important actions'),
          value: settings.hapticsEnabled,
          onChanged: (value) => controller.setHapticsEnabled(enabled: value),
        ),
        SwitchListTile(
          title: const Text('Reduced motion'),
          subtitle: const Text('Tone down large effects and camera movement'),
          value: settings.reducedMotion,
          onChanged: (value) => controller.setReducedMotion(enabled: value),
        ),
        const SizedBox(height: 16),
        const _ProgressSection(),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Campaign progress: the recovery message when a load had to fall back, and
/// the one destructive action in the app.
///
/// Reset lives here rather than on the picker so unlocking a level can never be
/// undone by a stray tap, and it asks first because there is no undo.
class _ProgressSection extends ConsumerWidget {
  const _ProgressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = ref.watch(campaignProgressProvider);
    final recorded = progress.results.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'Progress', theme: theme),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SaveStatusMessage(),
        ),
        ListTile(
          title: const Text('Reset campaign progress'),
          subtitle: Text(
            recorded == 0
                ? 'Nothing has been recorded on this device'
                : '$recorded level${recorded == 1 ? '' : 's'} recorded '
                      'on this device',
          ),
          enabled: recorded > 0,
          onTap: recorded == 0 ? null : () => _confirmReset(context, ref),
        ),
      ],
    );
  }

  /// Asks before wiping, because a reset cannot be undone from the app.
  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset campaign progress?'),
        content: const Text(
          'Every unlocked level, star and best result on this device will be '
          'erased. Audio and motion settings are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    ref.read(campaignProgressProvider.notifier).reset();
  }
}

/// One channel's loudness control.
///
/// Sits under its switch and disables with it: a slider on a muted channel
/// would promise an effect the switch has already vetoed. The value is stored
/// 0..1, so it doubles as the audio layers' volume multiplier.
class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = '${(value * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(
            child: Slider(
              value: value,
              onChanged: enabled ? onChanged : null,
              divisions: 20,
              label: percent,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              percent,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.theme});

  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
