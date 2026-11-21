import { applyAction, expireChain, initialGame, PROTOCOL_VERSION, RULESET_ID, type GameAction, type Side, type GameState } from "./engine";

export interface Env { ROOMS: DurableObjectNamespace; }
type Player = { id: "host" | "guest"; side: Side; name: string; tokenHash: string; ready: boolean; disconnectedAt: number | null; lastSeq: number; rate: number[] };
type Room = { code: string; createdAt: number; expiresAt: number; status: "waiting" | "ready" | "playing" | "finished"; players: Player[]; game: GameState; seq: number; events: unknown[]; result: Side | null };
const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers: { "content-type":"application/json; charset=utf-8", "cache-control":"no-store" } });
const randomToken = (bytes = 32) => { const a = crypto.getRandomValues(new Uint8Array(bytes)); return btoa(String.fromCharCode(...a)).replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/,""); };
const digest = async (value: string) => Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(value)))).map(x=>x.toString(16).padStart(2,"0")).join("");
const cleanName = (v: unknown) => typeof v === "string" ? v.trim().replace(/[<>\u0000-\u001f]/g,"").slice(0,24) : "";
const cors = { "access-control-allow-methods":"GET,POST,OPTIONS", "access-control-allow-headers":"content-type", "cache-control":"no-store", "vary":"Origin" };
const UNAUTHENTICATED_SOCKET_TTL_MS = 15_000;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const requestOrigin = request.headers.get("Origin");
    // Browser callers must be same-origin. Native Android clients normally omit
    // Origin; requests that do provide it cannot use a third-party site to claim
    // a guest seat or open a room on the player's behalf.
    if (requestOrigin && requestOrigin !== url.origin) return json({error:"origin_not_allowed"},403);
    if (request.method === "OPTIONS") return new Response(null,{status:204,headers:{...cors,"access-control-allow-origin":requestOrigin ?? url.origin}});
    if (url.pathname === "/health") return json({ok:true,service:"wolf-dusk-rooms",protocol:PROTOCOL_VERSION,ruleset:RULESET_ID});
    if (url.pathname === "/api/rooms" && request.method === "POST") {
      const body = await request.json().catch(()=>null) as any;
      if (!body || body.protocolVersion !== PROTOCOL_VERSION || body.rulesetId !== RULESET_ID) return json({error:"protocol_or_ruleset_mismatch"},409);
      const name = cleanName(body.displayName); if (!name) return json({error:"display_name_required"},400);
      const code = randomToken(12);
      const stub = env.ROOMS.get(env.ROOMS.idFromName(code));
      const response = await stub.fetch("https://room.internal/create",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({code,name})});
      const result = await response.json() as any;
      if (!response.ok) return json(result,response.status);
      return json({...result,inviteUrl: url.origin + "/join/" + code},201);
    }
    const join = url.pathname.match(/^\/api\/rooms\/([A-Za-z0-9_-]{16})\/join$/);
    if (join && request.method === "POST") {
      const body = await request.json().catch(()=>null) as any;
      if (!body || body.protocolVersion !== PROTOCOL_VERSION || body.rulesetId !== RULESET_ID) return json({error:"protocol_or_ruleset_mismatch"},409);
      const name = cleanName(body.displayName); if (!name) return json({error:"display_name_required"},400);
      const stub = env.ROOMS.get(env.ROOMS.idFromName(join[1]));
      const response = await stub.fetch("https://room.internal/join",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({name})});
      return new Response(response.body,{status:response.status,headers:{"content-type":"application/json; charset=utf-8","cache-control":"no-store"}});
    }
    const ws = url.pathname.match(/^\/api\/rooms\/([A-Za-z0-9_-]{16})\/ws$/);
    if (ws && request.headers.get("Upgrade")?.toLowerCase() === "websocket") {
      const stub = env.ROOMS.get(env.ROOMS.idFromName(ws[1]));
      return stub.fetch(new Request("https://room.internal/ws" + url.search,{headers:request.headers}));
    }
    const landing = url.pathname.match(/^\/join\/([A-Za-z0-9_-]{16})$/);
    if (landing && request.method === "GET") {
      const code = landing[1];
      return new Response(`<!doctype html><html lang="fa" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>دعوت به گرگ و میش</title><body style="font-family:system-ui;max-width:540px;margin:12vh auto;padding:24px;background:#edf5e8;color:#17351f"><h1>گرگ و میش ـ راز دشت سبز</h1><p>برای پیوستن به اتاق خصوصی، کد زیر را در بخش «بازی آنلاین» وارد کنید.</p><p style="font-size:1.6rem;font-weight:700;letter-spacing:.12em;background:white;padding:16px;border-radius:12px;text-align:center" id="code">${code}</p><button onclick="navigator.clipboard.writeText('${code}')">کپی کد دعوت</button><p>این پیوند به‌تنهایی بازی را آغاز نمی‌کند؛ هر دو بازیکن باید نسخه سازگار بازی را داشته باشند.</p></body></html>`,{headers:{"content-type":"text/html; charset=utf-8","cache-control":"no-store"}});
    }
    return json({error:"not_found"},404);
  }
};

