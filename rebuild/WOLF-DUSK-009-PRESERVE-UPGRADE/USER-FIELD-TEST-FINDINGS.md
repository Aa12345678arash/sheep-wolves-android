# WOLF-DUSK-009 — Field Test Findings (2026-11-02)

Status: NOT ACCEPTED. The installed Android build was tested by the user and did not meet the acceptance criteria.

## Confirmed user-observed defects
1. Part of the play screen is clipped / not visible on the user's phone.
2. Gameplay and piece movement are not sufficiently smooth.
3. Sheep can move, but wolves cannot be selected or moved after initial placement.
4. Camera presentation is unsatisfactory. There are no player-selectable high, medium and close/deep camera views.
5. Music is too quiet, has no volume control, and the current composition is rejected by the user.
6. Overall graphics/presentation need substantial improvement.

## Required repair order
P0 — Gameplay correctness:
- Reproduce and fix wolf selection and movement in local two-player mode on Android.
- Verify the human-vs-AI path separately; AI turns must execute automatically and must not block local input.
- Test ordinary wolf movement, capture, optional same-wolf chain capture, and turn handoff.
- Add regression checks for turn transitions and invalid/valid wolf moves.

P0 — Screen fit and touch:
- Keep all board nodes and all controls visible on supported phone aspect ratios and safe areas.
- Make touch selection reliable for every board node, including wolves after a sheep move.
- Do not let HUD panels cover board touch targets.

P1 — Camera:
- Add explicit, persistent player controls for three camera presets: high overview, medium tactical, and close/deep.
- Do not force an unexpected camera change on every turn; retain a full-board overview option.
- Ensure every preset keeps the active board area and selected piece visible.

P1 — Performance:
- Profile/reduce per-frame work and excessive scene-node/material creation.
- Keep movement animation short, consistent and interrupt-safe.
- Verify on a physical Android device; editor/import success is not a performance test.

P1 — Audio:
- Replace the rejected procedural chord loop with a new, user-approvable original meadow/adventure theme.
- Add a visible music volume slider and mute toggle.
- Keep sound-effect volume independently adjustable.
- Respect Android audio focus and avoid unexpectedly loud startup.

P2 — Visual quality:
- Improve the board, pieces, lighting, environment and animation without obscuring legal moves or reducing touch accuracy.
- Preserve the established game rules, AI, local two-player mode, icon, and creator credit.

## Acceptance gate
A source change or green CI build is not a completed milestone. A candidate build is accepted only after:
- automated rules checks pass;
- Android APK export succeeds;
- the APK installs and launches on the user's phone;
- the complete screen is visible;
- both sheep and wolves can be selected and moved in a real match;
- AI and local two-player modes are separately verified;
- camera presets and volume controls work;
- performance and audio are reviewed by the user.

Do not modify main or earlier development branches. All work stays on WOLF-DUSK-009-PRESERVE-UPGRADE until the user accepts it.
