# 006 · Tomb Explorer

Tomb Raider-style blocky 3D action-adventure. Explore a tomb, climb ledges,
dodge traps, pull levers, collect 3 relics, and reach the treasure.

- **Genre**: action-adventure / platformer
- **Engine**: Godot 4.7.2 (GL Compatibility)
- **Platform**: Android (arm64-v8a), portrait
- **Status**: playable (MVP)
- **Download**: see GitHub Releases

## Controls

- Left floating joystick: move (camera-relative, omnidirectional)
- Right **J** button: jump (tap twice = double jump)
- Walk into a marked ledge to auto-mantle (climb) up
- Walk over pressure plates / up to levers to open gates
- Avoid spike pits, sliding blades, and crumbling floors
- Collect coins for stars; find 3 relics to unlock the treasure sanctum

## Chambers

1. Entrance — climb + spike pit
2. Blade Hall — sliding blades + crumbling floor
3. Lever Gate — lever opens a gate (relic 1)
4. Pressure Path — pressure plate + spikes (relic 2)
5. Crumble Depths — crumble + blade + climb (relic 3)
6. Treasure Sanctum — climb + lever gate + treasure finale

Star rating: clear = 1, all coins = +1, under par = +1. Sequential unlock.

## Build

```bash
GODOT=~/tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe
"$GODOT" --headless --path . --import
"$GODOT" --headless --path .                      # headless regression bot (all 6 chambers)
"$GODOT" --headless --path . --export-debug "Android" build/006-tomb.apk
```

## Credits

Built in-house on the 002-obby core (player controller, camera, touch HUD,
voxel terrain, headless regression bot, Android export pipeline). Character &
decoration models from Kenney's CC0 Starter Kit 3D Platformer. All SFX/BGM
procedural. See [CREDITS.md](CREDITS.md). Code under MIT (see LICENSE).
