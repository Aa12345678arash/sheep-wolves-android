# WOLF-DUSK-AI-019 — Mobile touch targets

## Base
- Parent: `WOLF-DUSK-AI-018-AI-TURN-CAMERA`
- Branch: `WOLF-DUSK-AI-019-TOUCH-TARGETS`
- Scope: touch selection and board-node visibility only. No major character, meadow, or lighting redesign in this stage.

## Changes
- Increase each board-node ray-pick sphere from 0.92 to 1.02 world units.
- Increase the screen-space fallback tap radius from 54 to 70 pixels.
- Enlarge idle node pads from 0.19 to 0.25 and selected/legal pads from 0.34 to 0.44.
- Keep the 5×5 board graph, node positions, legal-move rules, camera behavior, and piece geometry unchanged.

## Automated acceptance
The existing player-control test now checks that all 25 nodes have touch areas, that the collision radius is at least 1.0, and that the fallback radius is at least 68 pixels. The mobile workflow is enabled for this branch and must pass project import, board/rules/AI/player-control tests, and Android debug APK export.

## Device acceptance required
After installing the generated APK on a phone, verify:
1. All 25 points can be selected reliably with a normal single-finger tap.
2. Neighboring points are not accidentally selected when tapping the intended point.
3. Selection and legal-destination pads are visibly easier to identify.
4. Two-finger camera gestures still work and one-finger taps do not unintentionally rotate the camera.
5. Existing AI turn flow and local two-player rules remain correct.
6. The app opens directly as an installable Android app, without opening the Godot editor.

This stage is not complete until automated checks pass and the user confirms real-device behavior.
