import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// D46/V2-5: an enemy may never be identifiable by colour alone.
///
/// Identity comes from art, so the check is on the art itself: every shipped
/// enemy's **alpha** mask is compared with every other's, sampled on a fixed
/// grid so different canvas sizes are comparable. Two enemies repainted from the
/// same shape would differ by nothing here, which is exactly the regression this
/// guards against — the Kenney and generated sprites all differ in outline.
const int _grid = 32;

/// Smallest share of the grid two silhouettes must disagree on.
///
/// A repaint of the same shape scores 0; the shipped art scores far more. The
/// floor is low on purpose: it catches "same outline, new colour" without
/// forcing art direction to keep a margin it cannot see.
const double _minDifference = 0.015;

void main() {
  testWidgets('every enemy reads by silhouette, never by colour alone', (
    tester,
  ) async {
    final ids = _enemyIds();
    expect(ids.length, greaterThan(2), reason: 'the catalog must be compared');

    final masks = <String, List<bool>>{};
    await tester.runAsync(() async {
      for (final id in ids) {
        masks[id] = await _alphaMask('assets/images/enemy_$id.png');
      }
    });

    for (final id in ids) {
      expect(
        masks[id]!.where((filled) => filled),
        isNotEmpty,
        reason: 'enemy_$id.png has no opaque pixels to read',
      );
    }

    for (var a = 0; a < ids.length; a++) {
      for (var b = a + 1; b < ids.length; b++) {
        final difference = _difference(masks[ids[a]]!, masks[ids[b]]!);
        expect(
          difference,
          greaterThan(_minDifference),
          reason:
              'enemy_${ids[a]} and enemy_${ids[b]} share a silhouette; '
              'they could only be told apart by colour',
        );
      }
    }
  });
}

/// Enemy definition ids from the shipped catalog, in file order.
List<String> _enemyIds() {
  final decoded = jsonDecode(
    File('assets/data/enemies/enemies.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final enemies = decoded['enemies']! as List<Object?>;
  return [
    for (final enemy in enemies)
      (enemy! as Map<String, Object?>)['id']! as String,
  ];
}

/// Whether each cell of a [_grid]×[_grid] overlay covers opaque pixels.
Future<List<bool>> _alphaMask(String path) async {
  final bytes = File(path).readAsBytesSync();
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  try {
    final data = await image.toByteData();
    final pixels = data!;

    return [
      for (var y = 0; y < _grid; y++)
        for (var x = 0; x < _grid; x++)
          _alphaAt(pixels, image.width, image.height, x, y) > 127,
    ];
  } finally {
    image.dispose();
  }
}

/// Samples the pixel under cell (x, y) of the normalised grid.
int _alphaAt(ByteData pixels, int width, int height, int x, int y) {
  final sourceX = (((x + 0.5) * width) / _grid).floor().clamp(0, width - 1);
  final sourceY = (((y + 0.5) * height) / _grid).floor().clamp(0, height - 1);
  return pixels.getUint8((sourceY * width + sourceX) * 4 + 3);
}

/// Share of grid cells where two masks disagree.
double _difference(List<bool> a, List<bool> b) {
  var differing = 0;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) {
      differing++;
    }
  }
  return differing / a.length;
}
