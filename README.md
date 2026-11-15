# 006 · Tomb Explorer

Tomb Raider-style blocky 3D action-adventure. Explore a tomb, climb ledges,
dodge traps, pull levers, collect 3 relics, and reach the treasure.

- **Author**: cykbot7 (bot7) · cykgames org — designed & built solo, wave 1 (2026-11-15)
- **Genre**: action-adventure / platformer
- **Engine**: Godot 4.7.2 (GL Compatibility)
- **Platform**: Android (arm64-v8a), portrait
- **Status**: playable (MVP) — headless regression green; on-device boot-verified
- **License**: MIT (code) · Kenney CC0 (models) · procedural audio
- **Download**: see GitHub Releases

> **Taking over / debugging?** Read the [Architecture](#architecture--file-map)
> and [Handoff / debugging guide](#handoff--debugging-guide) sections below, then
> [docs/CHECKPOINT.md](docs/CHECKPOINT.md) for decisions, the root-cause bug that
> was fixed, and open items. The in-game title screen also shows the author tag.

## Gameplay

One tomb, 6 hand-authored chambers, sequential unlock. Climb, jump, and dodge
your way to the end of each chamber. Three relics are hidden in chambers 3–5;
the final Treasure Sanctum only opens its goal once you hold all 3.

### Controls

- Left floating joystick: move (camera-relative, omnidirectional)
- Right **J** button: jump (tap twice = double jump)
- Walk into a marked ledge to auto-mantle (climb) up — no extra button
- Walk over pressure plates / up to levers to open gates (latched)
- Avoid spike pits, sliding blades, and crumbling floors
- Collect coins for stars; find 3 relics to unlock the treasure sanctum
- Desktop: WASD / arrows to move, Space to jump, Esc to pause
  (`emulate_touch_from_mouse` is on, so the joystick also works with a mouse)

### Chambers

1. Entrance — climb + spike pit
2. Blade Hall — sliding blades + crumbling floor
3. Lever Gate — lever opens a gate (relic 1)
4. Pressure Path — pressure plate + spikes (relic 2)
5. Crumble Depths — crumble + blade + climb (relic 3)
6. Treasure Sanctum — climb + lever gate + treasure finale (needs 3 relics)

Star rating: clear = 1, all coins = +1, under par = +1. Best result per chamber
is persisted; relics persist across chambers.

## Design origin / sources

- **In-house, not a fork.** Built on the sibling title **002-obby**'s core
  (same org): player controller, camera rig, touch HUD, chunked voxel terrain,
  checkpoint/respawn, headless regression bot, and the Android export pipeline.
  All tomb mechanics were authored fresh for this title.
- **Why no open-source base:** a GitHub search for a Tomb-Raider-style Godot
  project yields only `tr_lib` (a parser for classic TR level files), which
  needs copyrighted assets. Building on our own MIT 002 core was cleaner and
  fully headless-testable. See docs/CHECKPOINT.md "Key decisions / ruled out".
- **Models**: Kenney "Starter Kit 3D Platformer" (CC0). Character, cloud, flag,
  grass, colormap. Vendored under `assets_raw/starter-kit/` with its LICENSE.
- **Audio**: 100% procedural (`tools/gen_audio.py`); no third-party samples.
- Full attribution in [CREDITS.md](CREDITS.md). Code under [MIT](LICENSE).

## Architecture / file map

Godot 4.7.2, GL Compatibility renderer, portrait. All UI is built in code
(no `.tscn` UI widgets beyond the two scene roots). Autoload: `Game`.

Scene flow: `LevelSelect.tscn` (title / chamber select, main scene) → tap a
chamber → `Main.tscn` (gameplay). Headless runs skip LevelSelect and go
straight to Main.

| File | Role |
|------|------|
| `Game.gd` | **Autoload singleton.** Level index, progress (`user://progress.json`), sequential unlock, star/best records, cross-chamber relics (`relic_count()`, `RELICS_NEEDED=3`). `headless` flag. |
| `LevelSelect.gd` / `.tscn` | Title + chamber buttons, stars, total relics. Builds UI in code. Shows the author footer. Headless → jumps to Main. |
| `Main.gd` / `.tscn` | Gameplay orchestrator. Wires LevelGen/Player/HUD/CameraRig/Audio, finish flow, star rating, coin burst, haptics. Headless: prints `FINAL …` per chamber, auto-advances, `ALL_LEVELS_DONE` + quit. 180 s per-level timeout guard. |
| `LevelGen.gd` | **Data-driven course builder.** `LEVELS` table (6 chambers) is authoritative. A cursor walks a 4-dir path; step codes place geometry. Builds static terrain (one StaticBody3D + chunked ArrayMesh), hazards, gates, relics, and `level.nav` waypoints for the bot. |
| `Player.gd` | CharacterBody3D controller: joystick move, jump/double-jump, coyote/buffer, auto-mantle (`start_mantle`), checkpoint respawn. **Headless: waypoint-following bot** that reads `level.nav` and waits for `blade_safe()` before crossing blades. |
| `HUD.gd` | CanvasLayer: timer/coins/relics/falls bar, joystick + jump button, start/pause/finish panels, star rating, toasts, red fall flash. Headless auto-starts and prints `HUDREPORT` every 600 ticks. |
| `CameraRig.gd` | Follow camera + trauma/shake. |
| `Joystick.gd` / `JumpButton.gd` | Touch input widgets (floating stick, big jump key). |
| `Coin.gd` | Spinning coin collectible. |
| `Audio.gd` | Procedural SFX/BGM playback. |
| `tools/gen_audio.py` | Regenerates all audio assets. |
| `tools/gen_icon.py` | Regenerates `icon.png`. |
| `tools/test_joystick.*` | Standalone joystick test scene. |
| `export_presets.cfg` | Android arm64-v8a export. Package `com.cykgames.tomb`, label `TombExplorer`. |

### LevelGen step codes (the `LEVELS` table)

Inherited obby codes still parse: `P`=pad(w,l,dy) `G`=gap(d) `L`=lava(d)
`M`=mover(d) `B`=bounce `V`=vanish(n) `S`=spinner(w) `I`=ice(w,l)
`T`=turn(±1). Tomb codes:

- `C` climb ledge(h) — tall wall + auto-mantle grab zone
- `K` spike pit(d) — Area3D kill + cone visuals; jump over
- `X` sliding blade(w) — kill wall sweeping side-to-side
- `F` crumble(n) — floor collapses 0.7 s after stepped on, respawns 3 s later
- `W` lever(door_id) / `A` pressure plate(door_id) — opens a linked gate (latched)
- `D` gate(id,w) — blocking wall; collision off + faded when opened
- `R` relic(id) — golden idol; persisted in `Game.progress["relics"]`

Start (6×6) and goal (6×6) pads are added automatically. The Treasure Sanctum
has `"treasure": true`; its goal checks `Game.relic_count() >= 3`.

## Build & test

Requires Godot 4.7.2 (console build) and the Android export templates + SDK
for APK builds. Paths below use `~` (home) placeholders.

```bash
GODOT=~/tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe

# 1) Import assets (first run / after asset changes)
"$GODOT" --headless --path . --import

# 2) Headless regression: bot auto-plays all 6 chambers, exit 0 on success
"$GODOT" --headless --path .

# 3) Export Android APK (arm64-v8a, debug-signed)
"$GODOT" --headless --path . --export-debug "Android" build/006-tomb.apk
```

Expected headless tail (fresh progress): six `FINAL level=… stars=3` lines with
relics accumulating `0→1→2→3`, then `ALL_LEVELS_DONE`, exit code 0.

**Fresh-progress test:** delete the save before a headless run to watch relics
accumulate from 0:
`%APPDATA%/Godot/app_userdata/TombExplorer/progress.json` (Windows) or the
equivalent `user://` dir on your OS.

`build/` and `.godot/` are gitignored (not tracked).

## Handoff / debugging guide

Entry points, in order of usefulness:

1. **Reproduce logic fast, headless.** `"$GODOT" --headless --path .` runs the
   whole game with no device. If a chamber fails, the bot prints `FINAL …` /
   `TIMEOUT level=…` with position. This isolates game logic from touch/render.
2. **Level geometry / hazards** → `LevelGen.gd`. The `LEVELS` table is the
   single source of truth for chamber layout. `level.nav` (built here) is what
   the bot follows; a nav waypoint below a landing or before a checkpoint is a
   classic stall cause.
3. **Movement / climb / respawn** → `Player.gd`. Auto-mantle is `start_mantle`;
   the headless bot branch reads `level.nav` and `blade_safe()`.
4. **Progress / relics / unlock** → `Game.gd` (`user://progress.json`). Relic
   gating is `relic_count() >= RELICS_NEEDED`.
5. **UI / finish / stars** → `HUD.gd` + `Main.gd::_on_finished`.

### Known issues / open items (verify before release)

- **Treasure gate BLOCK path untested headless.** The bot always holds 3 relics,
  so the `relics < 3` refusal (count check + toast) is only logic-reviewed, not
  exercised. Test on device with a fresh save.
- **Balance tuned for the bot.** Par times are generous; blade/crumble timing
  was tuned so the headless bot passes. May need easing for humans.
- **Debug-signed.** No release keystore yet (same as 001/002). Do not ship to
  production until a release key is configured.
- **Touch feel not fully playtested.** Headless proves logic, not finger feel.
  On-device boot + render + touch were verified; extended human playtest pending.

### Root-cause bug already fixed (don't reintroduce)

`LevelGen._pad()` used to double-count `_cursor.y`
(`center = _cursor + dir*(l/2) + Vector3(0, top-THICK/2, 0)` with
`top = _cursor.y + dy`). Harmless at cursor y=0, but after a climb raised the
cursor, later pads landed 2× high → holes. Now uses absolute height:
`center = Vector3(_cursor.x, top-THICK/2, _cursor.z) + dir*(l/2)`.
Related fixes: climb nav targets the ledge **top**; grab zone spans full wall
height; mantle clears the jump buffer; each checkpoint adds a nav waypoint so
respawn resumes forward. Full write-up in docs/CHECKPOINT.md.

### Privacy / what is NOT in this repo

Public repo: no LAN IPs, device serials, user home paths, tokens, or internal
domains. Device-specific test facts live only in the org's internal notes.
`build/` and `.godot/` are gitignored. Keep it that way when adding logs.

## Credits

Built in-house by **cykbot7** on the 002-obby core. Models: Kenney CC0 Starter
Kit 3D Platformer. All SFX/BGM procedural. See [CREDITS.md](CREDITS.md).
Code under [MIT](LICENSE).