import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:up_tower_defense/app/routes.dart';
import 'package:up_tower_defense/core/constants/app_info.dart';
import 'package:up_tower_defense/features/campaign/presentation/campaign_summary.dart';
import 'package:up_tower_defense/features/save/presentation/save_status_message.dart';
import 'package:up_tower_defense/shared/layout/menu_layout.dart';

/// Root screen of the shell.
///
/// Entry points are deliberately shallow: one tap to play, one tap to any other
/// screen, and no login or connectivity gate before the first launch. Campaign
/// progress sits under the tagline because a returning player's first question
/// is how far they got, and the save status sits at the bottom because a player
/// who lost progress should learn it before hunting through a settings menu.
class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return MenuLayout(
      children: [
        Text(
          AppInfo.name,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          AppInfo.tagline,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        const CampaignSummary(),
        const SizedBox(height: 32),
        _MenuButton(
          icon: Icons.play_arrow_rounded,
          label: 'Play',
          primary: true,
          onTap: () => context.go(AppRoutes.gameplay),
        ),
        const SizedBox(height: 12),
        // The endless challenge sits beside Play but is not the campaign:
        // its own route, its own score (D62).
        _MenuButton(
          icon: Icons.waves_rounded,
          label: 'Endless',
          onTap: () => context.go(AppRoutes.endless),
        ),
        const SizedBox(height: 12),
        _MenuButton(
          icon: Icons.map_outlined,
          label: 'Campaign',
          onTap: () => context.go(AppRoutes.levelSelect),
        ),
        const SizedBox(height: 12),
        _MenuButton(
          icon: Icons.menu_book_outlined,
          label: 'Codex',
          onTap: () => context.go(AppRoutes.codex),
        ),
        const SizedBox(height: 12),
        _MenuButton(
          icon: Icons.settings_outlined,
          label: 'Settings',
          onTap: () => context.go(AppRoutes.settings),
        ),
        const SizedBox(height: 12),
        _MenuButton(
          icon: Icons.workspace_premium_outlined,
          label: 'Credits',
          onTap: () => context.go(AppRoutes.credits),
        ),
        const SizedBox(height: 28),
        // Silent unless something went wrong: the warning is the only reason
        // this line exists on the first screen.
        const SaveStatusMessage(onlyWhenDegraded: true),
        const SizedBox(height: 4),
        Text(
          'Offline game — no account, no network required.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(Size.fromHeight(56)),
      textStyle: WidgetStatePropertyAll<TextStyle?>(
        Theme.of(context).textTheme.titleMedium,
      ),
    );

    final iconWidget = Icon(icon);
    final labelWidget = Text(label, textAlign: TextAlign.start);

    if (primary) {
      return FilledButton.icon(
        onPressed: onTap,
        style: style,
        icon: iconWidget,
        label: labelWidget,
      );
    }

    return OutlinedButton.icon(
      onPressed: onTap,
      style: style,
      icon: iconWidget,
      label: labelWidget,
    );
  }
}
