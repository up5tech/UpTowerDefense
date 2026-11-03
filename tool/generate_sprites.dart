// Regenerates the four sprites V2-2 adds to the roster: the Arc and Beacon
// towers and the Bulwark and Splitter enemies.
//
//     dart run tool/generate_sprites.dart
//
// The art is original to this project and recorded in
// `docs/ASSET_ATTRIBUTIONS.md`. It speaks the same flat-shape, no-black-outline
// language as the shipped Kenney sprites so the new roster reads as one set,
// and it is rasterised at 4x then box-downsampled for soft anti-aliased edges
// rather than hard pixel steps.
//
// The script is deterministic: re-running it reproduces the files byte for
// byte, so a palette or silhouette change is a reviewable code diff instead of
// an opaque binary edit.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Writes the four sprite files next to the rest of the art in
/// `assets/images/`.
void main() {
  final files = <String, Uint8List>{
    'assets/images/tower_arc.png': _drawArc(),
    'assets/images/tower_beacon.png': _drawBeacon(),
    'assets/images/enemy_bulwark.png': _drawBulwark(),
    'assets/images/enemy_splitter.png': _drawSplitter(),
  };

  for (final file in files.entries) {
    File(file.key).writeAsBytesSync(file.value);
    stdout.writeln('wrote ${file.key} (${file.value.length} bytes)');
  }
}

// The platform every tower stands on, shared with the Kenney tower sprites so
// the five-tower roster reads as one family.
const _baseDark = 0xFF4E4E4E;
const _baseMid = 0xFF6E6E6E;
const _baseLight = 0xFF8A8A8A;

/// Arc tower: a gold pylon carrying the bolt that names it.
Uint8List _drawArc() {
  final raster = _Raster(56, 56);
  _drawPlatform(raster);

  raster.roundedRect(16, 4, 40, 30, 5, 0xFFC98A2E);
  raster.roundedRect(18, 6, 38, 28, 4, 0xFFFFD166);
  raster.roundedRect(20, 8, 25, 26, 2, 0xFFFFE9A8);

  // The bolt sits in near-white so it reads against the gold at the size the
  // camera actually draws the tower.
  const bolt = [30.0, 9.0, 23.0, 17.0, 32.0, 17.0, 24.0, 26.0];
  raster.polyline(bolt, 4, 0xFFFFFBEA);
  raster.disc(30, 9, 2, 0xFFFFFBEA);
  raster.disc(24, 26, 2, 0xFFFFFBEA);
  return raster.png();
}

/// Beacon tower: a mast-headed orb radiating two rings of aura.
Uint8List _drawBeacon() {
  final raster = _Raster(56, 56);
  _drawPlatform(raster);

  raster.roundedRect(24, 22, 32, 31, 2, _baseDark);
  raster.roundedRect(25, 23, 31, 31, 2, _baseLight);
  raster.roundedRect(26, 24, 28, 31, 0, 0xFFB0B0B0);

  raster.disc(28, 16, 8.5, 0xFFB446A8);
  raster.disc(28, 16, 7, 0xFFE46DD4);
  raster.disc(25.5, 13.5, 3, 0xFFFFC2F0);

  const wave = 0xCCE46DD4;
  raster.ringArc(28, 16, 10.5, 12.5, -50, 50, wave);
  raster.ringArc(28, 16, 10.5, 12.5, 130, 230, wave);
  raster.ringArc(28, 16, 14.5, 16.5, -45, 45, wave);
  raster.ringArc(28, 16, 14.5, 16.5, 135, 225, wave);
  return raster.png();
}

/// Bulwark: a steel shield-beast whose plate is the reason it shrugs off
/// small hits.
Uint8List _drawBulwark() {
  final raster = _Raster(54, 54);

  raster.polygon(const [7, 8, 47, 8, 47, 34, 27, 50, 7, 34], 0xFF3F566B);
  raster.polygon(const [10, 11, 44, 11, 44, 32, 27, 46, 10, 32], 0xFF5C7A99);
  raster.polygon(const [10, 11, 44, 11, 44, 17, 10, 17], 0xFF7FA0BC);
  raster.roundedRect(25, 17, 29, 42, 1, 0xFF7FA0BC);

  raster.disc(15, 27, 1.8, 0xFFA9C4D8);
  raster.disc(39, 27, 1.8, 0xFFA9C4D8);
  raster.disc(17, 35, 1.8, 0xFFA9C4D8);
  raster.disc(37, 35, 1.8, 0xFFA9C4D8);

  raster.disc(18, 19, 3.2, 0xFF22303D);
  raster.disc(36, 19, 3.2, 0xFF22303D);
  raster.disc(19, 18, 1.1, 0xFFDCEBF7);
  raster.disc(37, 18, 1.1, 0xFFDCEBF7);
  return raster.png();
}

