# FS25_AutoDriveEditorLink

Farming Simulator 25 mod, the game side of the [AutoDrive Editor](https://github.com/SvenBrauns/AutoDrive_Editor).
It renders the map from above as picture tiles for the editor's map view. The editor and the mod
talk through files in `modSettings/FS25_AutoDriveEditorLink/`; the format is in [FORMAT.md](FORMAT.md).

Single player only.

## Build

```powershell
./build.ps1
```

zips the mod into `Documents/My Games/FarmingSimulator2025/mods/FS25_AutoDriveEditorLink.zip`.

## Tests

Plain Lua 5.1 (the game's Lua version), from the repository root:

```
lua tests/run.lua
```

## Console commands (for testing)

- `adelTestCapture x z [n=1] [mPerPx=0.25] [waitMs=500]` writes a `request.xml` for an n × n
  block of the tile grid around x, z. The mod picks it up within a second.
- `adelCoeff [objects] [foliage]` shows or sets the distance factors used during captures
  (default 2.0 and 0) until the game is restarted.
- `adelTestReload <file>` loads an AutoDrive route file (root `routeExport`) into the running
  game, as the RoutesManager's import does. `<file>` is a full path or a file name in
  `modSettings/FS25_AutoDriveEditorLink/`.
