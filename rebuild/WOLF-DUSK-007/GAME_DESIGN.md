# WOLF-DUSK-007 — Independent Rebuild

This directory is a clean, independent Godot 4 project. It must not reuse the previous game's UI, scenes, scripts, or visual layout. The legacy project remains untouched for reference only.

## Product direction
- Title: گرگ و میش؛ راز دشت سبز
- Credit, exactly: سازنده و معرفی‌کننده: آرش سلیمی
- Target: Android phones, landscape orientation.
- Visual identity: polished stylized 3D storybook meadow; readable board; expressive sheep and wolves; warm daylight, natural terrain, trees, rocks and paths.
- UI: designed from scratch, large touch targets, clear Persian RTL labels, no oversized plain form dialog, no obscuring the board.
- Audio: optional, freely licensed/original ambient game music with mute control. Do not bundle unlicensed tracks.

## Canonical gameplay rules (preserve)
1. Board is a 5×5 node layout with 56 valid connections.
2. There are 25 sheep, initially distributed as five sheep on each of five designated starting nodes.
3. There are three wolves; wolves may be placed freely on legal unoccupied nodes during setup.
4. Sheep make the first move.
5. A sheep may move only along a valid connection to an unoccupied adjacent node.
6. A sheep with no legal move is not selectable. The player can select another movable sheep; invalid selection must never trap the turn.
7. Wolves move along valid connections and capture sheep according to the established board's capture edges/rules. Captures must be explicit and visually understandable.
8. Wolves win when the number of remaining sheep reaches eight or fewer.
9. Sheep win when all three wolves have no legal move (all are blocked).
10. A chained capture, when available, must be made by the same wolf. The optional second capture window is three seconds; otherwise the turn passes. The UI must explain this clearly and never cause an accidental hidden move.
11. First playable modes: single-player against easy AI and local two-player on one device. Online play is later scope.

## Rebuild sequence
A. Lock down and test the board graph and rule engine independently of graphics.
B. Build a clean landscape onboarding/setup screen and a playable 2D/3D board prototype.
C. Implement turn flow, legal moves, captures, chained capture, win/loss and restart.
D. Add easy AI and local two-player.
E. Replace prototype visuals with finished 3D meadow, animated characters, camera and effects.
F. Add settings, sound, accessibility/readability, app icon and Android packaging.
G. Test on a real Android phone. CI/build success is not gameplay acceptance.

## Acceptance gates
- No milestone is called successful solely because it compiles.
- Rule tests must cover edge cases and turn transitions.
- Real-device tests must confirm landscape layout, touch targets, all rules, no blocked-sheep selection dead-end, and readable Persian UI.
- Keep the old game and existing development branch unchanged. All new work stays on WOLF-DUSK-007-REBUILD.
