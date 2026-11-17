extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")
const BoardGraph = preload("res://scripts/board_graph.gd")

func _initialize() -> void:
	call_deferred("_run")

func _empty_state():
	var state = GameState.new()
	for node in range(BoardGraph.NODE_COUNT):
		state.sheep[node] = 0
		state.wolves[node] = false
	state.turn = GameState.Turn.WOLVES
	state.chain_wolf = -1
	state.chain_capture_count = 0
	state.winner = ""
	state.position_history.clear()
	state._record_position()
	return state

func _has_capture(state, from_node: int, to_node: int) -> bool:
	for option in state.capture_options(from_node):
		if int(option.to) == to_node:
			return true
	return false

func _run() -> void:
	# A capture requires exactly one sheep and an empty landing point.
	var single = _empty_state()
	single.wolves[0] = true
	single.sheep[1] = 1
	single.sheep[20] = 5
	single.sheep[21] = 5
	assert(_has_capture(single, 0, 2), "One sheep on the middle node must allow the straight jump")

	var stacked = _empty_state()
	stacked.wolves[0] = true
	stacked.sheep[1] = 2
	stacked.sheep[20] = 5
	stacked.sheep[21] = 5
	assert(not _has_capture(stacked, 0, 2), "A stack of two sheep must not be captured as one")

	var occupied_landing = _empty_state()
	occupied_landing.wolves[0] = true
	occupied_landing.sheep[1] = 1
	occupied_landing.sheep[2] = 1
	occupied_landing.sheep[20] = 5
	occupied_landing.sheep[21] = 5
	assert(not _has_capture(occupied_landing, 0, 2), "A capture must not land on an occupied node")

	# Only the capturing wolf may complete the optional second capture.
	var chain = _empty_state()
	chain.wolves[0] = true
	chain.wolves[10] = true
	chain.sheep[1] = 1
	chain.sheep[3] = 1
	chain.sheep[20] = 5
	chain.sheep[21] = 5
	assert(chain.move_wolf(0, 2) == "captured_chain_available",
		"First capture must expose the optional follow-up when one exists")
	assert(chain.chain_wolf == 2 and chain.chain_capture_count == 1)
	var chain_actions := AI._legal_search_moves(chain, true)
	var decline_count := 0
	for action in chain_actions:
		if str(action.get("side", "")) == "decline_chain":
			decline_count += 1
		elif str(action.get("side", "")) == "wolf":
			assert(int(action.get("from", -1)) == 2,
				"Only the wolf that made the first capture may continue the chain")
	assert(decline_count == 1, "The optional chain must include exactly one decline action")
	assert(chain.move_wolf(10, 11) == "wrong_chain_wolf",
		"An unrelated wolf must not take over an active chain")
	assert(chain.move_wolf(2, 4) == "captured",
		"The same wolf must be able to complete the second capture")
	assert(chain.sheep_total() == 10 and chain.turn == GameState.Turn.SHEEP)
	assert(chain.chain_wolf == -1 and chain.chain_capture_count == 0)

	# The wolf victory threshold is exact: 9 -> 8 wins; 10 -> 9 does not.
	var eight_after_capture = _empty_state()
	eight_after_capture.wolves[0] = true
	eight_after_capture.wolves[10] = true
	eight_after_capture.wolves[14] = true
	eight_after_capture.sheep[1] = 1
	eight_after_capture.sheep[20] = 4
	eight_after_capture.sheep[21] = 4
	assert(eight_after_capture.sheep_total() == 9)
	assert(eight_after_capture.move_wolf(0, 2) == "won")
	assert(eight_after_capture.sheep_total() == 8)
	assert(eight_after_capture.winner == "wolves")

	var nine_after_capture = _empty_state()
	nine_after_capture.wolves[0] = true
	nine_after_capture.wolves[10] = true
	nine_after_capture.wolves[14] = true
	nine_after_capture.sheep[1] = 1
	nine_after_capture.sheep[20] = 5
	nine_after_capture.sheep[21] = 4
	assert(nine_after_capture.sheep_total() == 10)
	assert(nine_after_capture.move_wolf(0, 2) == "captured")
	assert(nine_after_capture.sheep_total() == 9)
	assert(nine_after_capture.winner == "", "Nine remaining sheep must not trigger a wolf victory")

	# Sheep win only when every wolf has neither a move nor a capture.
	var all_wolves_blocked = _empty_state()
	for wolf_node in [0, 4, 20]:
		all_wolves_blocked.wolves[wolf_node] = true
	for node in range(BoardGraph.NODE_COUNT):
		if not all_wolves_blocked.wolves[node]:
			all_wolves_blocked.sheep[node] = 1
	all_wolves_blocked._check_winner()
	assert(all_wolves_blocked.sheep_total() == 22)
	assert(all_wolves_blocked.winner == "sheep",
		"All three fully blocked wolves must produce a sheep victory")

	var one_wolf_can_capture = _empty_state()
	for wolf_node in [0, 4, 20]:
		one_wolf_can_capture.wolves[wolf_node] = true
	for node in range(BoardGraph.NODE_COUNT):
		if not one_wolf_can_capture.wolves[node] and node != 2:
			one_wolf_can_capture.sheep[node] = 1
	assert(_has_capture(one_wolf_can_capture, 0, 2))
	one_wolf_can_capture._check_winner()
	assert(one_wolf_can_capture.winner == "",
		"One legal capture must prevent a false sheep victory")

	# Siege pressure must depend on adjacent wolves and genuinely restricted exits.
	var constrained = _empty_state()
	constrained.sheep[0] = 1
	constrained.wolves[1] = true
	constrained.wolves[5] = true
	constrained.wolves[10] = true
	assert(AI._sheep_escape_count(constrained, 0) == 1)
	assert(AI._sheep_siege_pressure(constrained) > 0.0)

	var open_center = _empty_state()
	open_center.sheep[12] = 1
	open_center.wolves[11] = true
	assert(AI._sheep_escape_count(open_center, 12) == 7)
	assert(AI._sheep_siege_pressure(open_center) == 0.0,
		"A wolf beside a sheep with seven open exits must not count as siege pressure")

	var distant_wolves = _empty_state()
	distant_wolves.sheep[0] = 1
	distant_wolves.sheep[1] = 1
	distant_wolves.sheep[5] = 1
	distant_wolves.sheep[6] = 1
	distant_wolves.wolves[12] = true
	distant_wolves.wolves[13] = true
	distant_wolves.wolves[14] = true
	assert(AI._sheep_escape_count(distant_wolves, 0) == 0)
	assert(AI._sheep_siege_pressure(distant_wolves) == 0.0,
		"Nearby but non-adjacent wolves must not be counted as direct siege pressure")

	# The search identity must distinguish the same board with a different turn.
	var identity_a = _empty_state()
	identity_a.sheep[20] = 5
	identity_a.turn = GameState.Turn.SHEEP
	identity_a.position_history.clear()
	identity_a._record_position()
	var identity_b = AI._copy_state(identity_a)
	identity_b.turn = GameState.Turn.WOLVES
	assert(identity_a._position_key() != identity_b._position_key())
	assert(AI._search_position_key(identity_a) != AI._search_position_key(identity_b))

	print("WOLF-DUSK-058 edge cases passed: single-sheep capture, occupied landing, chain ownership/decline, exact win threshold, all-wolves-blocked victory, siege semantics and turn-sensitive position identity.")
	quit()
