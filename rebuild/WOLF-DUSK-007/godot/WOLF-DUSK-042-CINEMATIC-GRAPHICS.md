# WOLF-DUSK-042 — Cinematic Graphics Production

Status: isolated graphics branch created from WOLF-DUSK-041-AI-TACTICAL-INTELLIGENCE. This document records the implementation and acceptance plan; it does not claim that the graphics upgrade or device acceptance is complete.

## Source and isolation
- Base branch: `WOLF-DUSK-041-AI-TACTICAL-INTELLIGENCE`
- Base commit: `f5470981c288bd68262059fcd273b2b0c251c086`
- Working branch: `WOLF-DUSK-042-CINEMATIC-GRAPHICS`
- Do not modify `main`, release branches, or the AI-041 branch.
- Keep the existing canonical board, game-state/rules code, five AI difficulty levels, tactical tests, and Android export identity unchanged unless a separate defect is found and documented.

## Approved visual identity
Use the owner-approved master reference `آیکن اولیه گرگ و میش.jpg` and the previously supplied layout references `22971.png` and `22973.jpg`:
- expressive gray wolf and friendly fluffy white sheep;
- winding stone path through a vivid green meadow;
- moonlit blue/purple twilight sky with warm golden highlights;
- wooden Persian/English title plaque;
- warm, family-friendly, high-quality 3D-cartoon storybook style.
- Story title: «گرگ و میش»; subtitle: «راز دشت سبز».
- Exact credit: «سازنده و معرفی‌کننده: آرش سلیمی».
- Do not use the rejected shield-shaped wolf/sheep/gold-frame emblem as the launcher icon, title art, or menu art.

## Production sequence

### 042-A — Visual baseline and startup/menu
- Replace any blank/dark first-launch interval with the cinematic poster/splash and keep it visible until the first fully drawn menu frame.
- Keep optional music synthesis and decorative scene construction off the critical first-frame path.
- Build a full-screen portrait-first story menu with readable Persian title, subtitle and large touch controls:
  «شروع ماجرا»، «انتخاب نوع بازی»، «درجه سختی هوش مصنوعی»، «آموزش و قوانین»، «تنظیمات صدا».
- Support short/tall Android screens and safe areas; no tiny controls or clipped text.

### 042-B — Meadow and board environment
- Elevate the current procedural meadow into a coherent storybook environment: layered hills, grass, flowers, trees, rocks, stone approach, dusk sky and warm/cool balanced lighting.
- Keep all decoration outside the playable board footprint.
- Preserve the complete 5×5 board and all 56 connections, the existing camera framing, all legal destinations and touch targets.
- Use shared materials and MultiMesh/low-cost geometry where appropriate; avoid expensive real-time shadows and unnecessary per-frame work.

### 042-C — Character art and animation
- Replace temporary primitive-looking pieces with cohesive stylized 3D-cartoon wolf and sheep silhouettes, with clear visual distinction and readable scale.
- Add restrained idle breathing/blinking/head-look, natural movement, capture reaction and clear turn/selection feedback.
- Sheep stacks must remain countable and must never obscure adjacent legal nodes.
- Keep animations short, skippable/non-blocking and independent of game-rule state.

### 042-D — Match HUD and feedback
- Use compact wooden/stone information plaques inspired by the owner references.
- Make stage, active side, remaining sheep, captured count, selected piece, legal destinations and chain-capture timer obvious.
- Preserve high contrast and large Persian type; do not cover the board or legal paths.
- Add distinct victory/defeat presentation without obscuring the reason or the actual game result.

### 042-E — Audio, polish and mobile optimization
- Retain original/procedural audio unless replaced by original or properly licensed assets.
- Provide clear music/effects controls and persist preferences.
- Measure startup time, frame pacing and memory on representative Android hardware.
- Keep low-cost fallback settings; no visual feature may make touch response or AI turn execution stall.

## Non-negotiable gameplay preservation
This is a presentation-only redesign:
- 25 sheep; five on each of the five starting pads; three wolves placed on empty nodes.
- Preserve the canonical 5×5 / 56-connection graph and all turn/movement logic.
- A wolf may jump only when exactly one sheep occupies the middle node and the landing node is empty. Two or more sheep in the middle forbid the jump.
- Optional second capture remains limited to the same wolf and the existing three-second decision window.
- Wolves win at the existing eight-sheep threshold; sheep win only when all three wolves are blocked.
- Five AI levels remain genuinely distinct and legal; preserve AI-041 tactical search budget and regression tests.

## Validation and acceptance gates
1. Every commit runs Godot import/headless startup plus board, rules, player-control, UI-readability, board-pad, AI and AI-tactics tests.
2. Android debug APK export must succeed and the artifact must be named for WOLF-DUSK-042, never a stale version number.
3. Review screenshots/video on short and tall portrait layouts; check that the entire board and all destinations remain visible.
4. Measure cold-launch time-to-first-visible-frame and check for the former dark startup interval.
5. Install on the owner's Android phone. Only owner-confirmed real-device behavior can pass the final gate.
6. Do not call any stage complete merely because code was committed or CI passed. Keep a written list of unverified items and observed defects.

## Current baseline observations
- The Godot project already contains a procedural twilight meadow, wooden board frame, grass/flower MultiMeshes, distant ridges, stone approach, a portrait HUD, and procedural music.
- The 3D pieces are still described in the project README as temporary geometric models, not final art.
- Existing startup work intentionally draws the menu before building the meadow and synthesizing music; retain and improve this first-frame strategy.

## CI correction log — 2026-11-07
- Run 10 exposed a malformed `elif` line in `scripts/meadow.gd` at the winner HUD branch; the status assignment was placed on the same line after a tab and caused a GDScript parse error. The branch and assignment have been separated.
- The visual regression test now explicitly types its duplicated sheep/wolf state snapshots as `Variant` to avoid inference errors when the meadow script is unavailable during parsing.
- Run 10 did not export an APK: validation failed before the Android export step. The next run must pass the complete validation suite and produce the named artifact before this branch can be considered CI-ready.
