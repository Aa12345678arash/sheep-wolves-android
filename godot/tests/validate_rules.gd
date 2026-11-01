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
	assert(state.move_sheep(20, 15))
	assert(state.sheep_total() == 25)
	assert(state.turn == GameState.Turn.WOLVES)

	var capture_state = GameState.new()
	assert(capture_state.place_wolf(0))
	assert(capture_state.place_wolf(1))
	assert(capture_state.place_wolf(2))
	capture_state.sheep[20] -= 1
	capture_state.sheep[6] = 1
	var options := capture_state.capture_options(0)
	var found := false
	for option in options:
		if option["middle"] == 6 and option["to"] == 12:
			found = true
	assert(found)
	assert(capture_state.move_wolf(0, 12) == "captured")
	assert(capture_state.sheep_total() == 24)
	assert(capture_state.turn == GameState.Turn.SHEEP)

	print("WOLF-DUSK-005 checks passed: graph, setup, sheep movement and wolf capture.")
	quit()
