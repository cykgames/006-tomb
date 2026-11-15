# 006-tomb — DEV CHECKPOINT (2026-11-15)

Status: **playable MVP**, headless regression green, APK built + on-device
boot/render/touch verified (Android arm64 test phone). NOT pushed (awaiting
consent). Built solo by **cykbot7** on user "go" (wave 1).

Attribution / handoff pass (2026-11-15): author tag `cykbot7` added to the
in-game title screen (LevelSelect.gd), README.md, and CREDITS.md. README.md is
now the takeover / debugging guide (design sources, architecture/file map,
step codes, build/test, known issues). LevelGen.gd header docstring corrected
(was stale "16 levels" inherited from 002; LEVELS table = 6 tomb chambers).

## What was built

Tomb Raider-style blocky 3D action-adventure on the 002-obby core (Godot
4.7.2, GL Compatibility, Android arm64, portrait). 6 hand-authored chambers
in one tomb, 3 relics gate the treasure finale.

Reused from 002 (read-only source): Player.gd controller (joystick, double
jump, coyote/buffer, ice, bounce, checkpoint respawn, headless nav bot),
CameraRig, Joystick/JumpButton/HUD, Audio, chunked ArrayMesh voxel terrain,
LevelSelect, Game progress autoload, export_presets pipeline, Kenney CC0 assets.

New tomb mechanics (LevelGen.gd step codes + Player.gd):
- `C` climb: tall ledge wall + auto-mantle grab zone (Player.start_mantle
  smooth pull-up; no extra button — touch friendly).
- `K` spike pit: Area3D kill (respawn) + metal cone visuals; jump over.
- `X` sliding blade: kill wall sweeping side-to-side; headless bot waits at
  the near edge until `blade_safe()` (|sin|>0.45) then crosses.
- `F` crumbling floor: collapses 0.7s after stepped on, respawns after 3s.
- `W` lever / `A` pressure plate: proximity/step activated, open a linked
  gate (latched). Each sits on its own floor pad.
- `D` gate: blocking wall, collision disabled + faded when opened.
- `R` relic: golden idol collectible; 3 persisted across chambers in
  Game.progress["relics"]; treasure goal gated on Game.relic_count()>=3.
- TOMB theme: sandstone, dark sky, emissive torches, ambient 0.9.

## Evidence (verified)

Headless regression bot, fresh progress (build/headless.log), exit 0:
```
FINAL level=0 name=ENTRANCE        time=6.39  falls=0 coins=6/6 stars=3 relics=0
FINAL level=1 name=BLADE HALL      time=11.93 falls=1 coins=6/6 stars=3 relics=0
FINAL level=2 name=LEVER GATE      time=8.35  falls=0 coins=5/5 stars=3 relics=1
FINAL level=3 name=PRESSURE PATH   time=8.78  falls=0 coins=6/6 stars=3 relics=2
FINAL level=4 name=CRUMBLE DEPTHS  time=8.54  falls=0 coins=5/5 stars=3 relics=3
FINAL level=5 name=TREASURE SANCTUM time=6.73 falls=0 coins=3/3 stars=3 relics=3
ALL_LEVELS_DONE
```
Relics accumulate 0->1->2->3 (chambers 3/4/5); treasure sanctum clears with 3.

APK: `build/006-tomb.apk` = 28,406,868 bytes (28.4 MB), arm64-v8a only,
debug-signed, export exit 0 (build/export.log).

Privacy: worktree scan (114 text files) = 0 sensitive hits (LAN IP / device
serial / user path / token / internal domain). build/ and .godot/ gitignored.

## Key decisions / ruled out

- **Auto-mantle climb** (walk/jump into ledge zone -> smooth pull-up) chosen
  over a dedicated climb button: fewer touch controls, headless-testable.
- **Latched gates** (lever/plate opens permanently) over timed/hold gates:
  simpler, bot passes without timing AI. Puzzle is spatial (reach the switch).
- **Cross-level relics + level-local treasure gate**: relics persist in Game;
  the final chamber's goal checks the total. Keeps the finale self-contained.
- **No fork**: GitHub search "tomb raider godot" yields only tr_lib (classic
  TR level parser, needs copyrighted assets). Built in-house on 002 instead.

## Root-cause bug fixed (important)

`_pad()` computed `center = _cursor + dir*(l/2) + Vector3(0, top-THICK/2, 0)`
where `top = _cursor.y + dy` — this **double-counts `_cursor.y`**. With the
cursor at y=0 (002's common case) it is harmless, but after a climb raises the
cursor to 3.5 every later pad landed at y6 instead of y3.5, leaving a 3.5m
hole the bot fell into. Fixed to absolute height:
`center = Vector3(_cursor.x, top-THICK/2, _cursor.z) + dir*(l/2)`.
Also fixed: climb nav targets the ledge TOP (a base waypoint sat below the
landing and never advanced); grab zone spans full wall height (a jumping bot
otherwise flies over it); mantle clears jump buffer; each checkpoint adds a
nav waypoint so respawn resumes forward (nearest-nav search otherwise picked
a waypoint before the checkpoint).

## Open items / next verification

- On-device boot/render/touch verified; extended human feel-test pending.
  Headless proves logic, not touch feel.
- Treasure gate BLOCK path (relics<3) not headless-tested (bot always has 3);
  logic is a simple count check + toast, verify on device.
- Debug-signed (no release keystore, same as 001/002).
- Balance: par times generous; blade/crumble timing tuned for the bot, may
  need easing for humans. More chambers / polish = post-MVP.
- LICENSE = MIT added for this in-house title (001/002 had none); adjust if
  the org prefers a different default.

## Reproduce

```bash
GODOT=~/tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe
"$GODOT" --headless --path . --import
"$GODOT" --headless --path .                       # bot clears all 6, exit 0
"$GODOT" --headless --path . --export-debug "Android" build/006-tomb.apk
```
Fresh-progress test: delete %APPDATA%/Godot/app_userdata/TombExplorer/progress.json
before the headless run to see relics accumulate from 0.
