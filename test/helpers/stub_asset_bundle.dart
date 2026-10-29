import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Serves content JSON from memory so tests never depend on real assets.
class StubAssetBundle extends AssetBundle {
  StubAssetBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    final contents = files[key];
    if (contents == null) {
      throw FlutterError('Missing asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(contents)));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final contents = files[key];
    if (contents == null) {
      throw FlutterError('Missing asset: $key');
    }
    return contents;
  }
}
