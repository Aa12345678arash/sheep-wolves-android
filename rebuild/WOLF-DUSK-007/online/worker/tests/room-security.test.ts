import test from "node:test";
import assert from "node:assert/strict";
import { RoomDurableObject, type Env } from "../src/index";

type FakeSocket = {
  attachment: unknown;
  sent: string[];
  deserializeAttachment(): unknown;
  send(payload: string): void;
};

function socket(attachment: unknown): FakeSocket {
  return {
    attachment,
    sent: [],
    deserializeAttachment() { return this.attachment; },
    send(payload: string) { this.sent.push(payload); },
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
