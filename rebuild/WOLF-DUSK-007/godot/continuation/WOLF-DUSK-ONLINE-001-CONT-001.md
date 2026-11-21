# WOLF-DUSK-ONLINE-001 — authoritative online rooms and invite links

Date: 2026-11-21

## Isolation
- Branch: `WOLF-DUSK-ONLINE-001-INVITE-ROOMS`
- Base: `0de60facfce53d126e1b312dc811a2d5961edb6e`
- Keep `main`, stable version 044 and all release branches unchanged.

## Existing agreed architecture
The existing `docs/multiplayer_and_orientation.md` is the authority:
- server-authoritative online play; do not expose peer IPs or trust client-sent board states.
- private room creation returns a short join code; invite link opens the app/site and joins that room.
- two players receive peer IDs and opposite sides; host starts after both are ready.
- server validates placements, moves, captures, chain-capture deadline and terminal state against the canonical rules.
- heartbeat, reconnect grace period, disconnect/forfeit, protocol versioning and rate limits are required.
- local hot-seat remains available; online must not be represented as working until a real server is deployed and tested.

## Planned player journey
1. Player selects «بازی آنلاین».
2. «ساخت اتاق» creates a server-side room and receives an unguessable, short-lived invite token.
3. The app builds a universal/deep link such as `https://<approved-game-domain>/join/<token>`.
4. Recipient opens the link; if the app is installed it opens the room, otherwise a lightweight web landing page offers install/open and preserves the token.
5. Server waits for both players, allows side selection or fair assignment, then host starts.
6. Server is authoritative for every turn and stores a short reconnect snapshot.
7. When a player disconnects, the opponent sees a countdown; reconnect restores the same match or applies the declared forfeit policy.

## Technical requirements
- Separate room service and authoritative match engine from Godot presentation.
- Use TLS for HTTPS/WSS, random high-entropy invite tokens, expiry, room capacity=2, rate limiting and abuse controls.
- Never put server secrets in the Android client.
- Validate every command server-side using the same canonical 25-node / 56-edge rules and the exact chain timer.
- Include match protocol version and ruleset hash; reject incompatible clients.
- Add deterministic replay/event log for dispute and reconnect recovery.
- Add tests for duplicate commands, out-of-turn moves, illegal captures, stale sequence numbers, token expiry, room-full, disconnect/reconnect and simultaneous joins.

## Deployment dependency / link status
No production host, domain, server credentials or deployment target is currently configured in this repository. The source code alone cannot create a working public invite link. A real invite URL must not be fabricated. The app can create a valid share link only after the room service is deployed behind an approved HTTPS domain.
