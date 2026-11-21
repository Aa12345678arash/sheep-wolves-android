import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import worker, { RoomDurableObject, type Env } from "../src/index";
import { initialGame } from "../src/engine";

type FakeSocket = {
  attachment: unknown;
  sent: string[];
  deserializeAttachment(): unknown;
  send(payload: string): void;
  serializeAttachment(value: unknown): void;
  close(code?: number, reason?: string): void;
  closed?: { code?: number; reason?: string };
};

function socket(attachment: unknown): FakeSocket {
  return {
    attachment,
    sent: [],
    deserializeAttachment() { return this.attachment; },
    send(payload: string) { this.sent.push(payload); },
    serializeAttachment(value: unknown) { this.attachment = value; },
    close(code?: number, reason?: string) { this.closed = { code, reason }; },
  };
}

function roomWithSockets(sockets: FakeSocket[]): RoomDurableObject {
  const ctx = {
    getWebSockets: () => sockets,
    storage: {
      get: async () => undefined,
      put: async () => undefined,
      setAlarm: async () => undefined,
    },
  } as unknown as DurableObjectState;
  return new RoomDurableObject(ctx, {} as Env);
}

test("room broadcasts never reach unauthenticated or invalid WebSocket attachments", () => {
  const host = socket({ playerId: "host" });
  const guest = socket({ playerId: "guest" });
  const pending = socket({ playerId: "" });
  const missing = socket(null);
  const malformed = socket({ playerId: "spectator" });
  const room = roomWithSockets([host, guest, pending, missing, malformed]);

  (room as unknown as { broadcast(data: unknown): void }).broadcast({ type: "private_state", seq: 7 });

  assert.equal(host.sent.length, 1);
  assert.equal(guest.sent.length, 1);
  assert.equal(pending.sent.length, 0);
  assert.equal(missing.sent.length, 0);
  assert.equal(malformed.sent.length, 0);
  assert.deepEqual(JSON.parse(host.sent[0]), { type: "private_state", seq: 7 });
});

test("concurrent Durable Object operations are serialized", async () => {
  const room = roomWithSockets([]);
  const exclusive = (room as unknown as {
    exclusive<T>(work: () => Promise<T>): Promise<T>;
  }).exclusive.bind(room);

  let active = 0;
  let maximumActive = 0;
  let completed = 0;
  await Promise.all(Array.from({ length: 12 }, () => exclusive(async () => {
    active++;
    maximumActive = Math.max(maximumActive, active);
    await Promise.resolve();
    completed++;
    active--;
  })));

  assert.equal(completed, 12);
  assert.equal(maximumActive, 1);
});

test("an unauthenticated socket is closed unless its first message is valid auth", async () => {
  const pending = socket({ playerId: "" });
  const roomData = {
    code: "abcdefghijklmnop",
    createdAt: Date.now(),
    expiresAt: Date.now() + 60_000,
    status: "waiting",
    players: [],
    game: initialGame(),
    seq: 0,
    events: [],
    result: null,
  };
  const ctx = {
    getWebSockets: () => [pending],
    storage: {
      get: async () => roomData,
      put: async () => undefined,
      setAlarm: async () => undefined,
    },
  } as unknown as DurableObjectState;
  const room = new RoomDurableObject(ctx, {} as Env);
  await (room as unknown as {
    handleWebSocketMessage(ws: FakeSocket, message: string): Promise<void>;
  }).handleWebSocketMessage(pending, JSON.stringify({ type: "state" }));
  assert.deepEqual(pending.closed, { code: 4003, reason: "authentication_required" });
  assert.equal(pending.sent.length, 0);
});

test("reconnecting player replaces the old socket without a false disconnect", async () => {
  const token = "test-player-token-with-more-than-32-characters";
  const tokenHash = createHash("sha256").update(token).digest("hex");
  const oldSocket = socket({ playerId: "host" });
  const newSocket = socket({ playerId: "" });
  const roomData = {
    code: "abcdefghijklmnop",
    createdAt: Date.now(),
    expiresAt: Date.now() + 60_000,
    status: "waiting",
    players: [{
      id: "host", side: "wolves", name: "Host", tokenHash, ready: false,
      disconnectedAt: Date.now() - 1000, lastSeq: 0, rate: [],
    }],
    game: initialGame(),
    seq: 0,
    events: [],
    result: null,
  };
  const ctx = {
    getWebSockets: () => [oldSocket, newSocket],
    storage: {
      get: async () => roomData,
      put: async (_key: string, value: unknown) => Object.assign(roomData, value),
      setAlarm: async () => undefined,
    },
  } as unknown as DurableObjectState;
  const room = new RoomDurableObject(ctx, {} as Env);
  await (room as unknown as {
    handleWebSocketMessage(ws: FakeSocket, message: string): Promise<void>;
  }).handleWebSocketMessage(newSocket, JSON.stringify({ type: "auth", token }));

  assert.deepEqual(oldSocket.closed, { code: 4001, reason: "reconnected" });
  assert.deepEqual(newSocket.attachment, { playerId: "host" });
  await (room as unknown as { markDisconnected(ws: FakeSocket): Promise<void> }).markDisconnected(oldSocket);
  assert.equal(roomData.players[0].disconnectedAt, null);
  assert.ok(newSocket.sent.some(payload => JSON.parse(payload).type === "snapshot"));
});

test("cross-origin browser requests cannot claim or create a private room", async () => {
  const response = await worker.fetch(new Request("https://wolf-dusk-rooms.example.workers.dev/api/rooms", {
    method: "POST",
    headers: { Origin: "https://attacker.example", "Content-Type": "application/json" },
    body: JSON.stringify({ displayName: "intruder" }),
  }), {} as Env);
  assert.equal(response.status, 403);
  assert.deepEqual(await response.json(), { error: "origin_not_allowed" });
});

