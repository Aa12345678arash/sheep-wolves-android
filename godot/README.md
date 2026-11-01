# گرگ و میش — WOLF-DUSK-004

Godot 4 isolated development branch. The tested Android 0.5.1 baseline and `main` remain unchanged.

## Current milestone
- Establish an independent Godot 4 project.
- Add a first 3D meadow scene and a 5×5 node-position layout.
- Keep the authoritative 56-connection graph and all turn/capture rules as explicit integration gates; do not approximate them.
- No claim of playable parity or Android APK until rule tests and device tests pass.

## Fixed gameplay requirements
- 5×5 board, 25 nodes, 56 connections.
- 25 sheep, five at each of the five starting nodes; every sheep is an individual unit.
- Three wolves placed freely by the wolf player; sheep move first.
- Wolves win at eight or fewer sheep; sheep win when all three wolves are blocked.
- Same-wolf chained captures; the optional second capture must follow the agreed three-second rule.

## Next implementation steps
1. Extract and document the exact 56 edges and legal-move rules from the 0.5.1 source.
2. Port rules into a renderer-independent game-state model and add automated tests.
3. Replace placeholder node markers with designed 3D board pieces and characters.
4. Add animations, camera, licensed music/SFX, and app icon.
5. Build and test Android APK before calling any release complete.

## Attribution
سازنده و معرفی‌کننده: آرش سلیمی