/// Splitter: a green blob already cracked down the middle, which is what it
/// does to two runners when it dies.
Uint8List _drawSplitter() {
  final raster = _Raster(44, 44);

  raster.disc(22, 23, 17.5, 0xFF5A9B33);
  raster.disc(22, 23, 15.5, 0xFF7BC950);
  raster.disc(17, 18, 7, 0xFFA5E86F);

  // The crack runs past the light body to the dark rim, so the silhouette
  // already reads as split.
  raster.polyline(
    const [22, 7, 19, 14, 25, 20, 18, 27, 24, 33, 21, 39],
    2.6,
    0xFF33501F,
  );

  raster.disc(13, 16, 2.6, 0xFF243A12);
  raster.disc(31, 16, 2.6, 0xFF243A12);
  raster.disc(14, 15, 1.1, 0xFFD9F5C0);
  raster.disc(32, 15, 1.1, 0xFFD9F5C0);
  return raster.png();
}

/// The tapered platform under both towers: dark silhouette, mid body, light
/// top face — the same three-step shading the Kenney bases use.
void _drawPlatform(_Raster raster) {
  raster.polygon(const [
    6,
    30,
    50,
    30,
    44,
    44,
    36,
    54,
    20,
    54,
    12,
    44,
  ], _baseDark);
  raster.polygon(const [
    8,
    32,
    48,
    32,
    42,
    44,
    35,
    52,
    21,
    52,
    14,
    44,
  ], _baseMid);
  raster.polygon(const [8, 32, 48, 32, 47, 37, 9, 37], _baseLight);
}

/// A shape rasteriser that draws hard-edged shapes on a 4x supersampled grid
/// and box-filters the grid back down, so every edge gets soft anti-aliasing
/// without hand-authored alpha ramps.
class _Raster {
  _Raster(this.width, this.height)
    : _sw = width * _ss,
      _sh = height * _ss,
      data = Float32List(width * _ss * height * _ss * 4);

  /// Subsamples per destination pixel per axis.
  static const _ss = 4;

  final int width;
  final int height;
  final int _sw;
  final int _sh;

  /// Premultiplied RGBA in 0..255, one record per subpixel.
  final Float32List data;

  /// Fills a disc of radius [radius] centred on ([cx], [cy]).
  void disc(double cx, double cy, double radius, int color) {
    _fill(cx - radius, cy - radius, cx + radius, cy + radius, (x, y) {
      final dx = x - cx;
      final dy = y - cy;
      return dx * dx + dy * dy <= radius * radius;
    }, color);
  }

  /// Fills the closed polygon described by flat `[x0, y0, x1, y1, ...]`
  /// [points] with the even-odd rule.
  void polygon(List<double> points, int color) {
    var minX = points[0];
    var minY = points[1];
    var maxX = points[0];
    var maxY = points[1];
    for (var i = 0; i < points.length; i += 2) {
      minX = math.min(minX, points[i]);
      maxX = math.max(maxX, points[i]);
      minY = math.min(minY, points[i + 1]);
      maxY = math.max(maxY, points[i + 1]);
    }
    _fill(minX, minY, maxX, maxY, (x, y) => _inPolygon(x, y, points), color);
  }

  /// Fills an axis-aligned rectangle with corners rounded by [radius].
  /// A radius of zero fills the plain rectangle.
  void roundedRect(
    double x0,
    double y0,
    double x1,
    double y1,
    double radius,
    int color,
  ) {
    final halfW = (x1 - x0) / 2;
    final halfH = (y1 - y0) / 2;
    final cx = (x0 + x1) / 2;
    final cy = (y0 + y1) / 2;
    _fill(x0, y0, x1, y1, (x, y) {
      final dx = (x - cx).abs();
      final dy = (y - cy).abs();
      if (dx > halfW || dy > halfH) {
        return false;
      }
      final ox = dx - (halfW - radius);
      final oy = dy - (halfH - radius);
      final ax = ox > 0 ? ox : 0.0;
      final ay = oy > 0 ? oy : 0.0;
      return ax * ax + ay * ay <= radius * radius;
    }, color);
  }

