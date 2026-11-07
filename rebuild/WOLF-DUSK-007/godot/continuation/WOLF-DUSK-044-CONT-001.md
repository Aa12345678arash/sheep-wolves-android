# WOLF-DUSK-044-CONT-001 — Continuation checkpoint

Last updated: 2026-11-07
Owner approval: user approved the supplied four-panel collage as the definitive visual reference.

## Purpose of this identifier
Use this ID in the next conversation/continuation to resume the same work without losing approved goals, constraints, repository locations, completed work, or outstanding work. This checkpoint supersedes no game rules and does not declare milestone completion.

## Repository and branch safety
- Repository: Aa12345678arash/sheep-wolves-android
- Active isolated branch: WOLF-DUSK-044-COLLAGE-ASSET-INTEGRATION
- Base branch: WOLF-DUSK-041-AI-TACTICAL-INTELLIGENCE
- Base commit: f5470981c288bd68262059fcd273b2b0c251c086
- main and 041 must remain unchanged.
- Latest branch commit at checkpoint creation: 5510aba762e4b7cec321fa2125540a99ff41db16
- Previous approved-art panel map commit: 4a3d29b5c2646b93dbb9ef9542539e859e500dc3
- Earlier extraction utility commit: 324cf1b1db409205a1c3cf4761e530e9ad753c87

## User-approved visual source and exact mapping
The user supplied and explicitly approved a single 1536×1024 four-panel collage on 2026-11-07. It is the sole visual authority. Do not revert to earlier rejected concepts or invent an alternate icon.
- Upper-left (0,0)-(512,568): launcher icon; wolf, lamb, moon, title.
- Upper-right (512,0)-(1536,568): active gameplay visual reference; meadow, actual 5×5 board layout, stone paths, waterfall, HUD, settings/pause controls.
- Lower-left (0,568)-(750,1024): wolf and sheep 3D appearance reference. This is a rendered reference, not transparent sprites or rigged models.
- Lower-right (750,568)-(1536,1024): menu environment; cottage, bridge, river, forest, moon, windmill.

## Existing assets / extraction
- A user-facing asset pack was created in the conversation runtime at /mnt/data/WOLF-DUSK-044-approved-visual-assets.zip.
- It contains four separate reference crops, an icon square padded derivative, optimized WebP references, README and SHA256 manifest.
- Four extracted reference files are also in /mnt/data/wolf-dusk-044-panels/.
- These local files have NOT yet been committed to the GitHub repository. Do not claim they are in the repository or integrated into Godot.
- Committed crop utility: rebuild/WOLF-DUSK-007/godot/tools/extract_wolf_dusk_044_panels.py
- Committed panel map: rebuild/WOLF-DUSK-007/godot/assets/art/WOLF-DUSK-044-source-panel-map.json

## Godot project inspection
- Project root: rebuild/WOLF-DUSK-007/godot/
- Active scene: scenes/main.tscn
- Active scene script: scripts/meadow.gd
- scripts/main.gd is a legacy/simple implementation; do not mistake it for the active scene.
- project.godot currently references assets/icon.svg and scenes/main.tscn.
- Android export preset explicitly references SVG launcher/adaptive icon fields.
- Existing meadow, board, HUD, and primitive character construction are procedural; they are not proof of matching the approved artwork.
- Existing start_poster.svg and icon.svg are prior SVG artwork, not the newly approved collage. Replace/derive only from approved source panels when assets are truly transferred.

## Completed work
1. Independent branch WOLF-DUSK-044-COLLAGE-ASSET-INTEGRATION created from 041.
2. Design requirements and acceptance criteria committed.
3. Exact panel coordinates documented in machine-readable JSON.
4. Reproducible crop utility committed.
5. Android workflow adjusted to include the 044 branch and to use consistent output artifact name wolf-dusk-044-preview.apk.
6. GitHub Actions run started for commit 5510aba762e4b7cec321fa2125540a99ff41db16:
   - Run ID: 42387669592
   - URL: https://github.com/Aa12345678arash/sheep-wolves-android/actions/runs/42387669592
   - At last check: in_progress; setup, checkout, Android preset check, environment setup, Godot import/validation, and startup/readability regression checks succeeded; Android APK export was still running. Recheck before claiming final result.
7. Do not infer visual changes from a build success; current 044 branch still does not contain approved binary collage crops or final 3D models.

## Required next work (in order)
A. Recheck run 42387669592; confirm final job conclusion and artifact upload. If successful, retrieve the actual APK artifact, verify it, report exact size and SHA-256. If failed, inspect logs and repair only on 044.
B. Transfer the approved collage/crops from the conversation asset pack into GitHub. The previous GitHub connector calls exposed text/blob APIs but not a convenient binary upload action. Discover a real supported binary transfer path (GitHub connector upload, repository upload action, or a user-accessible upload workflow); do not fake image data or claim upload without repository verification.
C. Commit source/crops into rebuild/WOLF-DUSK-007/godot/assets/art/ with provenance and hashes.
D. Implement approved icon and adaptive icon from upper-left panel with Android safe margins; verify APK packaged icon resources.
E. Implement menu background from lower-right panel.
F. Implement the active meadow/gameplay scene using upper-right panel as art/layout reference. Keep live 5×5 board and each piece independently selectable/movable; never use the gameplay screenshot as a flat replacement for the board.
G. Build lightweight actual 3D wolf/sheep models matching lower-left panel. Do not call a flat image crop a 3D model.
H. Preserve full-screen mobile layout, readable Persian UI, no prolonged black startup frame, and all existing game rules and AI.
I. Run Godot import validation, all existing rules/AI tests, startup/readability checks, Android export, inspect APK resources, and report commit, APK link, size, SHA-256.
J. User must install and verify launcher icon, menu, live gameplay environment and character appearance on their phone before final acceptance.

## Game invariants — must not change
- Godot 3D; 5×5 board with 56 connections.
- 25 sheep; 3 wolves; initial placement and turns unchanged.
- Wolves cannot jump over two or more sheep.
- Capture only when exactly one sheep is between wolf and an empty landing node.
- Consecutive capture stays with the same wolf and follows the agreed 3-second continuation rule.
- Wolves win at 8 sheep or fewer.
- Sheep win only when all three wolves have no legal normal move or capture.
- Five AI levels: training, easy, medium, hard, master/minimax alpha-beta. Active level must be shown.
- Preserve board graph, touch zones, orientation, control behavior, AI and all rule tests.

## Reporting rules
- Never claim binary assets uploaded until exact GitHub tree paths and blob contents are verified.
- Never claim visual integration based on references, design notes or CI alone.
- Never claim APK success without a completed successful run and retrievable artifact.
- Never claim phone verification; only user can confirm.
- At the end of each meaningful stage, update this checkpoint or create the next sequential ID (CONT-002, CONT-003, etc.), recording commits, workflow run IDs, exact results, remaining work and next actions.
