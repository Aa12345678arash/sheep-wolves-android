# WOLF-DUSK-059-CONT-001 — Timeout propagation and iterative deepening

Date: 2026-11-17

## Branch and safety boundary

- Active branch: `WOLF-DUSK-059-TIMEOUT-PROPAGATION-AND-ITERATIVE-DEEPENING`
- Base: `WOLF-DUSK-058-EDGE-CASE-AND-SEARCH-COVERAGE-AUDIT`
- Exact base commit: `fe6674a9112b507f901971c4f2523b48113267ce`
- The base includes the successful WOLF-DUSK-058 run #3, including canonical graph topology, board/rules, edge cases, and five-level search coverage.
- `main` and stable branches/builds are outside this work and must remain unchanged.
- This is a diagnostic/search-control branch. No game rule, evaluation weight, difficulty mapping, Android export, APK, merge, or stable release is authorized by this checkpoint.

## Changes in WOLF-DUSK-059

1. `scripts/ai_opponent.gd`
   - Search nodes now return a structured result with `score` and `completed`.
   - A time/node-limited subtree explicitly propagates `completed=false`; its partial score is not used by parent minimax comparisons.
   - Root search now uses iterative deepening at depths 2, 4, ... up to the configured target.
   - A root choice is committed only after every legal root candidate completes that iteration.
   - If the first iteration is interrupted, the AI retains a legal static-order fallback and reports completed depth 0.
   - Diagnostics distinguish target depth, attempted depth, completed depth, attempted root moves, and fully searched root moves.
   - A deterministic context-injection helper supports headless timeout tests.

2. `tests/validate_ai_timeout_contract.gd`
   - Forces a deterministic node-budget interruption below the root.
   - Verifies incomplete status propagates and search-path state is cleaned.
   - Verifies complete shallow search still returns a complete score.
   - Verifies an interrupted first root pass returns a legal fallback but does not count partial root results as completed.
   - Verifies a sufficiently budgeted depth-2 pass covers every legal root candidate.

3. `tests/validate_ai_search_coverage.gd`
   - Reports target depth separately from completed depth.
   - Distinguishes fully completed root coverage from attempted root coverage.
   - Accepts zero completed root candidates when the first iteration is interrupted, without misreporting them as completed.

4. `.github/workflows/wolf-dusk-059-timeout-propagation.yml`
   - Runs Godot 4.4.1 headless.
   - Re-runs topology, board/rules, edge-case, timeout-contract, and five-level coverage checks.
   - Diagnostic-only; no APK or artifact expected.

## Required verification before calling this stage successful

- Inspect the new GitHub Actions run and its logs, especially the timeout contract and all-five-level search report.
- Confirm no script parse/runtime errors.
- Confirm only complete iterations are committed and the fallback remains legal.
- Compare completed-depth and root-coverage metrics against WOLF-DUSK-058.
- If tests reveal a defect, fix it only on this branch and rerun.
- Do not alter official rules, evaluation weights, or configured difficulty depths in this stage.
- Device UI responsiveness and actual APK behavior remain unverified until the user tests a build on their phone; no APK is built by this workflow.

## Baseline evidence from WOLF-DUSK-058

- Branch head: `fe6674a9112b507f901971c4f2523b48113267ce`
- Actions run #3: `44077139857`, job `134017999003`, conclusion `success`.
- Topology test output confirmed 40 orthogonal edges, 16 diagonal edges, expected degree distribution, and 40 straight jump triples.
- Board, unchanged rules, diagnostic edge cases, and five-level legal move/coverage tests all passed.
- Search still hit its time budgets at levels 2–4; WOLF-DUSK-059 must demonstrate the effect of incomplete-result propagation and completed-depth reporting.

## Current WOLF-DUSK-059 code commits

- AI search timeout propagation / iterative deepening: `e29eb5323c1ff695efe86332f40caebdfa6d252d`
- Deterministic timeout contract test: `acb359fd934cfb6dd6ed65de1eff55e9d57ec0a6`
- Completed-depth coverage report: `3be03f702db10f3b15565e68b1233b86d4997c8d`
- Isolated diagnostic workflow: `0ecd67d72c3d6f5f45af8339253e1b4b075a2655`

The current state is implementation submitted to the branch; Actions verification is still pending. Do not mark WOLF-DUSK-059 complete until the workflow passes and its logs are reviewed.
