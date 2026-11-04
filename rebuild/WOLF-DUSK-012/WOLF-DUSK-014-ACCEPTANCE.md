# WOLF-DUSK-014 — Board Placement Zones, Piece Scale & Touch Accuracy

Branch: `WOLF-DUSK-014-BOARD-PIECES`
Base commit: `ef0ec6307d7fdd2980511a9142423353c1e7fc5e`

## Approved design requirements
- Make every node's placement area larger and easier to see.
- Enlarge sheep and wolf characters proportionally so their silhouettes are more readable and visually expressive.
- Keep every piece silhouette inside its own placement boundary, including the five-sheep stack.
- Preserve the canonical board graph, legal moves, capture rules, turn ownership, win conditions, camera framing and mobile performance.
- Improve touch selection without allowing neighboring node targets to overlap or become ambiguous.

## Implemented source changes in this branch
- Node physics pick radius: 0.92 -> 0.98 world units. With 2.2-unit node spacing, adjacent spherical hit areas retain a 0.24-unit gap.
- Visible node pads: 0.19 / 0.34 -> 0.52 / 0.62 world-unit radii, depending on selection/legal status.
- Added an outer placement boundary ring (0.87–0.96 world-unit radii) to show the full piece footprint.
- Sheep stack spacing: 0.34 -> 0.36; sheep scale: 0.92 -> 1.00, selected sheep 1.08.
- Wolf scale: 1.24 -> 1.36.
- Screen-space fallback hit radius is capped at 42% of the nearest projected node-center spacing (and never exceeds 54 px), preventing adjacent fallback targets from overlapping.

## Acceptance tests required
1. Godot project imports and starts headlessly without parse/runtime errors.
2. Existing board and rules tests pass unchanged.
3. In landscape on at least two phone/display sizes, all 25 node centers and all 56 legal links remain visible.
4. Every sheep stack and each wolf fit visually inside its own outer placement ring; no neighboring ring or character overlaps.
5. Tap tests across the board select the intended node; taps halfway between adjacent nodes do not select either node.
6. Selection, legal destinations, ordinary moves, captures and same-wolf chain captures remain correct.
7. Camera orbit and pinch zoom do not hide the playable area or make node selection ambiguous.
8. Performance remains smooth enough on the target Android phone; compare with the prior build and watch for frame drops.
9. Android debug export creates a non-empty APK artifact.
10. The user installs and tests on the target phone before mobile acceptance is marked complete.

## Status
Source changes are committed to the isolated branch. Automated validation and APK export are pending. No APK is declared install-ready and no on-device acceptance is claimed.
