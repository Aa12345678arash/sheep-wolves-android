extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")
const BoardGraph = preload("res://scripts/board_graph.gd")

func _initialize() -> void:
	call_deferred("_run")

func _move_keys(moves: Array[Dictionary]) -> Array[String]:
	var keys: Array[String] = []
	for move in moves:
		var side := str(move.get("side", ""))
		if side == "decline_chain":
			keys.append("decline_chain")
		else:
			keys.append("%s:%d>%d:%s" % [
				side, int(move.get("from", -1)), int(move.get("to", -1)),
				"capture" if bool(move.get("capture", false)) else "move"
			])
	keys.sort()
	return keys

func _expected_sheep_moves(state) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for from_node in range(BoardGraph.NODE_COUNT):
		for to_node in state.sheep_moves(from_node):
			result.append({"side": "sheep", "from": from_node, "to": to_node})
	return result

func _expected_wolf_moves(state, include_decline: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if include_decline and state.chain_wolf != -1:
		result.append({"side": "decline_chain"})
	var first_wolf: int = state.chain_wolf if state.chain_wolf != -1 else 0
	var last_wolf: int = state.chain_wolf + 1 if state.chain_wolf != -1 else BoardGraph.NODE_COUNT
	for from_node in range(first_wolf, last_wolf):
		if not state.wolves[from_node]:
			continue
		for capture in state.capture_options(from_node):
			result.append({"side": "wolf", "from": from_node, "to": int(capture.to), "capture": true})
		if state.chain_wolf == -1:
			for to_node in state.wolf_moves(from_node):
				result.append({"side": "wolf", "from": from_node, "to": to_node, "capture": false})
	return result

func _run() -> void:
	# The same opening setup used by the level-2 performance fixture.
	seed(460048)
	var state = GameState.new()
	for _i in range(3):
		var placement: int = AI.choose_wolf_placement(state, 2)
		assert(placement >= 0 and state.place_wolf(placement))
	assert(state.turn == GameState.Turn.SHEEP)
	var expected_sheep := _expected_sheep_moves(state)
	var actual_sheep := AI._legal_search_moves(state, false)
	assert(_move_keys(actual_sheep) == _move_keys(expected_sheep),
		"AI sheep search move generator must exactly match GameState.sheep_moves")

	var sheep_action: Dictionary = actual_sheep[0]
	assert(state.move_sheep(int(sheep_action.from), int(sheep_action.to)))
	var expected_wolves := _expected_wolf_moves(state, false)
	var actual_wolves := AI._legal_search_moves(state, false)
	assert(_move_keys(actual_wolves) == _move_keys(expected_wolves),
		"AI wolf search move generator must exactly match GameState wolf moves and captures")

	# Exact optional-chain fixture: same wolf only, capture-only plus decline.
	var chain = GameState.new()
	for node in range(BoardGraph.NODE_COUNT):
		chain.sheep[node] = 0
		chain.wolves[node] = false
	chain.wolves[0] = true
	chain.wolves[4] = true
	chain.wolves[20] = true
	chain.sheep[6] = 1
	chain.sheep[18] = 1
	chain.sheep[21] = 5
	chain.turn = GameState.Turn.WOLVES
	assert(chain.move_wolf(0, 12) == "captured_chain_available")
	var expected_chain := _expected_wolf_moves(chain, true)
	var actual_chain := AI._legal_search_moves(chain, true)
	assert(_move_keys(actual_chain) == _move_keys(expected_chain),
		"AI chain search must offer only same-wolf captures plus explicit decline")

	print("WOLF-DUSK-060 rule parity passed: search move generation exactly matches unchanged GameState movement, capture and chain rules.")
	quit()
