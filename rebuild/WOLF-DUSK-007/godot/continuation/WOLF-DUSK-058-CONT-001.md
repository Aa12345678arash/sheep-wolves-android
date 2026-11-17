# WOLF-DUSK-058-CONT-001 — Edge cases and search coverage

Date: 2026-11-17

## Branch and safety boundary

- Active diagnostic branch: `WOLF-DUSK-058-EDGE-CASE-AND-SEARCH-COVERAGE-AUDIT`
- Parent/base commit: `9afca2f1c5f36c51de24782e3a5b43523db78bc8` from `WOLF-DUSK-057-ROOT-CYCLE-AND-SIEGE-DIAGNOSTICS`
- Current code commit when this checkpoint was written: `e6f567016764fff5522c5c4e85b02da99475c245`
- The branch is 3 commits ahead and 0 behind its WOLF-DUSK-057 base.
- `main` remains `14de7a5bc21a77031f42409636c618a59070ecee`.
- No AI gameplay source, rules, evaluation weights, search depth, Android export, APK, merge, or stable release has been changed.

## Work added

- `tests/validate_ai_edge_cases.gd`: single-sheep capture, occupied landing, chain ownership and decline, exact eight-sheep win threshold, all-wolves-blocked win, siege semantics, and turn-sensitive position identity.
- `tests/validate_ai_search_coverage.gd`: checks legal opening/moves at all five levels and reports configured target depth separately from actual root-move coverage, elapsed time, node count, and stop reason.
- `.github/workflows/wolf-dusk-058-edge-case-audit.yml`: isolated Godot 4.4.1 headless workflow. No APK build or artifact is expected from this diagnostic workflow.

## WOLF-DUSK-057 evidence baseline

Source: GitHub Actions run `43847879046`, job `133232590782`, commit `9afca2f1c5f36c51de24782e3a5b43523db78bc8`.

- 100 self-play matches: 25 pairings of five levels × four fixed seeds.
- Result: 2 wolf wins, 0 sheep wins, 2 threefold-repetition draws, 96 artificial 72-ply-limit draws.
- 369 total captures across 7,167 plies.
- Search levels 2/3/4 requested depths 4/6/8 and budgets 70/150/240 ms.
- Every sampled search call at levels 2–4 stopped on its time limit.
- Average root candidate coverage was low: roughly 8–10% of legal root moves searched. The recorded `depth` field is configured target depth, not proof that all branches reached that depth.
- The 72-ply cap is a test harness limit, not an official game win/draw rule.
- The self-play fixture counts repetition draws, but the live GameState does not currently end a game by threefold repetition.

## Current workflow

- Run: `44075030003`, workflow run number 1.
- Head commit: `e6f567016764fff5522c5c4e85b02da99475c245`.
- At checkpoint creation the run was `in_progress`; do not mark it successful until all steps finish.
- No artifacts are expected.

## Next steps

1. Inspect the full result and logs for run `44075030003`.
2. Fix only diagnostic tests/workflow on this branch if a test fails due to a fixture or script error.
3. Review the search-coverage report and quantify the root-candidate completion problem.
4. Ask Claude for an independent read-only audit of `ai_opponent.gd`, `game_state.gd`, and the 057 self-play/cycle tests, using the findings and exact metrics above.
5. Do not change AI evaluation, game rules, search depth, create an APK, merge, or touch `main`/stable builds until the evidence and independent review are reconciled.
6. Device installation and real-phone testing remain user-only; never claim them as completed.