test("two simultaneous join requests cannot both occupy the guest seat", async () => {
  const roomData = {
    code: "abcdefghijklmnop",
    createdAt: Date.now(),
    expiresAt: Date.now() + 60_000,
    status: "waiting",
    players: [{
      id: "host", side: "wolves", name: "Host", tokenHash: "stored-hash",
      ready: false, disconnectedAt: null, lastSeq: 0, rate: [],
    }],
    game: initialGame(),
    seq: 0,
    events: [],
    result: null,
  };
  const ctx = {
    getWebSockets: () => [],
    storage: {
      get: async () => roomData,
      put: async (_key: string, value: unknown) => Object.assign(roomData, value),
      setAlarm: async () => undefined,
    },
  } as unknown as DurableObjectState;
  const room = new RoomDurableObject(ctx, {} as Env);
  const makeJoin = (name: string) => room.fetch(new Request("https://room.internal/join", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name }),
  }));
  const responses = await Promise.all([makeJoin("Guest A"), makeJoin("Guest B")]);
  assert.deepEqual(responses.map(response => response.status).sort(), [201, 409]);
  assert.equal(roomData.players.length, 2);
  const playerIds: string[] = roomData.players.map(player => String(player.id));
  assert.equal(playerIds.filter(id => id === "guest").length, 1);
});

test("unauthenticated WebSocket is closed after the handshake timeout", async () => {
  const pending = socket({ playerId: "", acceptedAt: Date.now() - 20_000 });
  const roomData = {
    code: "abcdefghijklmnop",
    createdAt: Date.now() - 20_000,
    expiresAt: Date.now() + 60_000,
    status: "waiting",
    players: [],
    game: initialGame(),
    seq: 0,
    events: [],
    result: null,
  };
  const ctx = {
    getWebSockets: () => [pending],
    storage: {
      get: async () => roomData,
      put: async () => undefined,
      setAlarm: async () => undefined,
      deleteAll: async () => undefined,
    },
  } as unknown as DurableObjectState;
  const room = new RoomDurableObject(ctx, {} as Env);
  await room.alarm();
  assert.deepEqual(pending.closed, { code: 4003, reason: "authentication_timeout" });
});

test("connect schedules the authentication timeout as the next Durable Object alarm", async () => {
  const acceptedAt = Date.now();
  const pending = socket({ playerId: "", acceptedAt });
  let scheduledAlarm = 0;
  const roomData = {
    code: "abcdefghijklmnop",
    createdAt: acceptedAt,
    expiresAt: acceptedAt + 24 * 60 * 60 * 1000,
    status: "waiting",
    players: [],
    game: initialGame(),
    seq: 0,
    events: [],
    result: null,
  };
  const ctx = {
    getWebSockets: () => [pending],
    storage: {
      get: async () => roomData,
      put: async () => undefined,
      setAlarm: async (timestamp: number) => { scheduledAlarm = timestamp; },
    },
  } as unknown as DurableObjectState;
  const room = new RoomDurableObject(ctx, {} as Env);
  await (room as unknown as { scheduleNextAlarm(value: typeof roomData): Promise<void> }).scheduleNextAlarm(roomData);
  assert.equal(scheduledAlarm, acceptedAt + 15_000);
});

test("match-not-ready rejection returns the unchanged expected action sequence", async () => {
  const host = socket({ playerId: "host" });
  const roomData = {
    code: "abcdefghijklmnop",
    createdAt: Date.now(),
    expiresAt: Date.now() + 60_000,
    status: "waiting",
    players: [{
      id: "host", side: "wolves", name: "Host", tokenHash: "hash",
      ready: true, disconnectedAt: null, lastSeq: 0, rate: [],
    }],
    game: initialGame(),
    seq: 0,
    events: [],
    result: null,
  };
  const ctx = {
    getWebSockets: () => [host],
    storage: {
      get: async () => roomData,
      put: async (_key: string, value: unknown) => Object.assign(roomData, value),
      setAlarm: async () => undefined,
    },
  } as unknown as DurableObjectState;
  const room = new RoomDurableObject(ctx, {} as Env);
  await (room as unknown as { handleWebSocketMessage(ws: FakeSocket, message: string): Promise<void> })
    .handleWebSocketMessage(host, JSON.stringify({ seq: 1, action: { type: "place_wolf", node: 0 } }));
  const error = JSON.parse(host.sent[0]);
  assert.equal(error.code, "match_not_ready");
  assert.equal(error.expected, 1);
});

test("rate-limit rejection returns the unchanged expected action sequence", async () => {
  const now = Date.now();
  const host = socket({ playerId: "host" });
  const roomData = {
    code: "abcdefghijklmnop",
    createdAt: now,
    expiresAt: now + 60_000,
    status: "playing",
    players: [{
      id: "host", side: "wolves", name: "Host", tokenHash: "hash",
      ready: true, disconnectedAt: null, lastSeq: 0, rate: Array(30).fill(now - 1),
    }],
    game: initialGame(),
    seq: 0,
    events: [],
    result: null,
  };
  const ctx = {
    getWebSockets: () => [host],
    storage: {
      get: async () => roomData,
      put: async (_key: string, value: unknown) => Object.assign(roomData, value),
      setAlarm: async () => undefined,
    },
  } as unknown as DurableObjectState;
  const room = new RoomDurableObject(ctx, {} as Env);
  await (room as unknown as { handleWebSocketMessage(ws: FakeSocket, message: string): Promise<void> })
    .handleWebSocketMessage(host, JSON.stringify({ seq: 1, action: { type: "place_wolf", node: 0 } }));
  const error = JSON.parse(host.sent[0]);
  assert.equal(error.code, "rate_limited");
  assert.equal(error.expected, 1);
});
