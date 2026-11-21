import test from "node:test";
import assert from "node:assert/strict";
import { EDGE_COUNT, NODE_COUNT, applyAction, captureOptions, initialGame, legalSheepMoves, verifyTopology, type GameState } from "../src/engine";

test("canonical board has 25 nodes and 56 unique edges", () => {
  assert.equal(NODE_COUNT,25); assert.equal(EDGE_COUNT,56); assert.equal(verifyTopology(),true);
});
test("wolf placement accepts three distinct empty nodes and then sheep move first", () => {
  let s=initialGame();
  for (const node of [0,2,4]) { const r=applyAction(s,"wolves",{type:"place_wolf",node},1000); assert.equal(r.ok,true); s=r.state; }
  assert.equal(s.turn,"sheep"); assert.equal(s.wolves.length,3);
});
test("sheep moves one animal and cannot move to occupied node", () => {
  let s=initialGame(); for (const node of [0,2,4]) s=applyAction(s,"wolves",{type:"place_wolf",node},1000).state;
  assert.ok(legalSheepMoves(s,20).length>0);
  const to=legalSheepMoves(s,20)[0];
  const r=applyAction(s,"sheep",{type:"move_sheep",from:20,to},1000);
  assert.equal(r.ok,true); assert.equal(r.state.sheep[20],4); assert.equal(r.state.sheep[to],1); assert.equal(r.state.turn,"wolves");
});
test("capture requires exactly one sheep, straight-line two-edge landing", () => {
  const s:GameState={sheep:Array(25).fill(0),wolves:[0,4,24],turn:"wolves",chainWolf:null,chainDeadline:null,winner:null};
  s.sheep[6]=1;
  assert.deepEqual(captureOptions(s,0),[{middle:6,to:12}]);
  s.sheep[6]=2;
  assert.deepEqual(captureOptions(s,0),[]);
});
test("a chained capture is locked to the same wolf and expires at three seconds", () => {
  const s:GameState={sheep:Array(25).fill(0),wolves:[0,4,24],turn:"wolves",chainWolf:null,chainDeadline:null,winner:null};
  s.sheep[6]=1; s.sheep[18]=1;
  let r=applyAction(s,"wolves",{type:"move_wolf",from:0,to:12},1000);
  assert.equal(r.ok,true); assert.equal(r.state.chainWolf,12); assert.equal(r.state.chainDeadline,4000);
  r=applyAction(r.state,"wolves",{type:"move_wolf",from:4,to:3},2000);
  assert.equal(r.ok,false); assert.equal(r.code,"wrong_chain_wolf");
  r=applyAction(r.state,"wolves",{type:"move_wolf",from:12,to:24},4000);
  assert.equal(r.ok,false); assert.equal(r.code,"chain_window_expired"); assert.equal(r.state.turn,"sheep");
});
