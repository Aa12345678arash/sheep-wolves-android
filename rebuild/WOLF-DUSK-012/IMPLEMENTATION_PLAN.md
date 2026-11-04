# WOLF-DUSK-012 — Victory, Tactical AI & Character Awareness

Base: WOLF-DUSK-011-MOBILE-PERFORMANCE at 4907e0058cb83998a41cdf0c475edf5ab0c0c2da.

This phase is isolated on WOLF-DUSK-012-VICTORY-AI. Do not modify the main branch or the WOLF-DUSK-011 branch.

## Non-negotiable constraints
- Preserve the canonical 5x5 board, 56 legal connections, 25 sheep, 3 wolves, turn order, capture rules, optional same-wolf chain capture, and win conditions.
- Preserve the improved WOLF-DUSK-011 mobile performance, camera framing, touch controls, and readable play area.
- No feature is complete until its behavior is tested. No APK is called install-ready until the Android export succeeds and the artifact is verified; on-device acceptance still requires the user's phone test.

## Ordered implementation plan

### 1. Verify and strengthen game logic and AI
- Run existing board/rules tests before changing behavior.
- Ensure easy, medium, and hard AI always proposes legal moves.
- Make difficulty levels meaningfully distinct: easy prioritizes simple legal choices; medium weighs immediate safety/capture opportunities; hard evaluates tactical threats, follow-up captures, mobility, and blocking.
- Add deterministic test positions for forced captures, threatened sheep, escape squares, blocked wolves, and chain-capture restrictions.
- Keep AI evaluation separate from authoritative game rules.

### 2. Character gaze and facing — approved requirement WOLF-DUSK-012-LOOK-AWARENESS
- Sheep face toward a legal available movement direction / intended destination, not an arbitrary fixed direction.
- On selection, orient the sheep toward the chosen legal destination; after moving, smoothly orient toward a sensible forward/available route.
- Wolves continuously but smoothly attend to sheep movement; when a target is selected for a capture, focus gaze on that target.
- Use low-cost interpolation and update only when the target/direction changes enough to matter; avoid per-frame expensive scene searches.
- Gaze must never alter legal moves, target selection rules, turn ownership, or game outcomes.
- If full 3D models expose head/eye pivots, animate those pivots; otherwise use a restrained head/body orientation fallback that remains readable from the phone camera.

### 3. Natural movement and capture feedback
- Smooth start/stop movement, restrained body/head motion, and clear capture feedback.
- Keep animation duration short and non-blocking; input and turn state must remain authoritative.
- Avoid physics-heavy effects or large numbers of dynamic lights/particles on mobile.

### 4. Match completion and score
- Clear winner and reason, remaining sheep / captures, celebratory or defeat feedback, and reliable restart/settings actions.
- Verify that restart resets every gameplay, timer, selection, score, and animation state.

### 5. Environment, audio, menus, and final polish
- Improve the meadow, lighting, and effects only after logic and controls pass.
- Keep music/effects independently controllable and respect pause/restart.
- Ensure all menu and in-game controls have working actions and clear labels.

## Acceptance gates
1. Board and rules automated tests pass.
2. AI legal-action tests pass for all three difficulties and representative tactical positions.
3. Gaze/facing tests verify target direction updates and no gameplay-state mutation.
4. Restart, pause/resume, victory/defeat, and menu controls pass.
5. Godot headless import/scene validation passes.
6. Android debug export produces a non-empty APK artifact.
7. User installs and tests on the target phone; only then may mobile acceptance be marked complete.

## Status
Planning and acceptance criteria only. Implementation, automated test execution, APK export, and on-device validation are not claimed by this document.