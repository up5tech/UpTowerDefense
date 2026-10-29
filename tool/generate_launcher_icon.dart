// Generates the launcher-icon source art for UpTowerDefense.
//
// Run with: dart run tool/generate_launcher_icon.dart
//
// The repo has no design file for an app icon, so the source images are drawn
// here from the game's own palette (AppTheme background #0D1117, seed green
// #37C2A0) — every launcher size is then derived from these two files by
// `flutter_launcher_icons` (dev dependency), never hand-copied:
//
//   tool/icon/icon.png               1024², full-bleed — legacy Android + iOS
//   tool/icon/icon_foreground.png    1024², transparent, art inside the
//                                    adaptive-icon safe zone — Android 8+
//
// Shapes are signed-distance fields with 1px analytic antialiasing, so the
// edges stay clean at every size the stores ask for. The art is a tower in a
// target ring: the game's whole loop in one mark.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int _size = 1024;

/// App background, matching AppTheme's dark background.
const int _bg = 0xFF0D1117;

/// Accent from AppTheme's seed colour — the target ring.
const int _ring = 0xFF37C2A0;

/// Tower stone: light enough to read at 48px against the background.
const int _stone = 0xFFE4ECF2;

void main() {
  final art = _render(includeBackground: false);
  _writePng(File('tool/icon/icon_foreground.png'), art);

  final full = _render(includeBackground: true);
  _writePng(File('tool/icon/icon.png'), full);

  stdout.writeln(
    'wrote tool/icon/icon.png and tool/icon/icon_foreground.png ($_size²)',
  );
}

/// Renders the icon at [_size]².
///
/// With [includeBackground] the art scales up to fill the legacy (pre-Android
/// 8) and iOS icon, where nothing crops it; without it the art stays inside
/// the adaptive-icon safe zone (a centred 66% circle) so launchers may mask
/// any shape without cutting the tower.
Uint8List _render({required bool includeBackground}) {
  final pixels = Uint8List(_size * _size * 4);
  if (includeBackground) {
    for (var i = 0; i < _size * _size; i++) {
      pixels[i * 4] = 0x0D;
      pixels[i * 4 + 1] = 0x11;
      pixels[i * 4 + 2] = 0x17;
      pixels[i * 4 + 3] = 0xFF;
    }
  }

  // Safe-zone art radius: adaptive icons must keep the mark inside a centred
  // circle of 66% of the canvas; the full icon uses the extra room.
  final scale = includeBackground ? 1.30 : 1.0;
  const cx = _size / 2;
  const cy = _size / 2;

  // The target ring, behind everything: stroke, not disc, so the background
  // reads through it and the mark stays light on dark.
  _paint(pixels, (x, y) {
    final d =
        (math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) - 306 * scale) -
        15 * scale;
    return _coverage(d);
  }, _ring);

  // Tower body.
  final hx = 75.0 * scale;
  final top = cy - 132 * scale;
  final bottom = cy + 188 * scale;
  _paint(pixels, (x, y) {
    return _coverage(
      _roundRect(
        x,
        y,
        cx,
        (top + bottom) / 2,
        hx,
        (bottom - top) / 2,
        8 * scale,
      ),
    );
  }, _stone);

  // Crenellations: three merlons, gaps cut by simply not painting them —
  // painted after the body would cover it, so paint them as one band with
  // three teeth before the body? Simpler: paint merlons as their own boxes.
  final merlonW = 40 * scale;
  final gap = 15 * scale;
  final merlonTop = top - 46 * scale;
  for (var m = 0; m < 3; m++) {
    final left = cx - hx + m * (merlonW + gap);
    final mcx = left + merlonW / 2;
    _paint(pixels, (x, y) {
      return _coverage(
        _roundRect(
          x,
          y,
          mcx,
          merlonTop + 23 * scale,
          merlonW / 2,
          23 * scale,
          4 * scale,
        ),
      );
    }, _stone);
  }

  // Arrow slit and gate, cut back to the background colour: openings, not
  // paint, so greyscale and colour-blind alike still read "tower".
  _paint(
    pixels,
    (x, y) {
      return _coverage(
        _roundRect(
          x,
          y,
          cx,
          top + 60 * scale,
          13 * scale,
          34 * scale,
          4 * scale,
        ),
      );
    },
    includeBackground ? _bg : 0x00000000,
    maskWithAlpha: !includeBackground,
  );

  _paint(
    pixels,
    (x, y) {
      return _coverage(
        _roundRect(
          x,
          y,
          cx,
          bottom - 40 * scale,
          34 * scale,
          40 * scale,
          6 * scale,
        ),
      );
    },
    includeBackground ? _bg : 0x00000000,
    maskWithAlpha: !includeBackground,
  );

  return pixels;
}

