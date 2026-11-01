extends SceneTree

const BoardGraph = preload("res://scripts/board_graph.gd")
const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")

func _initialize() -> void:
	assert(BoardGraph.NODE_COUNT == 25)
	assert(BoardGraph.EDGES.size() == 56)
	var adjacency := BoardGraph.adjacency()
	var directed_count := 0
	var unique_edges := {}
	for edge in BoardGraph.EDGES:
		assert(edge.size() == 2)
		assert(edge[0] >= 0 and edge[0] < 25)
		assert(edge[1] >= 0 and edge[1] < 25)
		assert(edge[0] < edge[1])
		var key := "%d-%d" % [edge[0], edge[1]]
		assert(not unique_edges.has(key))
		unique_edges[key] = true
	for node in range(25):
		for neighbor in adjacency[node]:
			directed_count += 1
			assert(node in adjacency[neighbor])
	assert(directed_count == 112)

	var state = GameState.new()
	assert(state.sheep_total() == 25)
	assert(state.sheep[20] == 5 and state.sheep[24] == 5)
	assert(state.turn == GameState.Turn.PLACE_WOLVES)
	assert(not state.place_wolf(20))
	assert(state.place_wolf(0))
	assert(state.place_wolf(1))
	assert(state.place_wolf(2))
	assert(state.turn == GameState.Turn.SHEEP)
	assert(not state.move_sheep(20, 0))
	assert(state.sheep_total() == 25)
	assert(state.move_sheep(20, 15))
	assert(state.sheep_total() == 25)
	assert(state.turn == GameState.Turn.WOLVES)

	var capture_state = GameState.new()
	assert(capture_state.place_wolf(0))
	assert(capture_state.place_wolf(1))
	assert(capture_state.place_wolf(2))
	capture_state.sheep[20] -= 1
	capture_state.sheep[6] = 1
	# Three wolves have been placed; the sheep turn must be completed before a wolf capture.
	capture_state.turn = GameState.Turn.WOLVES
	var options := capture_state.capture_options(0)
	var found := false
	for option in options:
		if option["middle"] == 6 and option["to"] == 12:
			found = true
	assert(found)
	var capture_result: String = capture_state.move_wolf(0, 12)
	if capture_result != "captured":
		push_error("Expected capture result 'captured', got: %s" % capture_result)
		quit(1)
		return
	assert(capture_state.sheep_total() == 24)
	assert(capture_state.turn == GameState.Turn.SHEEP)

	var invalid_state = GameState.new()
	assert(invalid_state.place_wolf(0))
	assert(invalid_state.place_wolf(1))
	assert(invalid_state.place_wolf(2))
	invalid_state.turn = GameState.Turn.WOLVES
	assert(invalid_state.move_wolf(0, 24) == "invalid")
	assert(invalid_state.wolves[0] and not invalid_state.wolves[24])
	assert(invalid_state.turn == GameState.Turn.WOLVES)
	assert(not invalid_state.place_wolf(3))

	# Optional second capture must be made by the same wolf and only once.
	var chain_state = GameState.new()
	for i in range(25):
		chain_state.sheep[i] = 0
		chain_state.wolves[i] = false
	chain_state.wolves[0] = true
	chain_state.wolves[1] = true
	chain_state.wolves[2] = true
	chain_state.sheep[6] = 1
	chain_state.sheep[18] = 1
	chain_state.sheep[20] = 5
	chain_state.sheep[21] = 5
	chain_state.turn = GameState.Turn.WOLVES
	assert(chain_state.move_wolf(0, 12) == "captured_chain_available")
	assert(chain_state.chain_wolf == 12)
	assert(chain_state.move_wolf(1, 3) == "wrong_chain_wolf")
	# An unrelated destination cannot consume the pending chain opportunity.
	assert(chain_state.move_wolf(12, 4) == "chain_capture_required")
	assert(chain_state.wolves[12] and not chain_state.wolves[4])
	assert(chain_state.sheep_total() == 11)
	assert(chain_state.turn == GameState.Turn.WOLVES)
	assert(chain_state.move_wolf(12, 24) == "captured")
	assert(chain_state.sheep_total() == 10)
	assert(chain_state.turn == GameState.Turn.SHEEP)
	assert(chain_state.chain_wolf == -1)

	# Declining the optional second capture must end the wolf turn cleanly.
	var declined_chain_state = GameState.new()
	for i in range(25):
		declined_chain_state.sheep[i] = 0
		declined_chain_state.wolves[i] = false
	declined_chain_state.wolves[0] = true
	declined_chain_state.wolves[1] = true
	declined_chain_state.wolves[2] = true
	declined_chain_state.sheep[6] = 1
	declined_chain_state.sheep[18] = 1
	declined_chain_state.sheep[20] = 5
	declined_chain_state.sheep[21] = 5
	declined_chain_state.turn = GameState.Turn.WOLVES
	assert(declined_chain_state.move_wolf(0, 12) == "captured_chain_available")
	assert(not declined_chain_state.capture_options(12).is_empty())
	declined_chain_state.finish_wolf_turn()
	assert(declined_chain_state.turn == GameState.Turn.SHEEP)
	assert(declined_chain_state.chain_wolf == -1)
	assert(declined_chain_state.chain_capture_count == 0)
	assert(declined_chain_state.sheep_total() == 11)

	# Reaching eight sheep wins immediately.
	var wolf_win_state = GameState.new()
	for i in range(25):
		wolf_win_state.sheep[i] = 0
		wolf_win_state.wolves[i] = false
	wolf_win_state.wolves[0] = true
	wolf_win_state.wolves[1] = true
	wolf_win_state.wolves[2] = true
	wolf_win_state.sheep[6] = 1
	wolf_win_state.sheep[20] = 5
	wolf_win_state.sheep[21] = 3
	wolf_win_state.turn = GameState.Turn.WOLVES
	assert(wolf_win_state.move_wolf(0, 12) == "won")
	assert(wolf_win_state.sheep_total() == 8)
	assert(wolf_win_state.winner == "wolves")
	assert(wolf_win_state.turn == GameState.Turn.FINISHED)

	# If every non-wolf point is occupied, no wolf can move or capture.
	var sheep_win_state = GameState.new()
	for i in range(25):
		sheep_win_state.sheep[i] = 0
		sheep_win_state.wolves[i] = false
	sheep_win_state.wolves[0] = true
	sheep_win_state.wolves[1] = true
	sheep_win_state.wolves[2] = true
	for i in range(3, 25):
		sheep_win_state.sheep[i] = 1
	sheep_win_state.turn = GameState.Turn.WOLVES
	sheep_win_state.finish_wolf_turn()
	assert(sheep_win_state.winner == "sheep")
	assert(sheep_win_state.turn == GameState.Turn.FINISHED)

	# AI must always return actions accepted by the same authoritative rules.
	var ai_state = GameState.new()
	for difficulty in range(3):
		var placement: int = AI.choose_wolf_placement(ai_state, difficulty)
		assert(placement >= 0 and placement < BoardGraph.NODE_COUNT)
		assert(ai_state.place_wolf(placement))
	assert(ai_state.turn == GameState.Turn.SHEEP)
	for difficulty in range(3):
		var sheep_action: Dictionary = AI.choose_sheep_move(ai_state, difficulty)
		assert(not sheep_action.is_empty())
		assert(ai_state.move_sheep(int(sheep_action.from), int(sheep_action.to)))
		# Restore the sheep turn to exercise all difficulty levels independently.
		ai_state.turn = GameState.Turn.SHEEP
	# Wolves now have a legal turn; every difficulty must propose a legal move.
	ai_state.turn = GameState.Turn.WOLVES
	for difficulty in range(3):
		var wolf_action: Dictionary = AI.choose_wolf_move(ai_state, difficulty)
		assert(not wolf_action.is_empty())
		var legal_wolf_move := false
		for destination in ai_state.wolf_moves(int(wolf_action.from)):
			if destination == int(wolf_action.to):
				legal_wolf_move = true
		for capture in ai_state.capture_options(int(wolf_action.from)):
			if int(capture.to) == int(wolf_action.to):
				legal_wolf_move = true
		assert(legal_wolf_move)

	# Sheep AI should advance from the E side toward the A side.
	var ai_direction_state = GameState.new()
	for i in range(25):
		ai_direction_state.sheep[i] = 0
		ai_direction_state.wolves[i] = false
	var forward_score: float = AI._sheep_position_score(ai_direction_state, 12, 6)
	var backward_score: float = AI._sheep_position_score(ai_direction_state, 6, 12)
	assert(forward_score > backward_score)

	# The AI must recognize a destination that becomes capturable after the move,
	# including a landing point vacated by the moving sheep itself.
	var ai_safety_state = GameState.new()
	for i in range(25):
		ai_safety_state.sheep[i] = 0
		ai_safety_state.wolves[i] = false
	ai_safety_state.wolves[0] = true
	ai_safety_state.wolves[1] = true
	ai_safety_state.wolves[2] = true
	ai_safety_state.sheep[12] = 1
	assert(AI._sheep_safety_score(ai_safety_state, 6, 12) < 0.0)

	print("WOLF-DUSK-004 checks passed: graph, setup, legal/illegal moves, capture chain, win conditions and AI safety/direction.")
	quit()
