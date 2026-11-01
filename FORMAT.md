# Exchange format, version 1

Editor and mod talk only through files in
`Documents/My Games/FarmingSimulator2025/modSettings/FS25_AutoDriveEditorLink/`.
Both sides check `format`; a file with another format is not read ("please update").

## Rules

- **The editor writes atomically**: `<name>.tmp`, then rename.
- **The mod cannot rename.** Its answers end with an empty `.done` marker written last; read a
  file only once its marker exists. `status.xml` has no marker: it is written in place every
  second, so a reader that fails to parse it tries again a second later.
- Coordinates are the game's world coordinates (x, z; the map centre is 0, 0, −z is north).
- `map` is the savegame's `mapId` (e.g. `FS25_Thueringen_2_0_16x.SampleModMap`), `savegame` the
  savegame slot number.

## status.xml (mod, every second while a map is loaded)

```xml
<status format="1" revision="812" modVersion="0.1.0.0" map="FS25_Thueringen_2_0_16x.SampleModMap"
        savegame="1" time="2026-11-01T14:03:22"/>
```

`revision` counts up with each write; `time` is the PC's local time. An old `time` means the game
is closed or no map is loaded.

## request.xml (editor)

```xml
<request format="1" id="17" type="pictures" map="FS25_Thueringen_2_0_16x.SampleModMap" savegame="1">
  <pictures mPerPx="0.25" res="2000" mode="raw_alpha" altitude="150" waitMs="500"
            firstWaitMs="3000" dayTime="12" weather="SUN">
    <tile col="3" row="7" x="-2346" z="-406"/>
  </pictures>
</request>
```

- `id`: an integer, new for each request. The mod handles a request once: it skips an id it has
  just handled and an id that already has a `result_<id>.xml`. The mod never deletes `request.xml`.
- `type`: only `pictures` so far.
- The mod checks `map` and `savegame` against the loaded game and answers `error` if they differ.
- `pictures`: all attributes required.
  - `mPerPx`, `res`: the tile is `res` × `res` pixels and covers `res · mPerPx` metres.
  - `mode`: `renderScreenshot` mode, `raw_alpha` (RGBA PNG).
  - `altitude`: camera height above the ground at the tile centre, m.
  - `firstWaitMs`, `waitMs`: real time between moving the camera and rendering, for the first and
    every further tile.
  - `dayTime` (hour), `weather` (`SUN`): set once at the start. They stay set after the capture.
- `tile`: grid cell `col`, `row` and its centre `x`, `z`. Rendered in the order given.

During a capture the mod hides the HUD, sets the five distance factors to fixed values (object
draw distance, LOD, terrain LOD: 2.0; foliage view and foliage LOD: 0, so foliage LOD bands do
not draw rings around the camera), and puts camera, HUD and factors back at the end, also on
cancel and error.

## Per tile (mod)

`pictures_<id>/tile_<col>_<row>.png`, then the empty marker `pictures_<id>/tile_<col>_<row>.done`.
The editor deletes both after reading.

## cancel_<id> (editor)

An empty file. The mod checks for it after each tile, stops, and answers `cancelled`.
The editor deletes it.

## result_<id>.xml (mod, at the end), then result_<id>.done

```xml
<result format="1" id="17" status="done" message="">
  <tile col="3" row="7" groundY="62.4" waitSec="0.51" renderSec="1.12"/>
</result>
```

- `status`: `done` | `cancelled` | `error`; `message` says why for `error`.
- One `tile` per finished tile: ground height at the centre, real wait and render time in seconds.
