export const PROTOCOL_VERSION = 1;
export const RULESET_ID = "wolf-dusk-25x25-56edges-v1";
export const CHAIN_WINDOW_MS = 3000;
export const SHEEP_WIN_THRESHOLD = 8;
export type Side = "wolves" | "sheep";
export type Turn = "place_wolves" | "sheep" | "wolves" | "finished";
export type GameAction =
  | { type: "place_wolf"; node: number }
  | { type: "move_sheep"; from: number; to: number }
  | { type: "move_wolf"; from: number; to: number }
  | { type: "finish_chain" };

const nodeId = (n: number) => String.fromCharCode(65 + Math.floor(n / 5)) + String(n % 5 + 1);
const nodeIndex = (id: string) => /^[A-E][1-5]$/.test(id) ? (id.charCodeAt(0) - 65) * 5 + Number(id[1]) - 1 : -1;
const edgePairs: [string, string][] = [];
for (let r = 0; r < 5; r++) for (let c = 0; c < 4; c++) edgePairs.push([nodeId(r * 5 + c), nodeId(r * 5 + c + 1)]);
for (let r = 0; r < 4; r++) for (let c = 0; c < 5; c++) edgePairs.push([nodeId(r * 5 + c), nodeId((r + 1) * 5 + c)]);
for (const [a, b] of [
  ["A1","B2"],["A3","B2"],["A3","B4"],["A5","B4"],
  ["B2","C1"],["B2","C3"],["B4","C3"],["B4","C5"],
  ["C1","D2"],["C3","D2"],["C3","D4"],["C5","D4"],
  ["D2","E1"],["D2","E3"],["D4","E3"],["D4","E5"],
] as [string, string][]) edgePairs.push([a,b]);
const key = (a: number, b: number) => a < b ? a + ":" + b : b + ":" + a;
const edges = new Set(edgePairs.map(([a,b]) => key(nodeIndex(a), nodeIndex(b))));
export const EDGE_KEYS = Array.from(edges).sort();
const adjacency: number[][] = Array.from({length:25}, () => []);
for (const pair of edges) {
  const [a,b] = pair.split(":").map(Number);
  adjacency[a].push(b); adjacency[b].push(a);
}
export const EDGE_COUNT = edges.size;
export const NODE_COUNT = 25;

export interface GameState {
  sheep: number[];
  wolves: number[];
  turn: Turn;
  chainWolf: number | null;
  chainDeadline: number | null;
  winner: Side | null;
}
export interface ApplyResult { ok: boolean; code?: string; state: GameState; }

