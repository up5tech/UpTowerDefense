/// A miniature `docs/ASSET_ATTRIBUTIONS.md` with the real document's shape:
/// one tracked-assets table, then the runtime package list followed by the
/// development-only one, which must never be credited.
const String attributionMarkdown = '''
# Asset and third-party attributions

## Tracked assets

| Asset(s) | Author / vendor | Licence | Source | In-app attribution |
|---|---|---|---|---|
| `assets/audio/shot.wav` — from *Test Sounds 1.0* | Test Author (example.com) | CC0 1.0 — public domain ([licence text](http://creativecommons.org/publicdomain/zero/1.0/)) | https://example.com/sounds | Not required |
| `assets/images/tower_ranger.png` — from *Test Pack* | Another Author | CC-BY 3.0 ([licence](https://creativecommons.org/licenses/by/3.0/)) | https://example.com/art | Credited here |

## Package licences

Current runtime packages:

- `flame` — MIT
- `flutter` SDK — BSD-3-Clause

Development-only packages (not shipped):

- `flame_lint` — BSD-3-Clause
''';
