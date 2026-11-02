# WOLF-DUSK-007 — Board Layout Specification

Status: canonical graph and starting sheep positions recovered from the legacy source archive on 2026-11-02.

## Canonical source
The original `app/src/main/assets/index.html` was extracted from `sheep_wolves_android_project.zip` by GitHub Actions run [41424748701](https://github.com/Aa12345678arash/sheep-wolves-android/actions/runs/41424748701). The extraction job completed successfully and uploaded the two source files for review.

Machine-readable authority: [CANONICAL_BOARD.json](./CANONICAL_BOARD.json). The node graph in that file must drive rendering, legal-move validation, AI and tests. Do not recreate the graph independently in scene scripts.

## Recovered board facts
- 25 nodes in a 5×5 grid, named A1–E5 (A-E top to bottom, 1-5 left to right).
- Exactly 56 undirected edges: 40 orthogonal grid edges plus the 16 explicit diagonals listed in CANONICAL_BOARD.json.
- Sheep start in five stacks of five at E1, E2, E3, E4 and E5 (25 total).
- Three wolves are placed by the player during setup on any three distinct empty nodes; the legacy source does not prescribe fixed wolf starting nodes.
- Once wolf setup is complete, sheep take the first move.
- Normal movement is one listed edge to an empty node.
- A capture is a straight-line jump over one adjacent sheep to an empty landing node. Both hops must be legal graph edges. The sheep jumped is removed.
- If another capture is available, the same wolf continues the chain. The turn passes to sheep when that wolf has no further legal capture.
- Wolves win at eight or fewer sheep. Sheep win when all three wolves have neither a normal move nor a legal capture.

## Important reconciliation
An earlier design note mentioned an optional three-second second-capture window. The recovered legacy source does not implement that timer: it requires the same wolf to continue while a legal capture exists. Preserve recovered behavior for the first faithful rebuild; any change to this rule requires explicit approval.

## Board presentation
- Show all 25 nodes and all 56 edges, with horizontal, vertical and diagonal links visually distinguishable by line style as well as restrained color.
- Show the five initial sheep stacks at E1-E5, five sheep per stack, and the three wolves on their selected empty nodes.
- Keep the node labels visible in setup/debug and unobtrusive during play.
- Show a clear legend, legal-move markers, selected-piece highlight and last-move highlight.
- Provide a top-down diagram as the geometry reference and a polished, bright, slightly isometric 3D meadow view generated from the same graph data.
- Never allow decorative scenery to hide a node, edge or legal destination.

## Automated validation gates
1. Exactly 25 unique nodes and 56 unique undirected edges.
2. No self-loops, duplicate edges or out-of-range endpoints.
3. Exactly five starting sheep stacks at E1-E5, each containing five sheep.
4. Three wolves occupy distinct empty nodes at setup completion.
5. Every rendered path corresponds to one canonical edge, and every canonical edge is rendered.
6. Every normal move uses one canonical edge and an empty destination.
7. Capture tests verify both hops are edges, the jumped piece is removed, and chained captures stay with the same wolf.
8. Sheep-first turn order and both win conditions are tested.
9. Test blocked sheep selection: an immobile sheep cannot trap selection; another movable sheep remains selectable.
10. CI compilation is not gameplay acceptance; test the finished game on an Android device in landscape orientation.
