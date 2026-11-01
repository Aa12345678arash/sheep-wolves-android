extends SceneTree

const BoardGraph = preload("res://scripts/board_graph.gd")
const GameState = preload("res://scripts/game_state.gd")

func _initialize() -> void:
	assert(BoardGraph.NODE_COUNT == 25)
	assert(BoardGraph.EDGES.size() == 56)
	var adjacency := BoardGraph.adjacency()
	var directed_count := 0
	for node in range(25):
		for neighbor in adjacency[node]:
			directed_count += 1
			assert(node in adjacency[neighbor])
	assert(directed_count == 112)

	var state = GameState.new()
	assert(state.sheep_total() == 25)
	assert(state.sheep[20] == 5 and state.sheep[24] == 5)
	assert(state.turn == GameState.Turn.PLACE_WOLVES)
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
	print("WOLF-DUSK-005 rule checks passed: 25 nodes, 56 edges, setup, sheep move, capture geometry.")
	quit()
