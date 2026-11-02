# WOLF-DUSK-007 — Board Layout Specification (Draft)

Status: visual requirements recorded; canonical geometry is awaiting verification/approval.

## Purpose
This document prevents the 3D artwork, board diagram, AI and rules engine from using different board layouts. The rendered board must be a view of one shared graph data model.

## Confirmed facts
- 25 nodes arranged as a 5×5 layout.
- 56 valid connections in the canonical board.
- Connection types include horizontal, vertical and diagonal where defined by the original game graph.
- 25 sheep start in five groups of five, one group per designated starting node.
- Three wolves are placed on legal unoccupied nodes during setup unless a fixed arrangement is later approved.
- Sheep always take the first turn.

## Proposed visual convention — not yet approved as game data
- Label the 25 board nodes 1–25 in row-major order (top-left to bottom-right) for diagrams and debugging only.
- Keep node labels small and optional in normal gameplay; show them in the setup diagram/debug view.
- Use both line style and restrained color to distinguish horizontal, vertical and diagonal edges.
- Use distinct piece silhouettes and base markers for sheep and wolves; never rely on color alone.
- Five sheep start groups must be visually countable (five pieces per group) and anchored to their approved start nodes.

This numbering is a documentation proposal only. It must not be used to infer or invent the 56 edges or the five sheep start nodes.

## Required canonical data before rule-engine implementation is locked
A reviewed data file must explicitly define:
1. The 25 node identifiers and their board coordinates.
2. Exactly 56 undirected legal edges, each represented once.
3. The five sheep starting node identifiers (five sheep on each).
4. The three wolf setup positions or the legal placement constraints for choosing them.
5. Any special capture edges/conditions and the exact same-wolf chained-capture rule.

## Validation
- Automated test: edge count is exactly 56; no duplicate, self-loop or out-of-range edges.
- Automated test: each edge is drawn in the scene if and only if it exists in the canonical graph.
- Automated test: every selectable destination is an adjacent empty node connected by a canonical edge.
- Automated test: initial setup contains exactly 25 sheep in five groups of five and three wolves on legal empty nodes.
- Manual visual test: all routes and nodes remain distinguishable on a landscape Android screen.
- Do not mark the board complete until the original geometry/start positions are recovered or the user explicitly approves a replacement map.

## Visual acceptance
The setup screen should show a top-down board diagram plus the 3D meadow presentation. A compact legend identifies sheep, wolves, nodes, horizontal paths, vertical paths and diagonal paths. A prominent start action is visible without covering the board. During play, keep the board central and retain slim status strips only.
