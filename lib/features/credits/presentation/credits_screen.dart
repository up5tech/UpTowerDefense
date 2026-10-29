import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/core/constants/app_info.dart';
import 'package:up_tower_defense/features/credits/application/credits_providers.dart';
import 'package:up_tower_defense/features/credits/domain/attributions.dart';
import 'package:up_tower_defense/shared/layout/menu_layout.dart';

/// Credits: art and audio attribution, runtime package licences and the
/// platform licence page.
///
/// Every line comes from `docs/ASSET_ATTRIBUTIONS.md`, the file the repo
/// requires each shipped asset to be recorded in *before* it lands in
/// `assets/` — so the screen cannot drift from the record, and an asset that
/// is not in the file does not appear in the credits. A failed read says so
/// instead of rendering an empty screen: silent credits would read as "nothing
/// to credit", which is exactly the claim the file exists to prevent.
class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final attributions = ref.watch(attributionsProvider);

    return MenuLayout(
      title: 'Credits',
      children: [
        Text(
          '${AppInfo.name} is built on open-source software and CC0 art and '
          'audio.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        ...attributions.when(
          loading: () => [
            Text(
              'Loading credits…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          error: (error, stackTrace) => [
            Text(
              'The attribution record could not be read: $error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          data: (credits) => [
            if (credits.assets.isEmpty)
              Text(
                'No third-party art or audio is shipped. Assets are recorded '
                'with their licences before they are added.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              const _SectionHeader(label: 'Art and audio'),
              for (final asset in credits.assets)
                _AssetTile(asset: asset, theme: theme),
            ],
            const SizedBox(height: 8),
            const _SectionHeader(label: 'Packages'),
            for (final package in credits.packages)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(package.name),
                trailing: Text(
                  package.licence,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Every shipped asset is recorded with its licence before it is '
          'added; assets with unknown licences never ship.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: AppInfo.name,
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open source licences'),
          ),
        ),
      ],
    );
  }
}

/// One recorded asset group: what ships, who made it, under what licence and
/// where it came from.
class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.asset, required this.theme});

  final AssetCredit asset;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(asset.assets, style: theme.textTheme.bodyMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${asset.author} · ${asset.licence}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            asset.source,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
