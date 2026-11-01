# Multiplayer and player identity design — WOLF-DUSK-004

## Match types
1. Local two-player: two people share one device. Players alternate turns; no AI actions are scheduled.
2. Private online room: one player creates a room and shares a short join code. The other enters the code.
3. Random online matchmaking: pair two waiting players with compatible protocol/game versions.
4. Vs AI: retain the three existing difficulty levels as a separate match type.

## Player identity and side selection
- Each player chooses a display name (validated, length-limited, trimmed; never use it as an account credential).
- Each player can choose Wolves or Sheep in private rooms; if both request the same side, the room host resolves the conflict or the game offers a random assignment.
- Random matchmaking assigns opposite sides fairly, with optional side preference.
- The match header shows both display names and their side, plus whose turn it is.

## Board orientation
- Keep the board graph, node IDs, piece positions, legal moves and rules unchanged.
- Rotate the camera 180 degrees around the board when control changes between Sheep and Wolves, with a smooth transition.
- Local two-player and online matches use the same orientation behavior. Accessibility setting may disable rotation.

## Online architecture
- Use Godot high-level multiplayer over an authoritative server/relay, not direct peer-to-peer IP exposure.
- Private room flow: create room -> server returns short code -> join by code -> server assigns peer IDs -> host starts match.
- Random flow: queue -> server pairs compatible players -> server assigns sides -> match starts.
- Server validates every placement, move, capture, chain-capture deadline and terminal result against the same rules engine. Clients send intents, not trusted board states.
- Reconnect grace period, heartbeat, disconnect/forfeit handling, protocol versioning and rate limits are required.
- Do not embed server secrets in the Android app. Online play requires a deployed backend/relay and operational testing.

## Current implementation status
- The current Godot game remains local hot-seat by default.
- Opposite-side camera rotation has been added as the first concrete presentation step.
- This document is a design contract, not a claim that online matchmaking, room codes, player names or network synchronization are already implemented.
- Next implementation stages: local mode/name/side setup UI; integrate AI match setup; define and test authoritative network protocol; deploy backend; test Android reconnect and abuse cases.
