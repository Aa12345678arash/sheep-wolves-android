# WOLF-DUSK-021 — Board node platform expansion

## Base and scope
- Parent: WOLF-DUSK-AI-019-TOUCH-TARGETS
- Branch: WOLF-DUSK-021-BOARD-NODE-EXPANSION
- Preserve the AI-018/019 gameplay, camera, turn flow, touch targets, board graph and piece geometry.
- This is a board-footprint and mobile-readability stage, not a character or meadow redesign.

## Changes in this branch
- Add a visible physical platform under each of the 25 board nodes.
- Set platform radius to 0.92 world units and thickness to 0.14 world units, keeping the 2.2-unit node-center spacing and leaving a gap between neighboring platforms.
- Spread the five sheep slots to a 3-by-2 arrangement using 0.40-unit spacing; keep every slot within the platform radius.
- Carry forward only the HUD and responsive setup-menu changes from UI-020.
- Preserve AI-019 touch collision radius, fallback tap radius, marker radii, fixed AI camera and AI sheep-turn handoff.
- Correct the APK workflow so the exported APK path and uploaded artifact path are identical.

## Automated acceptance
- Existing board, rules, AI and player-control tests must pass.
- UI readability test must pass.
- New board-pad test must verify 25 physical platforms and five sheep slots contained by a start platform.
- Android debug APK export and artifact upload must both pass.

## Device acceptance required
This stage is not complete until the user installs the APK and confirms:
1. The five sheep are visibly accommodated on each start platform without leaving its edges.
2. Wolf pieces fit clearly on a node platform.
3. The enlarged platforms do not obscure or confuse the connecting paths.
4. All 25 nodes remain easy to select without neighboring false selections.
5. HUD and settings are readable and usable on the phone.
6. AI camera, AI turn handoff, second-capture timeout/decline, and local two-player gameplay remain correct.
7. No new lag, freeze, black screen or camera regression is observed.
