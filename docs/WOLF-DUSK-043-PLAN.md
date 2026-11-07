# WOLF-DUSK-043 — AI, Art and Mobile UX

## Base and safety
- Base branch: WOLF-DUSK-042-CINEMATIC-GRAPHICS.
- Keep `main` and `WOLF-DUSK-041-AI-TACTICAL-INTELLIGENCE` unchanged.
- Preserve the 5x5 board, 56 connections, all approved movement/capture rules, and turn flow.
- Do not merge or call this milestone complete until automated tests and an Android device check pass.

## Approved art direction
Use the user's existing ChatGPT Library reference image, **«آیکن اصلی گرگ و میش 1254.png»**, as the visual source of truth: expressive gray wolf on the left, friendly fluffy white sheep on the right, green meadow, stone path, twilight sky/moon, wooden title treatment and gold frame. Do not substitute the rejected 034 icon concept. The cover image is a style/reference source, not a ready-made transparent in-game sprite; derive clean individual character/environment assets from this design language.

## Work packages
1. **AI search quality:** profile root move ordering and alpha-beta search on identical deterministic positions; record nodes, elapsed time, completed depth and selected move. Avoid spending the entire deadline sorting moves before a meaningful search. Add tactical regression cases for forced capture, multi-sheep no-capture, defensive escape, wolf coordination, blocking and chain-capture continuation. Verify all five exposed difficulty levels map to distinct, observable strength settings.
2. **Main menu and touch UX:** increase the two main mode choices (local two-player and play against AI) substantially; use large full-width touch targets, clear Persian labels, readable contrast, safe-area margins and consistent spacing. Check portrait phone dimensions and scaling.
3. **Game art:** improve meadow, lighting, stone paths and character presentation while preserving board geometry, node positions, hit targets and gameplay camera. Use separate optimized assets for wolf and sheep; no baked title/UI text in character sprites.
4. **App icon:** update both legacy and adaptive Android icon references to the approved 1254-square artwork or a carefully prepared icon crop; verify exported APK launcher icon, not just project settings.
5. **Startup/performance:** keep splash disabled only if the menu renders immediately; profile first-frame delay and avoid a dark/blank startup.
6. **Validation and delivery:** run project import, rule tests, AI tactical/strength tests, UI scaling checks, Android export and artifact integrity checks. Then provide direct APK and request on-device confirmation.

## Acceptance criteria
- No changes to the rules or board layout.
- Main menu choices are comfortably readable and tappable on a phone.
- The launcher icon visibly changes to the approved design.
- Visual differences are present in actual game scenes, not only in documentation.
- AI strength is supported by repeatable benchmark results, not a green CI badge alone.
- A new APK is delivered only after successful validation; phone acceptance remains pending until the user installs it.
