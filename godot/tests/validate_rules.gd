extends SceneTree

const BoardGraph = preload("res://scripts/board_graph.gd")
const GameState = preload("res://scripts/game_state.gd")

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
	assert(chain_state.move_wolf(12, 24) == "captured")
	assert(chain_state.sheep_total() == 10)
	assert(chain_state.turn == GameState.Turn.SHEEP)
	assert(chain_state.chain_wolf == -1)

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

	print("WOLF-DUSK-004 checks passed: graph, setup, legal/illegal moves, capture chain and both win conditions.")
	quit()
