# WOLF-DUSK-008-APK — field-test rejection and acceptance criteria

## User field-test result (2026-11-02)
The installed APK was rejected in real-device use. It did not open directly into a usable game, did not remain portrait/full-screen, HUD/information obstructed the playfield, the layout was unsuitable, the game felt slow, pieces were too small/unclear, and the overall visual quality was worse than the original game.

## Non-negotiable constraints
- Do not modify `main`, the prior 0.5.1 build, or the original playable version.
- All corrections must remain isolated on `WOLF-DUSK-008-FIX`.
- Preserve the canonical board and gameplay rules: 25 nodes A1–E5, 56 edges, 25 sheep (five at each E1–E5 start), three wolves, sheep move first, wolf win at 8 or fewer sheep, sheep win when all three wolves are blocked, and chain capture only by the same wolf with optional second capture.
- Do not call the next APK successful until it is installed and tested on the user's phone.

## Required acceptance criteria
1. Android launches directly into a clear playable screen; no unnecessary intro or modal overlay blocks the game.
2. Portrait orientation is enforced consistently by both Godot project settings and Android export settings.
3. Immersive full-screen presentation; no system bars or app content overlapping the board.
4. Responsive portrait layout: the board is large, centered, legible, and not covered by informational panels; controls and status are compact and placed in dedicated safe zones.
5. Sheep and wolves are visibly larger and more distinguishable; counters and node targets remain readable.
6. Improve frame rate and touch response on mid-range Android devices; avoid unnecessary real-time shadows and excess per-frame work.
7. Preserve the original rules and all prior versions; develop and export only from this isolated branch.
8. Validate project import, headless startup, rule tests, Android APK export, APK installation, and real-device gameplay before acceptance.

## Confirmed source-level findings
- `project.godot` currently declares a 1280x720 viewport and `window/handheld/orientation=0` (landscape).
- The Android export preset declares immersive mode and orientation=1, but this conflicts with the project-level landscape declaration and must be made consistent.
- The launch scene uses `scripts/meadow.gd`; editing `scripts/main.gd` alone cannot fix the shipped UI.
- `meadow.gd` uses fixed pixel HUD dimensions/positions (e.g. 690px-wide panel and fixed offsets) and a large initial setup overlay, which are unsuitable for a narrow portrait viewport.
- The current scene uses procedural mesh characters; the user requires a clearly visible quality improvement, not merely a successful export.

## Work sequence
A. Fix portrait/full-screen launch and responsive UI.
B. Reframe/scale the board and increase piece readability.
C. Profile and optimize mobile rendering and interaction.
D. Improve character/environment art without changing gameplay.
E. Run CI and produce a new test APK; clearly label it as unaccepted until phone testing.
