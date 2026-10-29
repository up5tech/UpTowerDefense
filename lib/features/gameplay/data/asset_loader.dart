import 'package:flutter/services.dart';
import 'package:up_tower_defense/features/gameplay/data/content_load_exception.dart';

/// Reads a bundled text asset, reporting failures as content errors.
///
/// Content only ever comes from the app bundle, so a failure here means a broken
/// build or a missing `pubspec.yaml` entry, never a network problem.
Future<String> readAssetText(AssetBundle bundle, String assetPath) async {
  try {
    return await bundle.loadString(assetPath);
  } on Object catch (error) {
    throw ContentLoadException(assetPath, 'could not read the asset: $error');
  }
}
