# Asset and third-party attributions

Every external asset that ships with the game must be listed here **before** it is
added to `assets/`. Assets with unclear or incompatible licences must not be
committed.

## Rules

1. Record the asset file/folder, its author or vendor, the licence, the source
   URL, and whether attribution is required in-app.
2. Keep the original licence text (or a link to it) next to the entry.
3. Placeholder art is only allowed if its licence is known; "found online" is not
   a licence.
4. If an asset's terms change or the source disappears, replace the asset rather
   than keeping it undocumented.
5. The credits screen reads this file at runtime — it ships in the app
   bundle as-is — so keep it current: what is not recorded here is not
   credited.

## Status

Phases 0–9 shipped with placeholder art drawn from Flutter/Flame primitives and
no audio, so the bundle carried no third-party content. Phase 10 added the
first shipped assets, all from Kenney or OpenGameArt and all CC0: six
gameplay SFX (converted Ogg → WAV for `audioplayers`), ten sprites for the
field, towers, enemies and shots (cropped to their art and squared at copy
time), and one background music loop (converted Ogg → MP3). No third-party
fonts. The credits screen renders this document directly from the bundle, so
an asset that is not recorded here does not appear in the credits — each new
asset must land here before it lands in `assets/`.

## Tracked assets

| Asset(s) | Author / vendor | Licence | Source | In-app attribution |
|---|---|---|---|---|
| `assets/audio/shot.wav`, `built.wav`, `upgraded.wav` — from *Interface Sounds 1.0*, converted Ogg → WAV | Kenney (kenney.nl) | CC0 1.0 — public domain, no attribution required ([licence text](http://creativecommons.org/publicdomain/zero/1.0/)) | https://kenney.nl/assets/interface-sounds | Not required; credited here and on the credits screen |
| `assets/audio/hit.wav`, `defeated.wav`, `leaked.wav` — from *Impact Sounds 1.0*, converted Ogg → WAV | Kenney (kenney.nl) | CC0 1.0 — public domain, no attribution required ([licence text](http://creativecommons.org/publicdomain/zero/1.0/)) | https://kenney.nl/assets/impact-sounds | Not required; credited here and on the credits screen |
| `assets/images/tower_*.png`, `enemy_*.png`, `projectile.png`, `map_grass.png`, `map_dirt.png` — 10 files from *Tower Defense (Top-Down) Pack*, cropped to their art | Kenney (kenney.nl) | CC0 1.0 — public domain, no attribution required ([licence text](http://creativecommons.org/publicdomain/zero/1.0/)) | https://kenney.nl/assets/tower-defense-top-down | Not required; credited here and on the credits screen |
| `assets/audio/music.mp3` — *Menu music loop (tiggo)*, converted Ogg → MP3 | qubodup (OpenGameArt) | CC0 1.0 — public domain, no attribution required ([licence text](http://creativecommons.org/publicdomain/zero/1.0/)) | https://opengameart.org/content/two-simple-game-music-loops | Not required; credited here and on the credits screen |

## Package licences

Third-party Dart/Flutter packages are tracked through `pubspec.yaml` and their
own licences, which ship with the app bundle. Packages added in later phases must
be compatible with the app's distribution licences; verify before adding.

Runtime packages were each reviewed against the `LICENSE` file in the pub
cache during Phase 13.

Current runtime packages:

- `flame` — MIT
- `flame_audio` — MIT
- `audioplayers` (transitive, via `flame_audio`) — MIT
- `flutter_riverpod` — MIT
- `go_router` — BSD-3-Clause (Copyright The Flutter Authors)
- `shared_preferences` — BSD-3-Clause (Copyright The Flutter Authors)
- `meta` — BSD-3-Clause (Copyright the Dart project authors)
- `flutter` SDK — BSD-3-Clause

Development-only packages (not shipped):

- `flame_lint` — BSD-3-Clause
- `flutter_launcher_icons` — MIT (regenerates launcher icons from
  `tool/icon/*.png`; ships nothing into the bundle)
- `flutter_test` (SDK)
