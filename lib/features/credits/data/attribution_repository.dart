import 'package:flutter/services.dart';
import 'package:up_tower_defense/features/credits/domain/attributions.dart';
import 'package:up_tower_defense/features/gameplay/data/asset_loader.dart';

/// Bundle key of the attribution document.
///
/// The file lives in `docs/` and is declared as a Flutter asset directly, so
/// the record the repo maintains and the record the credits screen renders are
/// one file — there is no copy that can drift.
const String kAttributionAssetKey = 'docs/ASSET_ATTRIBUTIONS.md';

/// Loads and parses the attribution document from the app bundle.
class AttributionRepository {
  AttributionRepository(this.bundle);

  /// Bundle to read from; widget tests inject a stub so they never depend on
  /// real assets.
  final AssetBundle bundle;

  Future<Attributions> load() async {
    final markdown = await readAssetText(bundle, kAttributionAssetKey);
    return const AttributionParser().parse(markdown);
  }
}
