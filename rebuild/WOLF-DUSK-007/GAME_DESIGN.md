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


## New visual board-layout requirement (added 2026-11-02)
The user explicitly requested a complete visual plan of the playable board, not decorative meadow art. The board view and its design reference must make the following immediately understandable:
- All 25 node locations are individually visible and consistently addressable.
- The complete set of 56 legal connections is drawn and distinguishable, including horizontal, vertical and diagonal links wherever those links exist in the canonical graph. A line must never imply a legal move unless that edge exists in the rule engine.
- Use a clear legend and distinct line treatments for horizontal, vertical and diagonal connections (for example, line pattern/weight plus restrained hues); do not rely on color alone. Keep the board bright, uncluttered and readable on a phone.
- Show the initial sheep formation as five visually separate groups of five sheep, each group anchored to one of the five designated starting nodes. Use a group marker or subtle base ring so the five groups are easy to count.
- Show the three wolves as distinct, recognizable pieces in the opposing setup area/positions. The setup view must make it clear that the wolves are placed on legal unoccupied nodes and must not overlap sheep or obscure connections.
- Include a compact legend for sheep, wolves, node, horizontal path, vertical path and diagonal path, plus a clear «شروع بازی» affordance. In-match view should retain the same graph and piece identity while removing setup-only clutter.
- Provide a clean top-down board diagram in the design reference in addition to the slightly isometric 3D in-game presentation. The top-down diagram is the authority for checking node and edge connectivity.
- The final 3D scene must be generated from the same canonical node/edge data used by move validation; visual paths and legal moves must never drift apart.

### Placement and graph integrity — unresolved data, do not guess
The current specification confirms 5×5 nodes, 56 connections, five sheep start nodes with five sheep per node, and three wolves. It does NOT yet contain the exact list of the five sheep start-node IDs, the complete 56-edge list, or fixed wolf start-node IDs. Therefore:
- Do not invent or silently hard-code exact starting node positions or a made-up 56-edge pattern.
- Treat the three wolf positions as setup-selected legal empty nodes unless the user supplies/approves a fixed arrangement.
- Before implementation is accepted, recover the original board diagram/rules or obtain the user's approval of a numbered 1–25 node map and explicit edge/start-node list. The same approved data must drive the diagram, AI, move validation and tests.
- Any concept illustration made before this data is confirmed must be labelled as a layout concept, not a verified rules-accurate board.

### Board-first visual hierarchy
1. Board and pieces occupy the majority of the landscape screen.
2. Five sheep groups and three wolves are visually countable at a glance.
3. Every legal route is visible at phone scale; path intersections and nodes remain distinct.
4. Side-to-move, remaining sheep and concise status stay in slim peripheral strips.
5. Rules, settings, move history and audio controls stay in a pause/collapsible panel.


## Recovered legacy rule authority (2026-11-02)

The original Android archive has now been extracted and inspected. The exact graph and initial sheep stacks are recorded in `CANONICAL_BOARD.json`; `BOARD_LAYOUT_SPEC.md` is updated to match it.

- Node labels A1-E5; exactly 56 edges (40 horizontal/vertical grid edges and 16 specified diagonals).
- Initial sheep stacks are E1, E2, E3, E4 and E5, five sheep at each.
- Wolves are placed on any three distinct empty nodes during setup; no fixed wolf start positions exist in the legacy source.
- Sheep move first after setup.
- Capture is a straight-line two-edge jump over one adjacent sheep into an empty node; the jumped sheep is removed.
- Same-wolf chained capture is mandatory while another legal capture exists. The old source does not implement the optional three-second window described in an earlier planning note. The faithful rebuild follows the recovered source unless a rule change is explicitly approved.
- The canonical JSON is the single source of truth for graph rendering, move validation, AI and tests.
