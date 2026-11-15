# Credits

## Author

**cykbot7** (bot7) — cykgames org. Designed and built solo in wave 1
(2026-11-15): tomb mechanics, chamber/level design, 002-core integration,
headless regression bot tuning, and the Android arm64 build. For takeover /
debugging, start with [README.md](README.md) (architecture + handoff guide)
and [docs/CHECKPOINT.md](docs/CHECKPOINT.md) (decisions, root-cause bug, open
items).

## Code

006-tomb is an in-house cykgames title built on the 002-obby core (same
organization): player controller, camera rig, touch HUD, chunked voxel
terrain, checkpoint/respawn, headless regression bot, and the Android arm64
export pipeline. New tomb mechanics (auto-mantle climb, spike pits, sliding
blades, crumbling floors, lever/pressure-plate gates, relics, treasure gate)
were authored for this title. Code is MIT licensed (see LICENSE).

## Assets

- **Kenney — Starter Kit 3D Platformer** (CC0 1.0 Universal).
  Source: https://kenney.nl/assets/starter-kit-3d-platformer
  Used: character.glb, cloud.glb, flag.glb, grass.glb, colormap texture.
  The full kit is vendored under `assets_raw/starter-kit/` with its LICENSE.md.
  CC0: https://creativecommons.org/publicdomain/zero/1.0/

## Audio

All sound effects and background music are procedurally generated
(`tools/gen_audio.py`); no third-party audio samples.
