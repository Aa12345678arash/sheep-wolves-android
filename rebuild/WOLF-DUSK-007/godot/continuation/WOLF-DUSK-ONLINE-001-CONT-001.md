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


## Implementation update — 2026-11-21

An isolated Cloudflare Workers + SQLite Durable Object backend foundation has been added under `rebuild/WOLF-DUSK-007/online/worker/`. It is not deployed and is not yet connected to the Godot UI.

Implemented in source:
- room creation with 96-bit random room code and 256-bit per-player bearer token (only token hashes are persisted);
- one host / one guest, opposite roles (wolves / sheep), 24-hour room expiry and readiness handshake;
- WebSocket snapshots and authoritative move intents (clients do not submit board snapshots);
- server-side topology/rule engine for 25 nodes and 56 edges, three wolf placements, sheep-first turn, one-sheep straight-line captures, win thresholds and 3-second follow-up capture window;
- sequence checks, message rate cap, event history, 45-second reconnect grace and forfeit handling;
- deployment config using SQLite-backed Durable Objects and the default workers.dev hostname; no custom domain is required.

Validation status at this record:
- GitHub Actions workflow `.github/workflows/wolf-dusk-online-worker.yml` added.
- Early runs failed before typecheck because the initially selected Cloudflare type package version was not published. The dependency was removed in favor of local runtime declarations; the current CI run must pass install, TypeScript checks, engine tests and Wrangler dry-run before this milestone is accepted.
- The engine currently mirrors the Godot runtime's one-follow-up-capture / 3-second behavior. The recovered legacy source notes a potential discrepancy (unlimited chained captures versus the current Godot runtime's one extra capture). This must be reconciled against the accepted in-game rules and regression tests before public release; do not silently change the shipped rules.

Remaining blockers before real online play:
1. CI green and adversarial tests for invalid turns, placements, stale/duplicate sequences, simultaneous joins, room-full, token expiry, reconnect and disconnect.
2. Godot Android client integration: create/join room, secure WebSocket connection, readiness, authoritative state rendering, reconnect sequence recovery and invite share action.
3. Resolve the documented chain-capture compatibility discrepancy and compute a cryptographic ruleset hash from the exact accepted rules/graph.
4. Deploy only after the owner connects an account. A free Cloudflare account can use a workers.dev subdomain and SQLite Durable Objects; this requires the owner's interactive account authorization. No credentials or paid services are assumed.
5. Android device-to-device test before describing the feature as operational.

No changes were made to `main`, stable 044 or the release branch.
