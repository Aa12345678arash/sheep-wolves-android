# WOLF-DUSK-010 — Baseline and Evidence Register

- Master tracking ID: `WOLF-DUSK-010-MASTER-ROADMAP`
- Active branch: `WOLF-DUSK-009-PRESERVE-UPGRADE`
- Baseline commit before this register: `66c7b3871a2c51da485f8a153f2b17347124b06d`
- Recorded: 2026-11-02

## Protected baseline

The active branch is the only branch authorized for this stage. No changes were made to `main`, `WOLF-DUSK-004-GODOT`, `WOLF-DUSK-007-REBUILD`, or `WOLF-DUSK-008-FIX`.

Key baseline source files:
- Main scene: `rebuild/WOLF-DUSK-007/godot/scenes/main.tscn`
- Gameplay/UI/input: `rebuild/WOLF-DUSK-007/godot/scripts/meadow.gd`
- Rules/state: `rebuild/WOLF-DUSK-007/godot/scripts/game_state.gd`
- Board graph: `rebuild/WOLF-DUSK-007/godot/scripts/board_graph.gd`
- AI: `rebuild/WOLF-DUSK-007/godot/scripts/ai_opponent.gd`
- Automated tests: `rebuild/WOLF-DUSK-007/godot/tests/validate_rules.gd`
- Android export preset: `rebuild/WOLF-DUSK-007/godot/export_presets.cfg`

## CI and build evidence

- Rule-check workflow run: [41504224098](https://github.com/Aa12345678arash/sheep-wolves-android/actions/runs/41504224098) — completed successfully.
- Android APK workflow run: [41504224141](https://github.com/Aa12345678arash/sheep-wolves-android/actions/runs/41504224141) — completed successfully.
- Artifact: `wolf-dusk-009-android-preview`
- Artifact ID: `13169507797`
- Size: 27,262,337 bytes
- SHA-256: `460cc001d3a82b678cba41398876876e9e62c02c6c410e4836993935b5cd1e5d`
- Expiry shown by GitHub: 2026-11-16.
- This artifact is a preview. It has not been installed or accepted on the owner's physical phone.

## User-reported acceptance failures carried forward

1. Part of the game screen is clipped.
2. Gameplay/movement is not smooth enough.
3. Wolves could not be selected/moved after placement in the user's installed build.
4. Three selectable camera views are missing.
5. Music is too quiet, not liked, and has no volume control.
6. Overall visual quality needs improvement.
7. User reported that the game-mode selection was absent in the earlier installed build; a setup menu has since been added in source and its latest APK export succeeded, but the menu has not yet been rechecked on the phone.

## Audit finding and immediate correction

The UI code schedules AI turns after normal moves, but the manual wolf-placement branch previously returned without scheduling the AI response. In AI mode with the human controlling wolves, this could leave the match waiting after the third wolf was placed. The active branch now schedules the AI turn after a placement attempt; the AI scheduler itself only acts when it is the computer's turn.

The automated rules test is extended to cover a normal wolf move immediately after a legal sheep move. This adds rules regression coverage, but it does not simulate Android touch input or replace a real-device test.

## Acceptance status

- Godot import / parse: passed in the referenced CI run.
- Automated rules checks: passed in the referenced CI run before the new regression assertion; rerun required after the new commit.
- Android APK export: passed in the referenced CI run.
- Physical-device installation: not verified.
- Full-screen fit, wolf touch selection, AI/local match completion, camera presets, audio controls, and user acceptance: not verified.

No release or phase completion is claimed by this register.