export function initialGame(): GameState {
  const sheep = Array(25).fill(0);
  for (let n = 20; n < 25; n++) sheep[n] = 5;
  return { sheep, wolves: [], turn: "place_wolves", chainWolf: null, chainDeadline: null, winner: null };
}
export function occupied(s: GameState, n: number): boolean { return s.sheep[n] > 0 || s.wolves.includes(n); }
export function neighbors(n: number): number[] { return adjacency[n] ?? []; }
export function legalSheepMoves(s: GameState, from: number): number[] {
  if (!Number.isInteger(from) || from < 0 || from >= 25 || s.sheep[from] < 1) return [];
  return neighbors(from).filter(to => !occupied(s,to));
}
export function legalWolfMoves(s: GameState, from: number): number[] {
  if (!s.wolves.includes(from)) return [];
  return neighbors(from).filter(to => !occupied(s,to));
}
export function captureOptions(s: GameState, from: number): { middle:number; to:number }[] {
  if (!s.wolves.includes(from)) return [];
  const r = Math.floor(from / 5), c = from % 5;
  const result: {middle:number;to:number}[] = [];
  for (const middle of neighbors(from)) {
    if (s.sheep[middle] !== 1) continue;
    const dr = Math.floor(middle / 5) - r, dc = middle % 5 - c;
    for (const to of neighbors(middle)) {
      if (to === from || occupied(s,to)) continue;
      if (Math.floor(to / 5) - Math.floor(middle / 5) === dr && to % 5 - middle % 5 === dc) result.push({middle,to});
    }
  }
  return result;
}
export function sheepCount(s: GameState): number { return s.sheep.reduce((a,b) => a+b,0); }
function checkWinner(s: GameState): void {
  if (sheepCount(s) <= SHEEP_WIN_THRESHOLD) { s.winner = "wolves"; s.turn = "finished"; s.chainWolf = null; s.chainDeadline = null; return; }
  if (s.wolves.length === 3 && s.wolves.every(w => legalWolfMoves(s,w).length === 0 && captureOptions(s,w).length === 0)) {
    s.winner = "sheep"; s.turn = "finished"; s.chainWolf = null; s.chainDeadline = null;
  }
}
export function expireChain(s: GameState, now: number): boolean {
  if (s.turn !== "wolves" || s.chainWolf === null || s.chainDeadline === null || now < s.chainDeadline) return false;
  s.chainWolf = null; s.chainDeadline = null; s.turn = "sheep"; checkWinner(s); return true;
}
export function applyAction(current: GameState, side: Side, action: GameAction, now: number): ApplyResult {
  const s: GameState = structuredClone(current);
  if (s.turn === "finished") return {ok:false,code:"match_finished",state:s};
  if (expireChain(s,now)) return {ok:false,code:"chain_window_expired",state:s};
  if (action.type === "finish_chain") {
    if (side !== "wolves" || s.turn !== "wolves" || s.chainWolf === null) return {ok:false,code:"no_chain_to_finish",state:s};
    s.chainWolf = null; s.chainDeadline = null; s.turn = "sheep"; checkWinner(s);
    return {ok:true,state:s};
  }
  if (action.type === "place_wolf") {
    if (side !== "wolves" || s.turn !== "place_wolves") return {ok:false,code:"not_wolf_placement_turn",state:s};
    if (!Number.isInteger(action.node) || action.node < 0 || action.node >= 25 || occupied(s,action.node)) return {ok:false,code:"invalid_placement",state:s};
    s.wolves.push(action.node);
    if (s.wolves.length === 3) { s.turn = "sheep"; checkWinner(s); }
    return {ok:true,state:s};
  }
  if (action.type === "move_sheep") {
    if (side !== "sheep" || s.turn !== "sheep") return {ok:false,code:"not_sheep_turn",state:s};
    if (!legalSheepMoves(s,action.from).includes(action.to)) return {ok:false,code:"illegal_sheep_move",state:s};
    s.sheep[action.from]--; s.sheep[action.to]++; s.turn = "wolves"; checkWinner(s);
    return {ok:true,state:s};
  }
  if (side !== "wolves" || s.turn !== "wolves") return {ok:false,code:"not_wolf_turn",state:s};
  if (!Number.isInteger(action.from) || !Number.isInteger(action.to) || action.from < 0 || action.from >= 25 || action.to < 0 || action.to >= 25) return {ok:false,code:"invalid_node",state:s};
  if (s.chainWolf !== null && action.from !== s.chainWolf) return {ok:false,code:"wrong_chain_wolf",state:s};
  const capture = captureOptions(s,action.from).find(c => c.to === action.to);
  if (capture) {
    s.wolves = s.wolves.map(n => n === action.from ? action.to : n);
    s.sheep[capture.middle]--;
    if (sheepCount(s) <= SHEEP_WIN_THRESHOLD) { checkWinner(s); return {ok:true,state:s}; }
    if (s.chainWolf === null && captureOptions(s,action.to).length > 0) {
      s.chainWolf = action.to; s.chainDeadline = now + CHAIN_WINDOW_MS;
    } else {
      s.chainWolf = null; s.chainDeadline = null; s.turn = "sheep"; checkWinner(s);
    }
    return {ok:true,state:s};
  }
  if (s.chainWolf !== null) return {ok:false,code:"chain_capture_required",state:s};
  if (!legalWolfMoves(s,action.from).includes(action.to)) return {ok:false,code:"illegal_wolf_move",state:s};
  s.wolves = s.wolves.map(n => n === action.from ? action.to : n);
  s.turn = "sheep"; checkWinner(s);
  return {ok:true,state:s};
}
export function nodeLabel(n: number): string { return nodeId(n); }
export function verifyTopology(): boolean {
  return NODE_COUNT === 25 && EDGE_COUNT === 56 && adjacency.every((a,i) => a.every(j => edges.has(key(i,j))));
}
