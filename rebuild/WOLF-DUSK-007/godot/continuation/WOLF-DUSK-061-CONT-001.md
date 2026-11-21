# WOLF-DUSK-061-ELITE-AI-SEARCH — continuation record

Date: 2026-11-21

## Safety and baseline
- Isolated branch: `WOLF-DUSK-061-ELITE-AI-SEARCH`
- Base commit: `0de60facfce53d126e1b312dc811a2d5961edb6e` from `WOLF-DUSK-060-SHEEP-L2-SEARCH-OPTIMIZATION`.
- `main`, stable version 044, and all release branches remain untouched.
- Canonical 5x5 / 56-edge graph, starting layout, movement/capture/chain rules, and win thresholds are immutable in this stage.

## First concrete fix
- `scripts/chain_capture_timer.gd` now uses a 1-microsecond floating-point tolerance at the exact 3-second expiry boundary.
- Commit: `3bd923f2a0f32b3c737a93998bf740c96037dd3b`.
- Rationale: subtracting 0.001 from a floating-point 0.001 remainder can leave a tiny positive residual, causing the exact-boundary assertion to fail. Expiry clamps the remaining time to zero within the epsilon.
- This is a numerical boundary correction, not a gameplay rule change.

## Regression workflow
- `.github/workflows/wolf-dusk-061-elite-ai.yml`
- Commit: `97979fc523999f2147bd54ef72591e58995cf33b`.
- Runs Godot 4.4.1 headless import, topology/rules/edge-case tests, all available AI/tactical/search-contract tests, exact chain timer boundary test, and seeded self-play.
- The workflow result must be inspected before claiming the fix or AI improvements are verified.

## Superior-AI acceptance
Five distinct levels must be behaviorally different:
1. آموزشی: explainable safe moves and hints.
2. آسان: legal basic strategy with occasional deliberate suboptimality.
3. متوسط: captures, threats, mobility and flock safety.
4. سخت: multi-ply lookahead, coordinated hunting, traps and endgame.
5. استاد: deeper completed-iteration search, move ordering, pruning/transposition where feasible, cycle avoidance and mobile-safe time/node budgets.

A move counts as searched only if the full required subtree/iteration completed. Record per side and level: calls, mean/max latency, nodes, target/completed depth, root candidates and fully searched roots, stop reasons, repeated-position decisions, and legal fallback use.

## Competitive acceptance
- Seeded self-play must cover all 25 wolf-level × sheep-level matchups with multiple seeds and controlled opening layouts.
- Report wins/losses/draws, threefold repetition, move-cap draws, captures, sheep remaining, match length, siege progress and blocked wolves.
- Compare to the WOLF-DUSK-056/057 baselines. CI green or legal moves alone do not establish strength.
- No claim of "superior" until stronger levels show reproducible, meaningful competitive separation and improved match outcomes without rule violations or unacceptable phone latency.

## Current known blocker
WOLF-DUSK-060 Actions run `44105481759` failed during exact chain-timer boundary validation; the 70ms sheep L2 optimization step was skipped. This branch adds the epsilon fix and a regression workflow. The result is pending until the new Actions run and logs are reviewed.
