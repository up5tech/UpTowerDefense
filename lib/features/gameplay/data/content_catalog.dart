/// Bundled content assets.
///
/// The campaign orders the levels; every other catalog is shared by all of them.
abstract final class ContentCatalog {
  /// Enemy catalog shared by every level.
  static const String enemies = 'assets/data/enemies/enemies.json';

  /// Tower catalog shared by every level.
  static const String towers = 'assets/data/towers/towers.json';

  /// Authored campaign: regions, level order and level names.
  static const String campaign = 'assets/data/campaign.json';

  /// Asset path for a level id.
  ///
  /// Level ids are file names by convention, and `campaign_assets_test` asserts
  /// that the campaign lists exactly the level files that ship — so a stray or
  /// missing file fails the suite instead of producing a level nobody can open.
  static String levelAssetFor(String levelId) =>
      'assets/data/levels/$levelId.json';

  /// The endless challenge level: authored like a level but not part of the
  /// campaign, so it lives outside `levels/` where the campaign's
  /// file-listing test would otherwise demand it be unlocked (D62).
  static const String endless = 'assets/data/endless.json';

  /// Map assets by map id, referenced from level definitions.
  static const Map<String, String> mapAssetsById = {
    'meadow_gate': 'assets/data/maps/meadow_gate.json',
    'ember_pass': 'assets/data/maps/ember_pass.json',
  };

  /// Asset for [mapId], or null when no such map ships with the app.
  static String? mapAssetFor(String mapId) => mapAssetsById[mapId];
}
