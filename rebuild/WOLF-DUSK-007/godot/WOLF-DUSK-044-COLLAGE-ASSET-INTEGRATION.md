# WOLF-DUSK-044 — Collage Asset Integration

## Design authority
The user's approved four-panel collage is the sole visual source of truth for this milestone. Do not substitute unrelated previous concepts, alternate icons, generic stock assets, emoji placeholders, or newly invented character designs.

## Source branch
- Base branch: WOLF-DUSK-041-AI-TACTICAL-INTELLIGENCE
- Base commit: f5470981c288bd68262059fcd273b2b0c251c086
- Work branch: WOLF-DUSK-044-COLLAGE-ASSET-INTEGRATION
- Keep main and branch 041 unchanged.

## Required extraction and integration
1. Launcher icon: crop the collage's upper-left panel (wolf, sheep, moon, game title). Produce square launcher and adaptive icon assets with safe margins; preserve the reference design and legibility.
2. Characters: extract the wolf and two sheep from the lower-left panel as separate in-game assets. Preserve faces, colors, proportions, and 3D visual style. Use transparent cutouts where feasible; do not redraw into a different style.
3. Main gameplay environment: use the upper-right panel as the visual source for the green meadow, 5x5 board, stone paths, and waterfall. Integrate this into the actual gameplay scene, not just a menu or poster. Maintain board node positions, hit targets, legal move highlighting, and rule logic.
4. Menu environment: use the lower-right panel as the source for the cottage, bridge, river, forest, and moon. Apply as the menu background.

## Critical acceptance criteria
- The actual four source panels must be available as source image input before extraction. Do not pretend the collage is present if it is not attached to the branch or available as a file.
- Keep source artwork and derived assets in a clearly named project assets directory; document provenance and crop/alpha processing.
- The in-game wolf/sheep sprites or models must visually match the lower-left panel, not merely resemble generic animals.
- The green meadow environment and board must render during an active match. A menu-only implementation fails.
- Launcher icon must be configured explicitly for Android launcher/adaptive icon export. Do not rely on Godot fallback icons.
- Preserve all existing game rules, AI behavior, board graph, touch zones, orientation, and controls. No gameplay rule changes in this graphics milestone.
- Optimize texture dimensions/compression for Android. Avoid long black/dark startup frames; load essential menu assets efficiently and provide a lightweight loading presentation if needed.
- Run Godot import/project validation, existing rule and AI tests, UI readability checks, and Android export.
- Inspect the resulting APK contents for the expected launcher icon and packaged textures. Report APK size and SHA-256.
- Do not mark complete on code or CI success alone. Final acceptance requires the user to install and confirm the APK on their phone, including launcher icon, menu scene, active gameplay environment, and character appearance.

## Delivery report
Provide commit SHA, changed asset paths, source-to-output mapping, validation results, APK direct download link, file size, SHA-256, and any known limitations. Never claim APK built or phone-verified unless the corresponding evidence exists.
