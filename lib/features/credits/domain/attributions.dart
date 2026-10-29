import 'package:meta/meta.dart';

/// One row of the tracked-assets table in `docs/ASSET_ATTRIBUTIONS.md`.
@immutable
class AssetCredit {
  const AssetCredit({
    required this.assets,
    required this.author,
    required this.licence,
    required this.source,
  });

  /// File or folder pattern the entry covers, exactly as written.
  final String assets;

  /// Author or vendor to credit.
  final String author;

  /// Licence in plain text, with markdown links flattened to their label.
  final String licence;

  /// Where the asset was obtained from.
  final String source;
}

/// One shipped runtime package from the licence list.
@immutable
class PackageCredit {
  const PackageCredit({required this.name, required this.licence});

  /// Package name; may carry a parenthetical such as a transitive note.
  final String name;

  /// Distribution licence, e.g. `MIT`.
  final String licence;
}

/// Everything the credits screen renders, parsed from one markdown document.
@immutable
class Attributions {
  const Attributions({required this.assets, required this.packages});

  /// Rows of the tracked-assets table, in file order.
  final List<AssetCredit> assets;

  /// Runtime packages only; development-only packages never ship.
  final List<PackageCredit> packages;
}

/// Turns `docs/ASSET_ATTRIBUTIONS.md` into the shapes the screen shows.
///
/// Plain Dart on purpose: the attribution file is the single source of truth
/// for what the credits say, so its reading rules belong where they can be
/// tested without a widget. A document that no longer looks like the format
/// throws instead of rendering an empty credits list — the file ships in the
/// bundle, so a format change must be noticed by a test, not discovered as a
/// silently blank screen.
class AttributionParser {
  const AttributionParser();

  /// Matches `[label](url)`, flattened to `label` for display.
  static final RegExp _link = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');

  Attributions parse(String markdown) {
    final lines = markdown.split('\n');
    return Attributions(
      assets: _parseAssets(lines),
      packages: _parsePackages(lines),
    );
  }

  /// Reads the tracked-assets table: header, separator, then 5-cell rows.
  List<AssetCredit> _parseAssets(List<String> lines) {
    final header = lines.indexWhere(
      (line) => line.trim().startsWith('| Asset(s) |'),
    );
    if (header == -1) {
      throw const FormatException(
        'no "| Asset(s) |" table header found in the attribution document',
      );
    }
    if (header + 1 >= lines.length ||
        !lines[header + 1].trim().startsWith('|-')) {
      throw const FormatException(
        'the tracked-assets header is not followed by a table separator',
      );
    }

    final assets = <AssetCredit>[];
    for (var i = header + 2; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('|')) {
        break; // the table ends at the first non-row line
      }
      final cells = _cells(line);
      if (cells.length != 5) {
        throw FormatException(
          'a tracked-assets row has ${cells.length} columns, expected 5: '
          '$line',
        );
      }
      assets.add(
        AssetCredit(
          assets: _plain(cells[0]),
          author: _plain(cells[1]),
          licence: _plain(cells[2]),
          source: _plain(cells[3]),
          // cells[4] records whether in-app attribution is required; the
          // screen credits everything anyway, so it needs no field here.
        ),
      );
    }
    return assets;
  }

  /// Reads the bullet list under `Current runtime packages:` and stops at the
  /// development-only list, which never ships and must not be credited.
  List<PackageCredit> _parsePackages(List<String> lines) {
    final heading = lines.indexWhere(
      (line) => line.trim() == 'Current runtime packages:',
    );
    if (heading == -1) {
      throw const FormatException(
        'no "Current runtime packages:" list in the attribution document',
      );
    }

    final packages = <PackageCredit>[];
    var inList = false;
    for (var i = heading + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        if (inList) {
          break; // a blank line closes the list
        }
        continue;
      }
      if (!line.startsWith('- ')) {
        break;
      }
      inList = true;
      final body = _plain(line.substring(2));
      final separator = body.indexOf(' — ');
      if (separator == -1) {
        throw FormatException(
          'a package line is not "name — licence": $line',
        );
      }
      packages.add(
        PackageCredit(
          name: body.substring(0, separator),
          licence: body.substring(separator + 3),
        ),
      );
    }
    return packages;
  }

  /// Table cells of one row, without the outer pipes.
  List<String> _cells(String row) {
    final parts = row.split('|');
    return [
      for (var i = 1; i < parts.length - 1; i++) parts[i].trim(),
    ];
  }

  /// Markdown-free display text: links keep their label, emphasis and code
  /// markers are dropped.
  String _plain(String cell) {
    return cell
        .replaceAllMapped(_link, (match) => match.group(1)!)
        .replaceAll('`', '')
        .replaceAll('*', '')
        .trim();
  }
}