  /// Strokes a polyline of the given [width] through flat `[x0, y0, ...]`
  /// [points], with round caps so the ends do not look chopped off.
  void polyline(List<double> points, double width, int color) {
    final half = width / 2;
    var minX = points[0] - half;
    var minY = points[1] - half;
    var maxX = points[0] + half;
    var maxY = points[1] + half;
    for (var i = 0; i < points.length; i += 2) {
      minX = math.min(minX, points[i] - half);
      maxX = math.max(maxX, points[i] + half);
      minY = math.min(minY, points[i + 1] - half);
      maxY = math.max(maxY, points[i + 1] + half);
    }
    _fill(minX, minY, maxX, maxY, (x, y) {
      for (var i = 0; i + 3 < points.length; i += 2) {
        final distance = _segmentDistance(
          x,
          y,
          points[i],
          points[i + 1],
          points[i + 2],
          points[i + 3],
        );
        if (distance <= half) {
          return true;
        }
      }
      return false;
    }, color);
  }

  /// Fills an annulus segment between radii [inner] and [outer] around
  /// ([cx], [cy]), from [startDegrees] to [endDegrees] measured on the
  /// standard maths axes (0 = right, positive = clockwise on screen).
  void ringArc(
    double cx,
    double cy,
    double inner,
    double outer,
    double startDegrees,
    double endDegrees,
    int color,
  ) {
    final start = startDegrees * math.pi / 180;
    final end = endDegrees * math.pi / 180;
    _fill(cx - outer, cy - outer, cx + outer, cy + outer, (x, y) {
      final dx = x - cx;
      final dy = y - cy;
      final distanceSq = dx * dx + dy * dy;
      if (distanceSq < inner * inner || distanceSq > outer * outer) {
        return false;
      }
      var angle = math.atan2(dy, dx);
      while (angle < start) {
        angle += 2 * math.pi;
      }
      while (angle >= start + 2 * math.pi) {
        angle -= 2 * math.pi;
      }
      return angle <= end;
    }, color);
  }

  /// Composites the supersampled buffer down to straight-alpha RGBA bytes.
  Uint8List image() {
    final out = Uint8List(width * height * 4);
    const samples = _ss * _ss;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var r = 0.0;
        var g = 0.0;
        var b = 0.0;
        var a = 0.0;
        for (var row = 0; row < _ss; row++) {
          var offset = ((y * _ss + row) * _sw + x * _ss) * 4;
          for (var column = 0; column < _ss; column++) {
            r += data[offset];
            g += data[offset + 1];
            b += data[offset + 2];
            a += data[offset + 3];
            offset += 4;
          }
        }
        r /= samples;
        g /= samples;
        b /= samples;
        a /= samples;

        final outOffset = (y * width + x) * 4;
        if (a > 0) {
          // The buffer is premultiplied; PNG wants straight alpha.
          out[outOffset] = _channel(r * 255 / a);
          out[outOffset + 1] = _channel(g * 255 / a);
          out[outOffset + 2] = _channel(b * 255 / a);
        }
        out[outOffset + 3] = _channel(a);
      }
    }
    return out;
  }

  /// Encodes [image] as an 8-bit RGBA PNG.
  Uint8List png() {
    final out = BytesBuilder();
    out.add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

    final header = BytesBuilder();
    header.add(_u32(width));
    header.add(_u32(height));
    header.add(const [8, 6, 0, 0, 0]); // 8 bits per channel, truecolour+alpha
    out.add(_chunk('IHDR', header.takeBytes()));

    final raw = BytesBuilder();
    final stride = width * 4;
    final pixels = image();
    for (var y = 0; y < height; y++) {
      raw.addByte(0); // filter: none, keeps the encoder trivially verifiable
      raw.add(pixels.sublist(y * stride, (y + 1) * stride));
    }
    out.add(_chunk('IDAT', ZLibEncoder().convert(raw.takeBytes())));
    out.add(_chunk('IEND', const []));
    return out.takeBytes();
  }

  /// Src-over composite of [color] (0xAARRGGBB) at one covered subpixel.
  void _blend(int offset, int color) {
    final alpha = (color >>> 24) & 0xFF;
    if (alpha == 0) {
      return;
    }
    final sourceAlpha = alpha / 255;
    final keep = 1 - sourceAlpha;
    data[offset] = ((color >>> 16) & 0xFF) * sourceAlpha + data[offset] * keep;
    data[offset + 1] =
        ((color >>> 8) & 0xFF) * sourceAlpha + data[offset + 1] * keep;
    data[offset + 2] = (color & 0xFF) * sourceAlpha + data[offset + 2] * keep;
    data[offset + 3] = alpha + data[offset + 3] * keep;
  }

  /// Rasterises the subpixels of the bounding box for which [inside] reports
  /// coverage, in destination coordinates.
  void _fill(
    double x0,
    double y0,
    double x1,
    double y1,
    bool Function(double x, double y) inside,
    int color,
  ) {
    final firstX = math.max(0, (x0 * _ss).floor());
    final lastX = math.min(_sw - 1, (x1 * _ss).ceil());
    final firstY = math.max(0, (y0 * _ss).floor());
    final lastY = math.min(_sh - 1, (y1 * _ss).ceil());
    for (var row = firstY; row <= lastY; row++) {
      final y = (row + 0.5) / _ss;
      for (var column = firstX; column <= lastX; column++) {
        final x = (column + 0.5) / _ss;
        if (inside(x, y)) {
          _blend((row * _sw + column) * 4, color);
        }
      }
    }
  }
}