/// Signed distance to a rounded rectangle centred at (cx, cy).
double _roundRect(
  double x,
  double y,
  double cx,
  double cy,
  double halfWidth,
  double halfHeight,
  double radius,
) {
  final dx = (x - cx).abs() - halfWidth + radius;
  final dy = (y - cy).abs() - halfHeight + radius;
  final outside = math.sqrt(
    math.max(dx, 0) * math.max(dx, 0) + math.max(dy, 0) * math.max(dy, 0),
  );
  return math.min(math.max(dx, dy), 0) + outside - radius;
}

/// 1px antialiasing coverage for a signed distance (inside is negative).
double _coverage(double distance) {
  final value = 0.5 - distance;
  if (value <= 0) {
    return 0;
  }
  if (value >= 1) {
    return 1;
  }
  return value;
}

/// Composites one shape over [pixels]; [maskWithAlpha] writes a transparent
/// hole instead of a colour (the icon's openings).
void _paint(
  Uint8List pixels,
  double Function(double x, double y) field,
  int color, {
  bool maskWithAlpha = false,
}) {
  final r = (color >> 16) & 0xFF;
  final g = (color >> 8) & 0xFF;
  final b = color & 0xFF;
  final a = (color >> 24) & 0xFF;

  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      final coverage = field(x + 0.5, y + 0.5);
      if (coverage <= 0) {
        continue;
      }
      final index = (y * _size + x) * 4;
      if (maskWithAlpha) {
        // Punch a hole through whatever is below (background or stone).
        final existing = pixels[index + 3] / 255;
        pixels[index + 3] = (existing * (1 - coverage) * 255).round();
        // RGB stays; fully transparent pixels are invisible anyway.
      } else {
        final existing = pixels[index + 3] / 255;
        final src = coverage * (a / 255);
        final outA = src + existing * (1 - src);
        if (outA <= 0) {
          continue;
        }
        for (var c = 0; c < 3; c++) {
          final dst = pixels[index + c];
          final channel = c == 0 ? r : (c == 1 ? g : b);
          pixels[index + c] =
              ((channel * src + dst * existing * (1 - src)) / outA).round();
        }
        pixels[index + 3] = (outA * 255).round();
      }
    }
  }
}

/// Minimal PNG writer: filter-0 scanlines, zlib from dart:io, manual chunks.
void _writePng(File file, Uint8List rgba) {
  final raw = Uint8List((_size * 4 + 1) * _size);
  for (var y = 0; y < _size; y++) {
    final rowStart = y * (_size * 4 + 1);
    raw[rowStart] = 0; // filter: none
    raw.setRange(rowStart + 1, rowStart + 1 + _size * 4, rgba, y * _size * 4);
  }

  final compressed = ZLibEncoder(level: 9).convert(raw);

  final ihdr = ByteData(13);
  ihdr.setUint32(0, _size);
  ihdr.setUint32(4, _size);
  ihdr.setUint8(8, 8); // bit depth
  ihdr.setUint8(9, 6); // colour type: RGBA
  ihdr.setUint8(10, 0);
  ihdr.setUint8(11, 0);
  ihdr.setUint8(12, 0);

  final buffer = BytesBuilder();
  buffer.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  _addChunk(buffer, 'IHDR', ihdr.buffer.asUint8List());
  _addChunk(buffer, 'IDAT', compressed);
  _addChunk(buffer, 'IEND', const []);

  file
    ..createSync(recursive: true)
    ..writeAsBytesSync(buffer.takeBytes());
}

void _addChunk(BytesBuilder buffer, String type, List<int> data) {
  final typeBytes = type.codeUnits;
  final body = BytesBuilder()
    ..add(typeBytes)
    ..add(data);
  final bodyBytes = body.takeBytes();
  buffer.add([
    (data.length >> 24) & 0xFF,
    (data.length >> 16) & 0xFF,
    (data.length >> 8) & 0xFF,
    data.length & 0xFF,
  ]);
  buffer.add(bodyBytes);
  final crc = _crc32(bodyBytes);
  buffer.add([
    (crc >> 24) & 0xFF,
    (crc >> 16) & 0xFF,
    (crc >> 8) & 0xFF,
    crc & 0xFF,
  ]);
}

final List<int> _crcTable = _buildCrcTable();

List<int> _buildCrcTable() {
  final table = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
}

int _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
