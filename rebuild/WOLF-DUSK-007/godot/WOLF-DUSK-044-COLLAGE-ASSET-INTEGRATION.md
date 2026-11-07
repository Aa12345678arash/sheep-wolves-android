# WOLF-DUSK-044 — Collage Asset Integration

## Design authority
The user-approved four-panel collage (1536 × 1024 pixels, supplied 2026-11-07) is the sole visual source of truth for this milestone. Do not substitute unrelated previous concepts, alternate icons, generic stock assets, emoji placeholders, or newly invented character designs.

## Source branch
- Base branch: WOLF-DUSK-041-AI-TACTICAL-INTELLIGENCE
- Base commit: f5470981c288bd68262059fcd273b2b0c251c086
- Work branch: WOLF-DUSK-044-COLLAGE-ASSET-INTEGRATION
- Keep main and branch 041 unchanged.

## Approved panel map
Coordinates are pixel rectangles in the original 1536 × 1024 image, with right/bottom edges exclusive:
| Panel | Rectangle (x, y, width, height) | Intended use |
|---|---:|---|
| Upper-left | (0, 0, 512, 568) | Launcher icon source: wolf, lamb, moon, title |
| Upper-right | (512, 0, 1024, 568) | Active gameplay visual target: 5×5 board, meadow, stone paths, waterfall, HUD |
| Lower-left | (0, 568, 750, 456) | Character appearance reference: wolf and sheep |
| Lower-right | (750, 568, 786, 456) | Menu environment reference: cottage, bridge, river, forest, moon, windmill |

The machine-readable map is `assets/art/WOLF-DUSK-044-source-panel-map.json`. The reproducible crop utility is `tools/extract_wolf_dusk_044_panels.py`. It validates the source dimensions and writes four separate, aspect-ratio-preserving JPEG reference panels. A local extraction run against the supplied image produced:
- icon-reference.jpg — 512 × 568
- gameplay-reference.jpg — 1024 × 568
- characters-reference.jpg — 750 × 456
- menu-environment-reference.jpg — 786 × 456

Keep the original aspect ratios during extraction. Do not stretch the panels. Trim rounded panel borders only when preparing final derived assets, and preserve a clean, readable silhouette and safe margins for launcher icon masks. The lower-left panel is a character reference; it is not a transparent cutout or a rigged 3D model.

## Required extraction and integration
1. Launcher icon: crop the upper-left panel. Produce square launcher and adaptive icon assets with safe margins; preserve the reference design and legibility.
2. Characters: use the lower-left panel as the exact visual reference for the wolf and sheep. Extract separate transparent sprites only if segmentation yields clean edges. For actual 3D characters, build or source lightweight 3D models that match the reference; never claim a flat crop is a 3D model.
3. Main gameplay environment: use the upper-right panel as the visual source for the green meadow, 5×5 board, stone paths, and waterfall. Integrate these into the actual active gameplay scene, not just a menu or poster. Maintain board node positions, hit targets, legal move highlighting, and rule logic.
4. Menu environment: use the lower-right panel as the source for the cottage, bridge, river, forest, moon, and windmill. Apply it to the menu background.
5. The upper-right panel is a layout and appearance reference, not a replacement for the live board. Pieces must remain independently selectable and movable.

## Current project inspection
- The Godot project is under `rebuild/WOLF-DUSK-007/godot/`.
- `project.godot` points at `res://assets/icon.svg` and `res://scenes/main.tscn`.
- `scenes/main.tscn` attaches `scripts/meadow.gd`; this is the active scene implementation.
- Android export preset explicitly points launcher and adaptive icon fields at SVG files in `assets/`.
- `scripts/meadow.gd` contains the procedural active meadow, board, HUD, and character construction and is the primary integration area to verify against the approved art.
- `scripts/main.gd` is a separate legacy/simple board implementation; do not mistake it for the active scene.
- Existing procedural environment and primitive animal meshes are not yet evidence of compliance with this approved artwork.

## Critical acceptance criteria
- The exact source image and derived panel assets must be present in the project before claiming visual integration. The source image and four binary crop files have not yet been committed to the Git branch; the panel map and reproducible extraction utility are committed. Do not describe the image assets as integrated until they are actually in the project.
- Keep source artwork and derived assets in a clearly named project assets directory; document provenance and crop/alpha processing.
- The in-game wolf/sheep models must visually match the lower-left panel, not merely resemble generic animals.
- The green meadow environment and board must render during an active match. A menu-only implementation fails.
- Launcher icon must be configured explicitly for Android launcher/adaptive icon export. Do not rely on Godot fallback icons.
- Preserve all existing game rules, AI behavior, board graph, touch zones, orientation, and controls. No gameplay rule changes in this graphics milestone.
- Optimize texture dimensions/compression for Android. Avoid long black/dark startup frames; load essential menu assets efficiently and provide a lightweight loading presentation if needed.
- Run Godot import/project validation, existing rule and AI tests, UI readability checks, and Android export.
- Inspect the resulting APK contents for the expected launcher icon and packaged textures. Report APK size and SHA-256.
- Do not mark complete on code or CI success alone. Final acceptance requires the user to install and confirm the APK on their phone, including launcher icon, menu scene, active gameplay environment, and character appearance.

## Delivery report
Provide commit SHA, changed asset paths, source-to-output mapping, validation results, APK direct download link, file size, SHA-256, and any known limitations. Never claim APK built or phone-verified unless the corresponding evidence exists.
