<!--
  ________________________________________________________________________
 / Copyright (c) 2026 Phobos A. D'thorga                                \
 |                                                                        |
 |           /\_/\                                                         |
 |         =/ o o \=    Phobos' PZ Modding                                |
 |          (  V  )     All rights reserved.                              |
 |     /\  / \   / \                                                      |
 |    /  \/   '-'   \   This source code is part of the Phobos            |
 |   /  /  \  ^  /\  \  mod suite for Project Zomboid (Build 42).         |
 |  (__/    \_/ \/  \__)                                                  |
 |     |   | |  | |     Unauthorised copying, modification, or            |
 |     |___|_|  |_|     distribution of this file is prohibited.          |
 |                                                                        |
 \________________________________________________________________________/
-->

# PhobosEPRCleanup

**Version:** 1.0.0 | **Requires:** Project Zomboid Build 42.14.0+ | PhobosLib 1.3.0+

A small utility mod that removes all **Extensive Power Rework (EPR)** data from save files, allowing you to cleanly uninstall EPR without lingering side effects.

## Problem

The EPR mod (Workshop ID 3643765614) crashes on load in certain PZ Build 42 versions, leaving orphaned data in save files that causes:

- **Power and water never shutting off** (EPR sets ElecShutModifier/WaterShutModifier to max int)
- **Water coolers showing "zone is offline"** (EPR modifies building power/water state)
- **Orphaned world modData** bloating save files

## What It Does

1. **Restores sandbox variables** -- reads EPR's backed-up original ElecShutModifier/WaterShutModifier values and writes them back to disk via `getSandboxOptions():set()` + `toLua()`
2. **Resets building state** -- calls `setHasElectricity(false)` / `setHasWater(false)` on all EPR-connected buildings, letting vanilla mechanics re-evaluate power
3. **Removes EPR world modData** -- deletes `EPR_GridData`, `EPR_PowerController`, `EPR_GlobalData`, and `EGO_GridData`
4. **Notifies the player** -- shows a modal dialog summarizing exactly what was cleaned

## What It Does NOT Do

- Does **not** scan every world object for `EPR_SpriteGenerator` markers on individual generators. These orphaned boolean markers are harmless and ignored by the game when EPR is not loaded.
- Does **not** modify save files on disk directly -- operates through PZ's normal modData API at runtime.
- Buildings not currently loaded in memory (far from the player) may retain EPR state until visited. Use `ForceRerun` if needed.

## Usage

1. **Unsubscribe from / disable EPR** (the mods are declared incompatible and cannot both be active)
2. Subscribe to **PhobosLib** and **PhobosEPRCleanup** on Steam Workshop
3. Enable both mods in your mod list
4. Load your save -- cleanup runs automatically on first load
5. Check the on-screen modal for results
6. Unsubscribe from PhobosEPRCleanup (and PhobosLib if no other Phobos mods are installed)

## Sandbox Options

| Option | Default | Description |
|--------|---------|-------------|
| Run EPR Cleanup | ON | Execute full EPR data removal on next load |
| Restore Sandbox Variables | ON | Restore ElecShutModifier/WaterShutModifier to pre-EPR values |
| Force Re-run | OFF | Clear guard flag and re-run cleanup (one-shot, resets after use) |

## Dependencies

| Mod | Workshop ID | Purpose |
|-----|-------------|---------|
| [PhobosLib](https://steamcommunity.com/sharedfiles/filedetails/?id=3668598865) | 3668598865 | World modData stripping, sandbox variable access |

## License

[MIT License](LICENSE)
