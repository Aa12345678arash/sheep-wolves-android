# WOLF-DUSK-3D-001 — Green Meadow 3D art implementation

Date: 2026-11-21

## Isolation
- Branch: `WOLF-DUSK-3D-001-GREEN-MEADOW`
- Base: `0de60facfce53d126e1b312dc811a2d5961edb6e`
- Do not touch `main`, stable version 044, AI branch 061, or release branches.

## Design authority
Follow the approved WOLF-DUSK-035 and WOLF-DUSK-044 visual specifications and the owner's visual references:
- expressive gray wolf and friendly fluffy white sheep;
- vivid green meadow, stone paths, wood-framed board, distant cottage/bridge/river/forest and moonlit blue-purple dusk;
- storybook / family-friendly high-quality 3D-cartoon appearance;
- preserve the approved original launcher icon concept (gray wolf left, white sheep/lambs right, stone path, green plain, twilight/moon, title «گرگ و میش»). The rejected WOLF-DUSK-034 shield emblem must not return.

## Existing implementation found
- Active scene: `scenes/main.tscn` attaches `scripts/meadow.gd`.
- The active match already creates a procedural 3D meadow, board, trees, rocks, sky/fog, low-poly animal meshes and simple idle movement.
- Current renderer is `gl_compatibility` for Android compatibility.
- Current animals are procedural primitive-based models, not the final approved art models.
- The existing 3D world is lazy-loaded after the player starts a match; retain fast startup and avoid a black/blank transition.

## Work scope
1. Create a visually coherent 3D asset layer for the active match scene, not only a poster/menu.
2. Upgrade wolf and sheep silhouettes/materials/proportions toward the approved references; retain readable faces and eyes at phone scale.
3. Improve meadow depth: layered terrain, grass clusters, distant hills, trees/rocks and the approved bridge/cottage/river elements, with conservative draw calls.
4. Improve stone/wood board framing and material response without changing any node coordinates, hit areas or legal-move indicators.
5. Add short movement, capture, idle and victory animation states; all cosmetic only.
6. Keep mobile renderer compatibility and profile CPU/GPU/memory. Use instancing/shared meshes and low-cost lighting; provide a lower-detail fallback.
7. Keep menu art loading separate from match-world loading so cold launch remains responsive.

## Acceptance
- Godot 4.4.1 import and scene parse pass.
- The active gameplay scene visibly uses the improved environment and character assets.
- Existing board/rule/AI tests pass unchanged.
- Android export succeeds; APK size and SHA-256 recorded.
- Owner installs and checks on the actual phone: startup, frame rate, touch accuracy, camera, characters and environment.
- Do not call a procedural primitive upgrade "final 3D art" unless the visual result meets the approved references and is confirmed on-device.
