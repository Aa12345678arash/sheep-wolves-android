# WOLF-DUSK-009-PRESERVE-UPGRADE

## Mission
Upgrade the existing playable game in place: preserve the current Godot game, its established rules, controls, state flow, and character identity while improving presentation, clarity, responsiveness, and completeness. This is not a new game and not a replacement prototype.

## Branch safety
- This branch was created from `WOLF-DUSK-008-FIX` at the existing project state.
- Do not modify `main`, `WOLF-DUSK-004-GODOT`, `WOLF-DUSK-007-REBUILD`, or `WOLF-DUSK-008-FIX`.
- Keep all work for this stage on `WOLF-DUSK-009-PRESERVE-UPGRADE`.
- Do not remove or replace the current gameplay implementation in `rebuild/WOLF-DUSK-007/godot/scripts/meadow.gd`.
- Any visual work must remain separate from and must not alter the game rules/state engine unless a verified gameplay defect is found.

## Preserved gameplay contract
- 25 board nodes and 56 connections.
- 25 sheep, initially five at each of E1–E5.
- Three wolves are placed on empty nodes; sheep move first.
- Normal moves follow connected edges to empty nodes.
- Wolf capture jumps over an adjacent sheep to an empty connected landing node.
- Optional second capture is made only by the same wolf, within the existing three-second window.
- Wolves win when sheep count reaches 8 or fewer.
- Sheep win when all three wolves have no legal move.
- Keep local two-player and the existing AI mode; do not silently remove either.

## Upgrade priorities
1. Preserve and verify the currently playable interaction loop before visual changes.
2. Make the complete board visible and touch targets reliable on Android portrait screens; no clipped or miniature board.
3. Keep HUD controls in safe zones and prevent panels from obscuring the board.
4. Improve performance by reducing unnecessary node/resource recreation and per-frame work without reducing gameplay clarity.
5. Improve the existing sheep, wolf, meadow, lighting, and movement presentation incrementally; do not replace the game with a mockup.
6. Keep existing music and sound controls functional; retain the app identity and creator credit: «سازنده و معرفی‌کننده: آرش سلیمی».

## Source observations at branch creation
- Launch scene: `rebuild/WOLF-DUSK-007/godot/scenes/main.tscn`, attached script: `res://scripts/meadow.gd`.
- Main gameplay implementation: `rebuild/WOLF-DUSK-007/godot/scripts/meadow.gd`.
- Rule/state implementation is separated into `scripts/game_state.gd`, with board graph in `scripts/board_graph.gd`.
- The inspected Godot project config currently specifies a 720x1280 viewport, portrait handheld orientation, and canvas-item stretch. Android export preset currently specifies immersive mode and portrait orientation. These settings must still be confirmed in the exported APK on a real phone; source settings alone are not acceptance.
- The current meadow script rebuilds node visuals during board refresh and creates detailed procedural character meshes. Profile this path before making performance claims.
- Existing 008 acceptance notes contain a conflicting statement about landscape project settings. Re-check the actual config and APK behavior rather than copying that statement blindly.

## Definition of done
No release or stage may be called successful until all of the following are verified:
- Godot project imports and starts without script/runtime errors.
- Automated board and rules tests pass.
- Android APK export succeeds and the exact APK artifact is identified.
- APK installs and opens on the user's phone in the intended orientation/full-screen layout.
- Real-device tests confirm sheep selection/movement, wolf movement/capture, same-wolf chain capture, both win conditions, restart, AI/local modes, music and touch responsiveness.
- The user confirms the board is clear, complete, and visually better than the previous playable version.

Until then, describe builds as previews only and report exactly what has and has not been tested.
