import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:up_tower_defense/features/credits/data/attribution_repository.dart';
import 'package:up_tower_defense/features/credits/domain/attributions.dart';

/// Bundle the attribution document is read from.
///
/// A seam of its own so widget tests can serve a fixture document and never
/// depend on real assets, the same rule the content providers follow.
final Provider<AssetBundle> attributionBundleProvider = Provider<AssetBundle>((
  ref,
) {
  return rootBundle;
});

/// The parsed credits document.
///
/// Loaded when the screen opens and kept per container, so revisiting credits
/// does not re-read the file but a relaunched app does.
///
/// `retry` is disabled deliberately: Riverpod 3 retries a failed future up to
/// ten times with backoff, which would hold the screen on "Loading" for the
/// better part of a minute. A bundled file that cannot be read is a broken
/// build or a format change, never a transient failure, so it should surface
/// as an error message the moment it happens.
final FutureProvider<Attributions> attributionsProvider =
    FutureProvider<Attributions>(
      (ref) {
        return AttributionRepository(
          ref.watch(attributionBundleProvider),
        ).load();
      },
      retry: (retryCount, error) => null,
    );
