extends SceneTree

const GameState = preload("res://scripts/game_state.gd")

# WOLF-DUSK-049: exact legal 12-ply cycle observed in the 048 competitive audit.
# The first eight plies already return to the start; the final four repeat it again.
# This is a reproduction fixture, not an assertion that the AI should prefer it.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = GameState.new()
	for node in range(25):
		state.sheep[node] = 0
		state.wolves[node] = false

	# Position repeated in the 048 logs for wolf level 2 vs sheep level 2.
	for node in [4, 10, 14]:
		state.sheep[node] = 1
	state.sheep[20] = 2
	for node in [21, 22, 23, 24]:
		state.sheep[node] = 5
	for node in [8, 16, 18]:
		state.wolves[node] = true
	state.turn = GameState.Turn.SHEEP
	state.chain_wolf = -1
	state.chain_capture_count = 0
	state.winner = ""
	state.position_history.clear()
	state._record_position()

	var cycle_start := state._position_key()
	var moves := [
		["S", 10, 6],
		["W", 8, 12],
		["S", 6, 2],
		["W", 12, 17],
		["S", 2, 6],
		["W", 17, 12],
		["S", 6, 10],
		["W", 12, 8],
		["S", 4, 3],
		["W", 8, 2],
		["S", 3, 4],
		["W", 2, 8]
	]

	for index in range(moves.size()):
		var action: Array = moves[index]
		var side: String = str(action[0])
		var from_node: int = int(action[1])
		var to_node: int = int(action[2])
		if side == "S":
			assert(state.turn == GameState.Turn.SHEEP, "Cycle fixture expected sheep turn at ply %d" % (index + 1))
			assert(state.move_sheep(from_node, to_node), "Recorded sheep move became illegal at ply %d: %d>%d" % [index + 1, from_node, to_node])
		else:
			assert(state.turn == GameState.Turn.WOLVES, "Cycle fixture expected wolf turn at ply %d" % (index + 1))
			assert(state.move_wolf(from_node, to_node) == "moved", "Recorded wolf move became illegal at ply %d: %d>%d" % [index + 1, from_node, to_node])

	assert(state.turn == GameState.Turn.SHEEP, "Twelve-ply cycle must return to the same side to move")
	assert(state._position_key() == cycle_start, "Recorded 12-ply loop must return to the exact same position")
	var history_matches := 0
	for history_key in state.position_history:
		if str(history_key) == cycle_start:
			history_matches += 1
	print("WOLF-DUSK-049 cycle diagnostic: history_size=%d exact_key_matches=%d final_key=%s" % [state.position_history.size(), history_matches, state._position_key()])
	if history_matches != 3:
		print("WOLF-DUSK-049 history entries: ", state.position_history)
		quit(1)
		return
	assert(state.winner == "", "Cycle fixture must remain non-terminal")
	print("WOLF-DUSK-049 exact cycle fixture passed: legal 12-ply loop reproduced; no game rule was changed.")
	quit()
