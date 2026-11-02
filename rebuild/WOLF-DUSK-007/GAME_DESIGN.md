# WOLF-DUSK-007 — Independent Rebuild

This directory is a clean, independent Godot 4 project. It must not reuse the previous game's UI, scenes, scripts, or visual layout. The legacy project remains untouched for reference only.

## Product direction
- Title: گرگ و میش؛ راز دشت سبز
- Credit, exactly: سازنده و معرفی‌کننده: آرش سلیمی
- Target: Android phones, landscape orientation.
- Visual identity: polished stylized 3D storybook meadow; readable board; expressive sheep and wolves; warm daylight, natural terrain, trees and rocks.
- UI: designed from scratch, large touch targets, clear Persian RTL labels, no oversized plain form dialog, no obscuring the board.
- Audio: optional, freely licensed/original ambient game music with mute control. Do not bundle unlicensed tracks.

## Chess-inspired side selection and board UX
- At match setup, offer a clear side choice: «گوسفندها» as the light side and «گرگ‌ها» as the dark side, analogous to choosing White or Black in online chess. Use distinctive character portraits/tokens, not only color.
- In single-player, choosing sheep means the human controls sheep and easy AI controls wolves. Choosing wolves means easy AI controls sheep and the human controls wolves. The canonical first move remains with sheep; selecting wolves never changes the rules or lets wolves move first.
- In local two-player, assign one player to sheep and the other to wolves; clearly show who controls each side. Sheep still move first.
- Camera orientation: when the player chooses a side, rotate the board camera 180 degrees so the player's own pieces appear nearest/bottom of the screen. Sheep-player view looks from behind the sheep toward wolves; wolf-player view looks from behind wolves toward sheep. Provide a top-down overview option for full board planning. Camera rotation must not alter board coordinates, legal moves, or turn order, and should use a brief smooth transition.
- Keep the board central, large, high-contrast and unobstructed. Use a light natural meadow/leaf-inspired board surface with clearly visible 5×5 nodes and all 56 connections. Do not use a dark, nearly black background or camouflage paths in grass.
- Provide subtle visual feedback inspired by online chess interfaces: selected piece halo, legal destination markers, last-move origin/destination highlight, clear active-side indicator and smooth but brief move animation.
- Use shapes and small labels as well as color so the sides remain distinguishable for color-vision differences and on small phone screens.
- Put only essential information in slim player strips around the board: side/turn, remaining sheep count, and concise game status. Secondary details (rules, settings, move history, sound) belong in collapsible or pause panels and must never cover the board during play.
- Controls must be touch-friendly and legible in landscape orientation. Avoid large modal forms, crowded text, persistent chat, clocks, ratings, or other chess-site features that do not serve this game.
- The visual inspiration is the clarity of online chess boards: legal-move dots, last-move highlights, side identity, compact player information and board-first layout. Do not copy any proprietary chess site's branding or exact artwork.

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
B. Build a clean landscape side-selection screen and a board-first playable prototype.
C. Implement turn flow, legal moves, captures, chained capture, win/loss and restart.
D. Add easy AI and local two-player.
E. Build finished 3D meadow, animated characters, camera and effects around a readable board.
F. Add settings, sound, accessibility/readability, app icon and Android packaging.
G. Test on a real Android phone. CI/build success is not gameplay acceptance.

## Acceptance gates
- No milestone is called successful solely because it compiles.
- Rule tests must cover edge cases and turn transitions, including choosing either side while preserving sheep-first play.
- Real-device tests must confirm landscape layout, touch targets, all rules, no blocked-sheep selection dead-end, readable Persian UI and unobstructed board; verify both camera orientations and top-down overview.
- Keep the old game and existing development branch unchanged. All new work stays on WOLF-DUSK-007-REBUILD.
