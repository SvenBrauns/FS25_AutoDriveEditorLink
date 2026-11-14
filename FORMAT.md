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
<status format="1" revision="812" modVersion="1.0.0" map="FS25_Thueringen_2_0_16x.SampleModMap"
        savegame="1" time="2026-11-01T14:03:22"/>
```

`revision` counts up with each write; `time` is the PC's local time. An old `time` means the game
is closed or no map is loaded.

## request.xml (editor)

```xml
<request format="1" id="17" type="pictures" map="FS25_Thueringen_2_0_16x.SampleModMap" savegame="1">
  <pictures mPerPx="0.25" res="2000" mode="raw" altitude="150" waitMs="500"
            firstWaitMs="3000" dayTime="12" weather="SUN">
    <tile col="3" row="7" x="-2346" z="-406"/>
  </pictures>
</request>
```

- `id`: an integer, new for each request. The mod handles a request once: it skips an id it has
  just handled and an id that already has a `result_<id>.xml`. The mod never deletes
  `request.xml`; the editor deletes it with all other exchanged files (answers, cancel files,
  tiles; all but `status.xml`) when a capture ends and before it writes a new request.
- `type`: `pictures`, `reload`, `vehicles` or `park` (below).
- The mod checks `map` and `savegame` against the loaded game and answers `error` if they differ.
- `pictures`: all attributes required.
  - `mPerPx`, `res`: the tile is `res` × `res` pixels and covers `res · mPerPx` metres.
  - `mode`: `renderScreenshot` mode, `raw` (24-bit RGB; `raw_alpha` gives 32-bit RGBA).
  - `altitude`: camera height above the ground at the tile centre, m.
  - `firstWaitMs`, `waitMs`: real time between moving the camera and rendering, for the first and
    every further tile.
  - `dayTime` (hour), `weather` (`SUN`): set once at the start. At the end, also on cancel and
    error, the mod sets the weather type back and the time to the old time plus the time the
    capture took.
- `tile`: grid cell `col`, `row` and its centre `x`, `z`. Rendered in the order given.

During a capture the mod hides the HUD, sets the five distance factors to fixed values (object
draw distance, LOD, terrain LOD: 2.0; foliage view and foliage LOD: 0, so foliage LOD bands do
not draw rings around the camera), and puts camera, HUD and factors back at the end, also on
cancel and error.

### reload

```xml
<request format="1" id="18" type="reload" map="FS25_Thueringen_2_0_16x.SampleModMap" savegame="1">
  <reload file="network_18.xml">
    <marker old="2" new="0"/>
    <marker old="3" new="2"/>
  </reload>
</request>
```

- `file`: a file name in the exchange folder (no path), an AutoDrive route file (root
  `routeExport`, as the RoutesManager writes it). The editor writes it before the request.
- The mod loads it into the running game as the RoutesManager's import does
  (`AutoDrive.readGraphFromXml`, then `AutoDriveRoutesUploadEvent`): nodes, markers and groups
  are replaced. It runs within one frame; no cancel.
- `marker` (optional, any number): a marker whose number changes, `old` its number in the game
  before, `new` its number in the file, `0` if it was deleted. Unlisted markers keep their number.
  After loading, the mod moves the vehicles' targets and parking positions (AutoDrive keeps them
  as marker numbers) along: a deleted target becomes marker 1, a deleted parking position none, as
  when a marker is deleted in the game. The targets are read before the upload and set anew in
  any case, also without `marker` entries: after the upload AutoDrive points them to the marker
  on the same node id, and the editor's saved file has renumbered node ids.

### vehicles

```xml
<request format="1" id="19" type="vehicles" map="…" savegame="1"/>
```

The vehicles AutoDrive can park: those of a farm (not trains) that AutoDrive drives or that can
be attached (not pallets). See the result below.

### park

```xml
<request format="1" id="20" type="park" map="…" savegame="1">
  <park>
    <vehicle uniqueId="vehicle494b759a0511842498a997124b755b10" marker="5"/>
    <vehicle uniqueId="vehicle9105f3616605497b14f90e808c307416" marker="0"/>
  </park>
</request>
```

Sets the parking position of each vehicle to the marker number, `0` removes it, as AutoDrive's
HUD does (`advd:setParkDestination`). The game saves it with its next save. Answers `error`
naming the unique ids not found; the others are set.

## Per tile (mod)

`pictures_<id>/tile_<col>_<row>.dds` (uncompressed DDS, 12 MB at 2000², readable with Pillow), then
the empty marker `pictures_<id>/tile_<col>_<row>.done`.
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
- For `reload`, when `done`:
  `<reload nodes="113021" markers="54" groups="6" readSec="1.2" uploadSec="0.6"/>`, the counts
  loaded and the real time for reading the file and replacing the network; `vehicles` (since
  1.1.0) the number of vehicles whose parking position moved.
- For `vehicles`, when `done`, one element per vehicle:
  `<vehicle uniqueId="vehicle…" filename="data/vehicles/fendt/vario1000/vario1000.xml"
  name="Fendt 1000 Vario" driverName="Vario 1" attachedTo="vehicle…" park="5"/>`.
  `filename` as in `vehicles.xml` (`data/…` or `$moddir$<mod>/…`), `name` brand and name,
  `driverName` AutoDrive's driver name (empty for implements), `attachedTo` the unique id of the
  vehicle it hangs on (empty if none), `park` the parking marker number (`-1`: none).
