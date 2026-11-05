# WOLF-DUSK-035 — Cinematic Storybook Redesign

Status: implementation scope recorded; only the startup splash configuration has been changed so far. This document is a specification, not a claim that the full redesign or five-level AI is already implemented.

## Rejected direction
The shield-shaped wolf/sheep/gold-frame icon introduced in WOLF-DUSK-034 is explicitly rejected by the owner. Do not reuse it as the launcher icon, title art, or menu art.

## Approved visual master
Use the owner's Library image `آیکن اولیه گرگ و میش.jpg` as the master reference:
- expressive gray wolf, friendly fluffy sheep, stone path through a vivid green meadow;
- moonlit blue/purple sky with warm highlights;
- wooden Persian/English title sign and playful adventure-cover composition;
- preserve the warm, family-friendly 3D-cartoon character style.
Do not redraw this as a shield badge. Prepare launcher/adaptive crops from this master image, preserving safe margins and readable silhouettes.

## Startup and loading
- Show the cinematic meadow poster during engine startup instead of a blank/dark splash.
- Avoid a blank screen between splash and main menu; keep the splash visible until the first menu frame is ready.
- Preload essential menu art/audio before switching; do not block startup on optional effects.
- Verify cold launch on a real Android device and record time-to-first-visible-frame. Do not claim the delay is eliminated until measured.

## Main menu
- Full-screen, portrait-first story poster with the wolf, flock, winding stone path, distant meadow and dusk sky.
- Large, high-contrast Persian controls spanning the usable phone width: «شروع ماجرا»، «انتخاب نوع بازی»، «درجه سختی هوش مصنوعی»، «آموزش و قوانین»، «تنظیمات صدا».
- Buttons must be comfortably touchable, not tiny; support short and tall phone aspect ratios and safe areas.
- Keep the title and story subtitle readable over a subtle dark translucent backing; keep attribution exactly: «سازنده و معرفی‌کننده: آرش سلیمی».

## Match-mode selection
- Replace tiny choices with large full-width cards/buttons and a short explanatory line.
- Clearly distinguish «بازی با هوش مصنوعی»، «دو نفره روی یک گوشی»، and any other mode only if it is genuinely playable.
- Show selected mode and provide an obvious back action.

## Gameplay presentation
- Retain the complete 5×5 / 56-connection board and camera framing; do not crop legal destinations.
- Add decorative meadow/wood/stone framing around the playfield without obscuring nodes, paths, hit targets, or legal-move indicators.
- Make turn, side-to-move, remaining sheep, wolf count, selected piece, legal destinations, capture availability, and win condition obvious with large Persian labels and iconography.
- Animate movement and capture with short, clear feedback; preserve responsiveness on mid-range Android hardware.
- Maintain all canonical movement/capture rules, including: a wolf may jump only when exactly one sheep occupies the middle node and the landing node is empty. Two or more sheep in the middle forbid the jump.

## AI: five distinct playable levels
Implement and test five actual levels, not five labels:
1. «آموزشی» — safe, explainable moves and hints; forgiving opponent.
2. «آسان» — basic legal strategy with occasional non-optimal choices.
3. «متوسط» — evaluates captures, threats, mobility and sheep safety.
4. «سخت» — multi-ply lookahead, traps, blocking and endgame awareness.
5. «استاد» — deeper search, move ordering, pruning/transposition where feasible, and deterministic time budget for mobile.
Every level must obey the same rules. Measure response time on-device and never freeze the UI. Add AI scenario tests and verify that difficulty changes strength rather than only randomness.

## Sound and music
- Add an original or properly licensed, loopable cinematic adventure score, with calm menu and tense match layers.
- Add distinct, natural sheep bleats, wolf growls/howls, movement and capture cues.
- Provide separate music/effects volume sliders, mute, and persistence. Start audio only after an explicit user interaction where Android audio policy requires it.
- Do not ship placeholder beeps or unlicensed commercial tracks. Validate that audio assets are bundled and audible on-device.

## Delivery and acceptance
- Keep this work isolated to `WOLF-DUSK-035-CINEMATIC-REDESIGN`; do not modify `main`, v0.5.x, or earlier release branches.
- Build and run automated Godot validation and gameplay-rule tests.
- Produce an APK only after the implementation is actually present and CI succeeds.
- The owner must install the APK and confirm launch, icon, menu, mode selection, gameplay readability, sound, and performance. A successful CI build is not proof of real-device acceptance.
