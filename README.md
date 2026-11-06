# FS25_AutoDriveEditorLink

[![Latest release](https://img.shields.io/github/v/release/SvenBrauns/FS25_AutoDriveEditorLink)](https://github.com/SvenBrauns/FS25_AutoDriveEditorLink/releases/latest)
[![Tests](https://github.com/SvenBrauns/FS25_AutoDriveEditorLink/actions/workflows/tests.yml/badge.svg)](https://github.com/SvenBrauns/FS25_AutoDriveEditorLink/actions/workflows/tests.yml)
[![License: GPL v3](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)
![Farming Simulator 25](https://img.shields.io/badge/game-FS25-6a9f2a)

Farming Simulator 25 mod, the game side of the [AutoDrive FS25 Editor](https://github.com/SvenBrauns/AutoDrive_Editor).

- **Game picture.** Renders the map from above, tile by tile, so the editor can show the map as the
  game draws it: roads, yards, buildings and fields as they are in your savegame.
- **Reload after saving.** When the editor saves the savegame the game is running, the mod loads
  the new network into the game. AutoDrive drives on it right away, no restart needed.

The editor and the mod talk only through files in
`Documents/My Games/FarmingSimulator2025/modSettings/FS25_AutoDriveEditorLink/`.
Single player only. Reloading needs the [AutoDrive](https://github.com/Stephan-S/FS25_AutoDrive) mod.

## Installation

1. Download `FS25_AutoDriveEditorLink.zip` from [Releases](https://github.com/SvenBrauns/FS25_AutoDriveEditorLink/releases/latest).
2. Put the zip, without unpacking it, into `Documents/My Games/FarmingSimulator2025/mods`.
3. Activate the mod for your savegame.

The editor's manual explains capturing the game picture and saving into a running game.

## Development

### Build

```powershell
./build.ps1
```

zips the mod into `Documents/My Games/FarmingSimulator2025/mods/FS25_AutoDriveEditorLink.zip`.
Pushing a tag like `v1.0.0` builds the zip on GitHub and publishes a release; the tag must match
the version in `modDesc.xml`, and `CHANGELOG.md` needs a section for it.

For development, link the repository into the mods folder instead (game closed, no zip of the
same name there), so the game reads the scripts from here and `adelReloadScripts` works:

```powershell
New-Item -ItemType Junction -Path "$HOME\Documents\My Games\FarmingSimulator2025\mods\FS25_AutoDriveEditorLink" -Target (Get-Location)
```

### Tests

Plain Lua 5.1 (the game's Lua version), from the repository root:

```
lua tests/run.lua
```

GitHub runs them on every push to `main` and before each release.

### Exchange format

[FORMAT.md](FORMAT.md) describes the files the editor and the mod exchange.

### Console commands (for testing)

- `adelTestCapture x z [n=1] [mPerPx=0.25] [waitMs=500]` writes a `request.xml` for an n × n
  block of the tile grid around x, z. The mod picks it up within a second.
- `adelCoeff [objects] [foliage]` shows or sets the distance factors used during captures
  (default 2.0 and 0) until the game is restarted.
- `adelTestReload <file>` loads an AutoDrive route file (root `routeExport`) into the running
  game, as the RoutesManager's import does. `<file>` is a full path or a file name in
  `modSettings/FS25_AutoDriveEditorLink/`.
- `adelReloadScripts` runs the mod's scripts again from the linked folder: changed functions
  apply without leaving the savegame. State (e.g. the status revision) is kept; not during a
  capture. Changes to `loadMap` or modDesc.xml still need a savegame reload.

## License

[GPL-3.0](LICENSE). This project has no connection to GIANTS Software or the AutoDrive team.
