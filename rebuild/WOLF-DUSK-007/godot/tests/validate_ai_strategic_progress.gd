extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
const AI = preload("res://scripts/ai_opponent.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = GameState.new()
	var placements: Array[int] = []
	for _i in range(3):
		var node: int = AI.choose_wolf_placement(state, 4)
		assert(node >= 0 and node < 25 and not state.is_occupied(node),
			"Master placement must return a legal, unoccupied node")
		for previous in placements:
			assert(AI._graph_distance(node, previous) >= 2,
				"Master opening must distribute wolves instead of clustering adjacent placements")
		assert(state.place_wolf(node), "Rules rejected a master placement")
		placements.append(node)

	assert(placements.size() == 3 and state.turn == GameState.Turn.SHEEP,
		"Strategic opening must place all three wolves and start the sheep turn")
	var nearest_flock_distance := 99
	for wolf_node in placements:
		var nearest_for_wolf := 99
		for sheep_node in range(20, 25):
			nearest_for_wolf = mini(nearest_for_wolf, AI._graph_distance(wolf_node, sheep_node))
		nearest_flock_distance = mini(nearest_flock_distance, nearest_for_wolf)
	assert(nearest_flock_distance <= 2,
		"At least one master wolf must begin within two legal steps of the starting flock")

	print("WOLF-DUSK-052 strategic placement passed: placements=%s; wolves are distributed and retain access to the starting flock." % str(placements))
	quit()