export class RoomDurableObject {
  private lock: Promise<void> = Promise.resolve();
  constructor(private ctx: DurableObjectState, private env: Env) {}
  private async exclusive<T>(work: () => Promise<T>): Promise<T> {
    const previous = this.lock;
    let release!: () => void;
    this.lock = new Promise<void>(resolve => { release = resolve; });
    await previous;
    try { return await work(); } finally { release(); }
  }
  private async load(): Promise<Room | null> { return await this.ctx.storage.get<Room>("room") ?? null; }
  private async save(room: Room): Promise<void> { await this.ctx.storage.put("room",room); }
  async fetch(request: Request): Promise<Response> { return this.exclusive(() => this.handleFetch(request)); }
  private async handleFetch(request: Request): Promise<Response> {
    const path = new URL(request.url).pathname;
    if (path === "/create" && request.method === "POST") {
      if (await this.load()) return json({error:"room_already_exists"},409);
      const b = await request.json() as any, now = Date.now();
      const hostToken = randomToken();
      const room: Room = { code:b.code,createdAt:now,expiresAt:now+24*60*60*1000,status:"waiting",players:[{id:"host",side:"wolves",name:b.name,tokenHash:await digest(hostToken),ready:false,disconnectedAt:null,lastSeq:0,rate:[]}],game:initialGame(),seq:0,events:[],result:null };
      await this.save(room); await this.ctx.storage.setAlarm(room.expiresAt);
      return json({roomCode:b.code,playerToken:hostToken,side:"wolves",status:room.status,protocolVersion:PROTOCOL_VERSION,rulesetId:RULESET_ID});
    }
    if (path === "/join" && request.method === "POST") {
      const room = await this.load(); if (!room || room.expiresAt < Date.now()) return json({error:"room_expired"},410);
      if (room.players.length !== 1 || room.status !== "waiting") return json({error:"room_full"},409);
      const b = await request.json() as any, token = randomToken();
      room.players.push({id:"guest",side:"sheep",name:b.name,tokenHash:await digest(token),ready:false,disconnectedAt:null,lastSeq:0,rate:[]});
      await this.save(room);
      return json({roomCode:room.code,playerToken:token,side:"sheep",status:room.status,protocolVersion:PROTOCOL_VERSION,rulesetId:RULESET_ID},201);
    }
    if (path === "/ws" && request.headers.get("Upgrade")?.toLowerCase() === "websocket") return this.connect(request);
    return json({error:"not_found"},404);
  }
  private async connect(request: Request): Promise<Response> {
    const room = await this.load(); if (!room || room.expiresAt < Date.now()) return json({error:"room_expired"},410);
    const pair = new WebSocketPair(); const client = pair[0], server = pair[1];
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment({playerId:"",acceptedAt:Date.now()});
    await this.scheduleNextAlarm(room);
    return new Response(null,{status:101,webSocket:client});
  }
  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    await this.exclusive(() => this.handleWebSocketMessage(ws,message));
  }
  private async handleWebSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    const attachment = ws.deserializeAttachment() as {playerId:"host"|"guest"|""} | null;
    if (!attachment) { ws.close(4003,"invalid_session"); return; }
    const room = await this.load(); if (!room) { ws.close(4004,"room_missing"); return; }
    let msg: any; try { msg = JSON.parse(typeof message === "string" ? message : new TextDecoder().decode(message)); } catch { ws.send(JSON.stringify({type:"error",code:"invalid_json"})); return; }
    const now = Date.now();
    if (!attachment.playerId) {
      if (msg.type !== "auth" || typeof msg.token !== "string" || msg.token.length < 32) { ws.close(4003,"authentication_required"); return; }
      const tokenHash = await digest(msg.token);
      const authenticated = room.players.find(p=>p.tokenHash === tokenHash);
      if (!authenticated) { ws.close(4003,"unauthorized"); return; }
      // Attach the new authenticated socket before closing an older session.
      // The old socket's close callback can then see this replacement and must
      // not mark the player disconnected.
      ws.serializeAttachment({playerId:authenticated.id});
      for (const old of this.ctx.getWebSockets()) {
        if (old === ws) continue;
        const oldAttachment = old.deserializeAttachment() as {playerId?:string} | null;
        if (oldAttachment?.playerId === authenticated.id) old.close(4001,"reconnected");
      }
      authenticated.disconnectedAt = null;
      await this.save(room);
      await this.scheduleNextAlarm(room);
      this.broadcast({type:"presence",playerId:authenticated.id,connected:true});
      ws.send(JSON.stringify({type:"snapshot",roomCode:room.code,status:room.status,players:room.players.map(p=>({id:p.id,side:p.side,name:p.name,ready:p.ready,connected:this.ctx.getWebSockets().some(socket=>{const a=socket.deserializeAttachment() as {playerId?:string}|null;return a?.playerId===p.id;})})),game:room.game,seq:room.seq,nextActionSeq:authenticated.lastSeq+1,events:room.events.slice(-64)}));
      return;
    }
    if (msg.type === "auth") { ws.close(4003,"already_authenticated"); return; }
    const player = room.players.find(p=>p.id===attachment.playerId);
    if (!player) { ws.close(4003,"invalid_player"); return; }
    player.rate = player.rate.filter(t=>now-t<10000);
    if (player.rate.length >= 30) { ws.send(JSON.stringify({type:"error",code:"rate_limited",expected:player.lastSeq+1})); return; }
    player.rate.push(now);
    if (msg.type === "ping") { ws.send(JSON.stringify({type:"pong",at:now})); return; }
    if (msg.type === "ready") {
      player.ready = true;
      if (room.players.length === 2 && room.players.every(p=>p.ready)) room.status = "playing";
      room.seq++; room.events.push({seq:room.seq,type:"ready",playerId:player.id,at:now});
      await this.save(room); this.broadcast({type:"snapshot",status:room.status,players:room.players.map(p=>({id:p.id,side:p.side,name:p.name,ready:p.ready})),game:room.game,seq:room.seq});
      return;
    }
    if (room.status !== "playing") { ws.send(JSON.stringify({type:"error",code:"match_not_ready",expected:player.lastSeq+1})); return; }
    if (!Number.isInteger(msg.seq) || msg.seq !== player.lastSeq + 1) { ws.send(JSON.stringify({type:"error",code:"stale_or_out_of_order_sequence",expected:player.lastSeq+1})); return; }
    const action = msg.action as GameAction;
    if (!action || !["place_wolf","move_sheep","move_wolf","finish_chain"].includes(action.type)) { ws.send(JSON.stringify({type:"error",code:"unknown_action",expected:player.lastSeq+1})); return; }
    const applied = applyAction(room.game,player.side,action,now);
    if (!applied.ok) {
      if (applied.code === "chain_window_expired") { room.game = applied.state; room.seq++; await this.save(room); this.broadcast({type:"state",game:room.game,seq:room.seq}); }
      ws.send(JSON.stringify({type:"error",code:applied.code,expected:player.lastSeq+1})); return;
    }
    player.lastSeq = msg.seq; room.game = applied.state; room.seq++;
    room.events.push({seq:room.seq,playerId:player.id,side:player.side,action,at:now});
    if (room.events.length > 256) room.events.splice(0,room.events.length-256);
    if (room.game.turn === "finished") { room.status = "finished"; room.result = room.game.winner; }
    await this.save(room);
    await this.scheduleNextAlarm(room);
    this.broadcast({type:"state",game:room.game,seq:room.seq,lastAction:{playerId:player.id,action},status:room.status,result:room.result});
  }
  async webSocketClose(ws: WebSocket): Promise<void> { await this.exclusive(() => this.markDisconnected(ws)); }
  async webSocketError(ws: WebSocket): Promise<void> { await this.exclusive(() => this.markDisconnected(ws)); }
  private async markDisconnected(ws: WebSocket): Promise<void> {
    const a = ws.deserializeAttachment() as {playerId:"host"|"guest"} | null; if (!a) return;
    const room = await this.load(); if (!room) return;
    const p = room.players.find(x=>x.id===a.playerId); if (!p) return;
    const anotherSocketIsOpen = this.ctx.getWebSockets().some(other => {
      if (other === ws) return false;
      const otherAttachment = other.deserializeAttachment() as {playerId?:string} | null;
      return otherAttachment?.playerId === p.id;
    });
    if (anotherSocketIsOpen) return;
    p.disconnectedAt = Date.now(); await this.save(room);
    if (room.status === "playing") await this.scheduleNextAlarm(room);
    this.broadcast({type:"presence",playerId:p.id,connected:false,reconnectGraceMs:45000});
  }
  private async scheduleNextAlarm(room: Room): Promise<void> {
    const now = Date.now();
    const pendingAuthDeadlines = this.ctx.getWebSockets().map(socket => {
      const attachment = socket.deserializeAttachment() as {playerId?:string;acceptedAt?:number} | null;
      return attachment && !attachment.playerId && typeof attachment.acceptedAt === "number"
        ? attachment.acceptedAt + UNAUTHENTICATED_SOCKET_TTL_MS : Infinity;
    });
    const deadlines = [room.expiresAt,room.game.chainDeadline ?? Infinity,...room.players.map(p=>p.disconnectedAt === null ? Infinity : p.disconnectedAt+45000),...pendingAuthDeadlines].filter(x=>x>now);
    if (deadlines.length) await this.ctx.storage.setAlarm(Math.min(...deadlines));
  }
  async alarm(): Promise<void> { await this.exclusive(() => this.handleAlarm()); }
  private async handleAlarm(): Promise<void> {
    const room = await this.load(); if (!room) return;
    const now = Date.now();
    // Do not let clients hold unauthenticated room sockets open indefinitely.
    for (const socket of this.ctx.getWebSockets()) {
      const attachment = socket.deserializeAttachment() as {playerId?:string;acceptedAt?:number} | null;
      if (attachment && !attachment.playerId && typeof attachment.acceptedAt === "number" && now - attachment.acceptedAt >= UNAUTHENTICATED_SOCKET_TTL_MS) {
        socket.close(4003,"authentication_timeout");
      }
    }
    if (room.game.chainDeadline && expireChain(room.game,now)) {
      room.seq++; room.events.push({seq:room.seq,type:"chain_timeout",at:now});
      await this.save(room); this.broadcast({type:"state",game:room.game,seq:room.seq,status:room.status});
    }
    if (now >= room.expiresAt) { await this.ctx.storage.deleteAll(); return; }
    if (room.status === "playing") {
      const disconnected = room.players.find(p=>p.disconnectedAt !== null && now-p.disconnectedAt >= 45000);
      if (disconnected) {
        room.status = "finished"; room.result = disconnected.id === "host" ? "sheep" : "wolves";
        room.game.turn = "finished"; room.game.winner = room.result;
        room.seq++; room.events.push({seq:room.seq,type:"disconnect_forfeit",playerId:disconnected.id,at:now});
        await this.save(room); this.broadcast({type:"match_end",reason:"disconnect_forfeit",winner:room.result,seq:room.seq});
      }
    }
    const pendingAuthDeadlines = this.ctx.getWebSockets().map(socket => {
      const attachment = socket.deserializeAttachment() as {playerId?:string;acceptedAt?:number} | null;
      return attachment && !attachment.playerId && typeof attachment.acceptedAt === "number"
        ? attachment.acceptedAt + UNAUTHENTICATED_SOCKET_TTL_MS : Infinity;
    });
    const deadlines = [room.expiresAt,room.game.chainDeadline ?? Infinity,...room.players.map(p=>p.disconnectedAt === null ? Infinity : p.disconnectedAt+45000),...pendingAuthDeadlines].filter(x=>x>now);
    if (deadlines.length) await this.ctx.storage.setAlarm(Math.min(...deadlines));
  }
  private broadcast(data: unknown): void {
    const payload = JSON.stringify(data);
    for (const socket of this.ctx.getWebSockets()) {
      // A WebSocket is accepted before its first auth message. Never disclose
      // room state or presence events to that unauthenticated connection.
      let attachment: { playerId?: string } | null = null;
      try { attachment = socket.deserializeAttachment() as { playerId?: string } | null; } catch { /* invalid attachment */ }
      if (attachment?.playerId !== "host" && attachment?.playerId !== "guest") continue;
      try { socket.send(payload); } catch { /* stale socket is removed by runtime */ }
    }
  }
}