/// Even-odd point-in-polygon test over flat `[x0, y0, ...]` [points].
bool _inPolygon(double x, double y, List<double> points) {
  var inside = false;
  final vertices = points.length ~/ 2;
  for (var i = 0, j = vertices - 1; i < vertices; j = i++) {
    final xi = points[i * 2];
    final yi = points[i * 2 + 1];
    final xj = points[j * 2];
    final yj = points[j * 2 + 1];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}

/// Distance from ([x], [y]) to the segment ([x1], [y1])–([x2], [y2]).
double _segmentDistance(
  double x,
  double y,
  double x1,
  double y1,
  double x2,
  double y2,
) {
  final vx = x2 - x1;
  final vy = y2 - y1;
  final lengthSq = vx * vx + vy * vy;
  var t = 0.0;
  if (lengthSq > 0) {
    t = ((x - x1) * vx + (y - y1) * vy) / lengthSq;
    t = t < 0 ? 0 : (t > 1 ? 1 : t);
  }
  final dx = x - (x1 + t * vx);
  final dy = y - (y1 + t * vy);
  return math.sqrt(dx * dx + dy * dy);
}

/// Clamps a filtered channel back into a byte.
int _channel(double value) {
  if (value <= 0) {
    return 0;
  }
  if (value >= 255) {
    return 255;
  }
  return value.round();
}

/// Big-endian 32-bit word, as PNG chunks want it.
List<int> _u32(int value) => [
  (value >>> 24) & 0xFF,
  (value >>> 16) & 0xFF,
  (value >>> 8) & 0xFF,
  value & 0xFF,
];

/// Wraps [data] in a PNG chunk: length, type, payload, CRC of type+payload.
Uint8List _chunk(String type, List<int> data) {
  final body = Uint8List(type.length + data.length);
  for (var i = 0; i < type.length; i++) {
    body[i] = type.codeUnitAt(i);
  }
  body.setAll(type.length, data);

  final out = BytesBuilder();
  out.add(_u32(data.length));
  out.add(body);
  out.add(_u32(_crc32(body)));
  return out.takeBytes();
}

/// CRC-32/ISO-HDLC, the checksum every PNG chunk carries.
int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >>> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

final List<int> _crcTable = List<int>.generate(256, (index) {
  var value = index;
  for (var bit = 0; bit < 8; bit++) {
    value = (value & 1) != 0 ? 0xEDB88320 ^ (value >>> 1) : value >>> 1;
  }
  return value;
});
