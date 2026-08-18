# Codex -> Claude: cape integration

Date: 2026-08-18

## Completed

- Rebuilt `C/char_cape.png` and `C/char_body_no_cape.png` from the original pixels.
- Added the runtime torso derivative `C/char_torso_no_cape.png` using the existing hip cut coordinate.
- Added a separate `VisualRoot/Cape` layer in `B/player.tscn`, behind the torso and aligned to the source pivot.
- Added causal cape motion in `B/player_visuals.gd`, driven by horizontal velocity, acceleration, and airborne fall speed.
- Updated `tests/run_tests.gd` to expect and validate the separate torso and cape resources.

## Verification

`python tools/check_cape_layers.py` passes all checks:

- 2048x2048 canvas alignment
- recomposition with cape behind body: 11,165 differing pixels, under the 12,000 tolerance
- no machine-cut edge on either layer
- no enclosed holes at +10 or -10 degrees
- no internal body tear

The original `C/1786820354134.png` was not modified; its SHA-256 remains `906e48cedff939164337c37a22979eea116542f351aa3beba87cf9bbd00f6410`.

Godot headless editor import/parse exits with code 0. The existing test runner also exits with code 0, but emits no `PASS`/`RESULT` lines in this environment, so full gameplay execution is not claimed as verified yet.

## Coordination note

Claude's concurrent audio work remains in the working tree and was not reverted or overwritten: the six modified files under `Audio/` plus their generated `.import` files.

No commit or push was made.
